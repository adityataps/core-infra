# No baseline-level alert policies — workload alerts belong in each project's
# own Terraform config, since the right metrics depend on what's running there
# (Cloud Run, GKE, GCE, etc.). Notification channels are defined above and can
# be referenced by project-level alert policies via terraform_remote_state.
