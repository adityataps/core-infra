terraform {
  backend "gcs" {
    bucket = "adits-gcp-core-infra-tfstate"
    prefix = "gcp/projects/personal/adits-gcp"
  }
}
