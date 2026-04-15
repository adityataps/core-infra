terraform {
  backend "gcs" {
    bucket = "adits-gcp-core-infra-tfstate"
    prefix = "gcp/adits-gcp"
  }
}
