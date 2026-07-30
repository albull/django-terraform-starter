app_cpu     = 256
app_memory  = 1024
jobs_cpu    = 512
jobs_memory = 2048

# Replace <ACCOUNT_ID> with the AWS account this env deploys into, and the domain
# with your own Route 53 hosted zone. ecr_repository_name matches the workspace name.
ecr_repository_url  = "<ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/myapp-dev"
ecr_registry_id     = "<ACCOUNT_ID>"
ecr_repository_name = "myapp-dev"
zone_name           = "app.dev.example.com"
domain_name         = "*.app.dev.example.com"
django_env          = "dev"
repo                = "<GITHUB_ORG>/<GITHUB_REPO>"
server_threads      = 10

service_desired_job_count = 1
service_desired_web_count = 1
