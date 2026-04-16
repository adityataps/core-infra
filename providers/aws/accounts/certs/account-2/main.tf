data "terraform_remote_state" "github" {
  backend = "gcs"
  config = {
    bucket = "tapshalkar-com-tfstate"
    prefix = "github"
  }
}

module "baseline" {
  source = "../../../modules/baseline"

  account_name = "certs-2"
  region       = var.region
  github_repo  = data.terraform_remote_state.github.outputs.core_infra_repo_full_name
}
