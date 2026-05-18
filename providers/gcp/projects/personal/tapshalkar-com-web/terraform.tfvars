project_id    = "tapshalkar-com-web"
project_name  = "tapshalkar-com-web"
admin_user    = "aditya@tapshalkar.com"
region        = "us-central1"
budget_amount = 20

enabled_apis = [
  # Default
  "compute.googleapis.com",
  "iam.googleapis.com",
  "cloudbilling.googleapis.com",
  "billingbudgets.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "logging.googleapis.com",
  "monitoring.googleapis.com",
  "iamcredentials.googleapis.com",
  "storage.googleapis.com",

  # Bespoke
  "artifactregistry.googleapis.com",
  "modelarmor.googleapis.com",
  "secretmanager.googleapis.com",
  "run.googleapis.com",
  "cloudscheduler.googleapis.com",
]

labels = {
  env          = "web"
  owner        = "aditya"
  "managed-by" = "terraform"
}
