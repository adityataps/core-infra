project_id        = "tapshalkar-com"
project_name      = "tapshalkar-com"
billing_account   = "01580F-EF92F2-574531"
admin_user        = "aditya@tapshalkar.com"
region            = "us-east1"
budget_amount     = 25
budget_thresholds = [0.5, 0.9, 1.0]

labels = {
  env          = "management"
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
  "generativelanguage.googleapis.com",
]

# enable_data_access_audit_logs = true  # set to false to disable billable DATA_READ/WRITE audit logs
