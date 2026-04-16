terraform {
  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "gcp/projects/management/tapshalkar-com"
  }
}
