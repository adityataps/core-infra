project_id        = "tapshalkar-vista-hackathon-26"
project_name      = "Vista Hackathon 2026"
admin_user        = "aditya@tapshalkar.com"
region            = "us-east1"
budget_amount     = 100
budget_thresholds = [0.5, 0.9, 1.0]

labels = {
  env          = "personal"
  owner        = "aditya-tapshalkar"
  "managed-by" = "terraform"
}

enabled_apis = [
  "compute.googleapis.com",
  "iam.googleapis.com",
  "cloudbilling.googleapis.com",
  "billingbudgets.googleapis.com",
  "cloudresourcemanager.googleapis.com",
  "logging.googleapis.com",
  "monitoring.googleapis.com",
  "iamcredentials.googleapis.com",
  "aiplatform.googleapis.com",
  "discoveryengine.googleapis.com",
  "run.googleapis.com",
  "artifactregistry.googleapis.com",
  "secretmanager.googleapis.com",
  "storage.googleapis.com",
]

# enable_data_access_audit_logs = true  # set to false to disable billable DATA_READ/WRITE audit logs
