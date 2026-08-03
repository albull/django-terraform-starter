# Secrets (SOPS + age)

How this repo stores deployment secrets: encrypted in git with
[SOPS](https://github.com/getsops/sops), keyed with [age](https://github.com/FiloSottile/age)
rather than AWS KMS.

Requires both tools: `brew install sops age`.

## TL;DR

```bash
cd terraform
./setup-sops.sh yourproject     # once, after cloning — generates keys + encrypted secrets
sops ecs/vars/yourproject-dev-secrets.json    # edit a secret later
```

Everything else on this page is detail you only need when onboarding someone, rotating a
key, or debugging a decrypt failure.

## How it fits together

```
vars/<workspace>-secrets.json   committed, ENCRYPTED (age)
        │
        │  terraform plan/apply  — carlpett/sops provider, via SOPS_AGE_KEY_FILE
        ▼
   aws_ssm_parameter             SecureString in SSM Parameter Store
        │
        │  ECS task definition `secrets` block (valueFrom)
        ▼
   container env var             DJANGO_SECRET_KEY, DATABASE_PASSWORD
```

Encrypted `vars/<workspace>-secrets.json` files **are** committed; the decrypted form never
is. Terraform decrypts them at plan/apply time (see the `data "sops_file"` blocks in
[`ecs/main.tf`](ecs/main.tf) and [`rds/main.tf`](rds/main.tf)), writes them to SSM as
`SecureString` parameters, and the ECS task definitions reference those parameters by name.

**The running container never sees an age key** — it gets plain env vars, injected by ECS
from SSM. Likewise the deploy workflow doesn't decrypt anything: it only builds the image
and rolls the service. Secrets reach AWS via `terraform apply`, run by a human.

### Why age instead of AWS KMS

Chicken-and-egg. With KMS you can't encrypt a secret until a KMS key exists, which means an
AWS account, credentials, and a successful `terraform apply` — before you can write down the
password that apply needs. age works offline, so someone cloning this repo can have working
encrypted secrets before touching AWS.

The tradeoff: every operator holds a private key file, and onboarding someone means
re-wrapping the files for them (below). KMS instead piggybacks on IAM, which is nicer once
you're at a scale where IAM is already how you manage access.

### Per-environment keying

Each secrets file is encrypted to **two** recipients: your personal age key, and a CI key
dedicated to that one environment. So a leaked dev key cannot decrypt prod. `.sops.yaml`
has one `creation_rule` per environment enforcing this.

## What is safe to publish

This trips people up, so explicitly:

| Thing | Looks like | Commit / publish? |
|---|---|---|
| age **public** key | `age1qm2zsw…` | **Yes.** Encryption-only — it's a recipient. Publishing is how SOPS is meant to work. |
| age **private** key | `AGE-SECRET-KEY-1…` | **Never.** Decrypts everything it's a recipient of. |
| `vars/*-secrets.json` (encrypted) | `"ENC[AES256_GCM,data:…]"` | **Yes** — safe *only* because the private keys aren't published. |
| `ci-age-keys.OUTPUT.txt` | private keys, plaintext | **Never.** Gitignored; delete it after use. |
| `~/.config/sops/age/*.txt` | private keys, plaintext | **Never.** Lives outside the repo by design. |

Two caveats worth knowing before you commit an encrypted file:

- **SOPS encrypts values, not key names.** A committed file publicly reveals its structure —
  `DJANGO_SECRET_KEY`, `rds_master_password`. Usually fine, but the *existence* of something
  like `stripe_live_key` is itself a signal. Check the key names, not just the values.
- **Public + encrypted is forever.** Anyone can copy the ciphertext now and attack it later.
  For genuinely long-lived, high-value secrets, prefer a secrets manager that supports real
  rotation over a file committed to a public repo.

> **If you cloned this template:** `.sops.yaml` ships with `<PLACEHOLDER>` recipients, not
> real keys. That's deliberate — inheriting someone else's public key would let you encrypt
> secrets *they* could read and you couldn't. `setup-sops.sh` replaces them with your own.

## First-time setup

From `terraform/`:

```bash
./setup-sops.sh yourproject     # defaults to `myapp`
```

Idempotent — safe to re-run. It will:

1. Create your personal age key at `~/.config/sops/age/keys.txt` if you don't have one.
2. Generate a per-environment CI key at `~/.config/sops/age/<project>-<env>.txt`.
3. Rewrite `.sops.yaml` with one rule per environment, listing both public keys.
4. Create any missing `<module>/vars/<workspace>-secrets.json` from the committed `.example`
   templates, filling in strong random values, and encrypt them. Existing files are
   re-wrapped with `sops updatekeys` — **contents are preserved**.
5. Write the CI *private* keys to `ci-age-keys.OUTPUT.txt` (gitignored).

Then **verify the isolation holds** before you rely on it — the dev key must fail on prod:

```bash
# should succeed
SOPS_AGE_KEY_FILE=~/.config/sops/age/yourproject-dev.txt \
  sops -d ecs/vars/yourproject-dev-secrets.json

# should FAIL with "no key could decrypt the data"
SOPS_AGE_KEY_FILE=~/.config/sops/age/yourproject-prod.txt \
  sops -d ecs/vars/yourproject-dev-secrets.json
```

Finally, **delete `ci-age-keys.OUTPUT.txt`** — it's plaintext private keys on disk. See
[Do you need the CI keys?](#do-you-need-the-ci-keys) first.

### Do you need the CI keys?

**Probably not yet.** As shipped, nothing in CI decrypts secrets — Terraform does it from
your laptop, and [`deploy-dev.yml`](../.github/workflows/deploy-dev.yml) only builds and
rolls the service. The per-env CI keys exist for when you add a workflow that runs
`terraform plan`/`apply` itself.

When you do, store that environment's private key as a **GitHub environment secret** named
`SOPS_AGE_KEY` (Settings → Environments → `<env>` → Environment secrets — *not* a repo-wide
secret, or dev jobs could read the prod key), and have the job write it out before Terraform
runs:

```yaml
- name: Install sops
  run: |
    curl -sLo sops https://github.com/getsops/sops/releases/download/v3.10.2/sops-v3.10.2.linux.amd64
    sudo install -m 0755 sops /usr/local/bin/sops
- name: Provision age key
  run: |
    mkdir -p ~/.config/sops/age
    echo "${{ secrets.SOPS_AGE_KEY }}" > ~/.config/sops/age/keys.txt
    chmod 600 ~/.config/sops/age/keys.txt
```

Until then, keep the keys offline or discard them and regenerate later with `setup-sops.sh`.

## Day-to-day

```bash
sops ecs/vars/myapp-dev-secrets.json              # edit in place (re-encrypts on save)
sops --decrypt ecs/vars/myapp-dev-secrets.json    # print plaintext
openssl rand -hex 32                              # generate a new secret value
```

The `terraform-apply.sh` / `terraform-destroy.sh` wrappers export `SOPS_AGE_KEY_FILE`
(defaulting to `~/.config/sops/age/keys.txt`) and fail early if it's missing.

### Adding a new secret

1. `sops <module>/vars/<workspace>-secrets.json` and add the JSON key.
2. Repeat for every environment — a key present in dev but missing in prod fails at
   *plan* time for prod, which is easy to miss until you deploy.
3. Reference it in Terraform: `data.sops_file.secrets.data["your_key"]`.
4. Add it to the matching `.example` file with a `replace-with-…` placeholder, so the next
   person knows it's expected. `setup-sops.sh` uses these templates.

Secrets are read by the `ecs` and `rds` modules. If you add a `data "sops_file"` block to
another module, add that module to `MODULES` in `setup-sops.sh`.

## Onboarding a teammate

Ask for their age **public** key (`grep 'public key:' ~/.config/sops/age/keys.txt`). Add it
to every rule's `age:` list in `.sops.yaml`, then re-wrap each file so it's encrypted for
them too:

```bash
sops updatekeys ecs/vars/myapp-dev-secrets.json   # repeat per module × env
```

Re-wrapping changes *who can decrypt*; it does not change the values. Commit the updated
`.sops.yaml` and secrets files.

## Rotating a key

**A CI key** (someone left, or it may have leaked): delete
`~/.config/sops/age/<project>-<env>.txt`, re-run `./setup-sops.sh`, then update that
environment's `SOPS_AGE_KEY` secret if you're using one.

**Removing an operator:** drop their public key from `.sops.yaml`, then
`sops updatekeys` every file. They can no longer decrypt *future* versions.

> Re-wrapping does **not** change the secret values. If a private key genuinely leaked,
> whoever held it already read everything it could decrypt — rotate the underlying secrets
> too (DB password, Django secret key), not just the age keys. Git history still holds
> ciphertext they can open.

## Troubleshooting

**`no key could decrypt the data`** — your key isn't a recipient of that file. Check
`SOPS_AGE_KEY_FILE` points at the right key, and that your public key is in the matching
`.sops.yaml` rule. If you were just added as a recipient, someone needs to run
`sops updatekeys` and commit the result.

**Terraform: `Error: Failed to get the data key`** — Terraform can't find your age key.
The wrappers set `SOPS_AGE_KEY_FILE`; if you're running bare `terraform`, export it yourself.

**`sops` rewrote the whole file / huge diff** — you edited the ciphertext by hand or with a
non-SOPS editor. Revert and use `sops <file>`.

**A new key works in dev but prod plan fails** — you added it to only one environment's
file. Every environment needs its own copy.
