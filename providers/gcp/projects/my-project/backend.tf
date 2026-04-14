terraform {
  backend "gcs" {
    bucket = "your-tf-state-bucket"
    prefix = "gcp/my-project"
  }
}
