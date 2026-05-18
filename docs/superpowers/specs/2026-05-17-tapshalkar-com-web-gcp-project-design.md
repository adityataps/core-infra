# Design: tapshalkar-com-web GCP Project

**Date:** 2026-05-17
**Status:** Approved

## Summary

Create a new GCP project (`tapshalkar-com-web`) in the `personal` folder of the org, scaffolded via the existing `create-gcp-project.sh` script, with web-specific API and audit log defaults applied afterward.

## Decisions

- **No new GCP org folder.** The project lives under the existing `personal` GCP folder. A dedicated `web/` folder is premature for a single project and can be introduced later if multiple web properties are added.
- **No new `projects/` subdirectory.** The project sits at `providers/gcp/projects/personal/tapshalkar-com-web/`, consistent with sibling personal projects (`tapshalkar-com-personal`, `tapshalkar-com-sandbox`).
- **Use `create-gcp-project.sh` for scaffolding.** The script handles template copy, `backend.tf`/`main.tf`/`variables.tf` patching, `terraform.tfvars` generation, and Makefile + `tf-all.sh` wiring.
- **Web-specific overrides applied post-scaffold.** `storage.googleapis.com` added to `enabled_apis`; `enable_data_access_audit_logs` defaulted to `false` (static CDN traffic doesn't need billable DATA_READ/WRITE logs); `labels.env` set to `"web"`.

## Scope

This spec covers only the Terraform project scaffolding. The actual Cloud Storage bucket, CDN, and DNS configuration for tapshalkar.com live in the separate `adityataps/tapshalkar.com` repo and are out of scope.

## Files Changed

| File | Change |
|------|--------|
| `providers/gcp/projects/personal/tapshalkar-com-web/backend.tf` | Created by script — prefix `gcp/projects/personal/tapshalkar-com-web` |
| `providers/gcp/projects/personal/tapshalkar-com-web/backend.hcl` | Created by script — bucket `tapshalkar-com-tfstate` |
| `providers/gcp/projects/personal/tapshalkar-com-web/main.tf` | Created by script — uses `personal_folder_resource_name` |
| `providers/gcp/projects/personal/tapshalkar-com-web/variables.tf` | Created by script, then patched for web defaults |
| `providers/gcp/projects/personal/tapshalkar-com-web/outputs.tf` | Created by script — unchanged |
| `providers/gcp/projects/personal/tapshalkar-com-web/terraform.tfvars.example` | Created by script — unchanged |
| `providers/gcp/projects/personal/tapshalkar-com-web/terraform.tfvars` | Created by script — gitignored, reviewed before apply |
| `Makefile` | Patched by script — adds `gcp-personal-tapshalkar-com-web` target |
| `scripts/tf-all.sh` | Patched by script — increments `TOTAL_MODULES` |

## Implementation Steps

1. Run `./scripts/create-gcp-project.sh personal tapshalkar-com-web`
2. In the generated `variables.tf`, apply three patches:
   - Add `"storage.googleapis.com"` to `enabled_apis` default list
   - Change `enable_data_access_audit_logs` default to `false`
   - Change `labels` default `env` value to `"web"`
3. Review generated `terraform.tfvars` — update `budget_amount` to `20` if not already set
4. Commit all scaffolded files (excluding `terraform.tfvars`)

## Apply Instructions (manual, post-commit)

```bash
cd providers/gcp/projects/personal/tapshalkar-com-web
terraform init -backend-config="bucket=tapshalkar-com-tfstate"
terraform import module.baseline.google_project.this projects/tapshalkar-com-web
terraform plan && terraform apply
```
