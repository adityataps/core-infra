terraform {
  backend "gcs" {
    # TODO: replace with the bucket name output from `cd bootstrap && terraform output bucket_name`
    bucket = "your-tf-state-bucket"
    prefix = "gcp/my-project"
  }
}
