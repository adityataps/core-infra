terraform {
  required_version = ">= 1.5"
  required_providers {
    supabase = {
      source  = "supabase/supabase"
      version = "~> 1.0"
    }
  }

  backend "gcs" {
    # bucket is set via -backend-config or backend.hcl (gitignored)
    prefix = "supabase"
  }
}

provider "supabase" {
  access_token = var.access_token
}
