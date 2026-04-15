# GCP Organization Structure Design

## Goal

Introduce GCP organization-level hierarchy under `tapshalkar.com` (Google Workspace), placing existing and future projects under named folders, with org IAM managed via Terraform.

## Architecture

A new `providers/gcp/org/` root manages the organization's folders and IAM. Per-project roots read folder IDs via `terraform_remote_state` and pass them into the baseline module. The existing `adits-gcp` project state is migrated to a new GCS prefix to match the updated directory structure.

## Directory Structure

```
providers/gcp/
├── org/                              ← NEW: folders + org IAM
│   ├── versions.tf
│   ├── backend.tf                    — GCS prefix: "gcp/org"
│   ├── variables.tf
│   ├── main.tf
│   └── outputs.tf
│
├── modules/baseline/
│   ├── variables.tf                  — add optional folder_id (default null)
│   └── project.tf                   — set folder_id on google_project.this
│
└── projects/
    ├── personal/                     ← NEW grouping by folder
    │   └── adits-gcp/               ← MOVED from projects/adits-gcp/
    └── certs/                       ← placeholder for future projects
```

## Resources Per Root

### `providers/gcp/org/`

- `data.google_organization` — looks up org by domain (`tapshalkar.com`), no import needed
- `google_folder.personal` — folder under org for personal projects
- `google_folder.certs` — folder under org for cert/learning projects
- `google_organization_iam_member.admin` — binds `aditya@tapshalkar.com` as `roles/resourcemanager.organizationAdmin`

**Outputs:** `personal_folder_id`, `certs_folder_id`

### `providers/gcp/modules/baseline/`

Two-line change only:
- `variables.tf`: add `folder_id` variable (`type = string`, `default = null`, `sensitive = false`)
- `project.tf`: add `folder_id = var.folder_id` to `google_project.this`

### `providers/gcp/projects/personal/adits-gcp/`

- Add `data "terraform_remote_state" "gcp_org"` reading from GCS prefix `gcp/org`
- Pass `folder_id = data.terraform_remote_state.gcp_org.outputs.personal_folder_id` to `module.baseline`
- Update `backend.tf` prefix from `gcp/adits-gcp` → `gcp/projects/personal/adits-gcp`

## State Migration

The existing `adits-gcp` state lives at GCS prefix `gcp/adits-gcp`. Migrate before moving the local directory:

```bash
gsutil cp \
  gs://adits-gcp-core-infra-tfstate/gcp/adits-gcp/default.tfstate \
  gs://adits-gcp-core-infra-tfstate/gcp/projects/personal/adits-gcp/default.tfstate
```

Then update `backend.tf`, run `terraform init -reconfigure`, and verify `terraform plan` shows zero changes before proceeding.

## Apply Order

1. `providers/gcp/org/` — creates folders (greenfield, no imports expected)
2. `providers/gcp/projects/personal/adits-gcp/` — moves project parent from org root → `personal/` folder (non-destructive update, no reimport needed)

## Import Notes

- **Folders**: expected to be greenfield — `terraform apply` creates them. If a `personal/` folder already exists in the console, import with `terraform import google_folder.personal folders/<FOLDER_ID>`.
- **Org IAM**: if the `organizationAdmin` binding for `aditya@tapshalkar.com` already exists, import with `terraform import google_organization_iam_member.admin "organizations/<ORG_ID> roles/resourcemanager.organizationAdmin user:aditya@tapshalkar.com"`.
- **adits-gcp project**: already in state — no reimport needed. Changing `folder_id` on `google_project.this` is a non-destructive in-place update.

## Out of Scope

- Org policies / constraints (added later)
- `work/` folder (added when needed)
- Billing account management
