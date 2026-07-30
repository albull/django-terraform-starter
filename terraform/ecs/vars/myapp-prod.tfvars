app_cpu     = 1024
app_memory  = 4096
jobs_cpu    = 4096
jobs_memory = 8192

ecr_repository_url  = "<ACCOUNT_ID>.dkr.ecr.us-west-2.amazonaws.com/myapp-prod"
ecr_registry_id     = "<ACCOUNT_ID>"
ecr_repository_name = "myapp-prod"
zone_name           = "app.example.com"
domain_name         = "*.app.example.com"
django_env          = "prod"
repo                = "<GITHUB_ORG>/<GITHUB_REPO>"
server_threads      = 10

service_desired_job_count = 1
service_desired_web_count = 1
