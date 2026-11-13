# These budgets outlived their project configurations. Their former remote states
# contain no managed resources. Preserve their filters and limits while restoring
# delivery; an unresolved project reference alone is not grounds for deletion.
locals {
  legacy_budgets = {
    tapshalkar-vista-hackathon-26 = "503850767595"
    vista-hackathon-2026          = "273444870514"
  }
}

resource "google_billing_budget" "legacy" {
  for_each        = local.legacy_budgets
  billing_account = var.billing_account
  display_name    = "${each.key}-monthly-budget"

  budget_filter {
    projects = ["projects/${each.value}"]
  }

  amount {
    specified_amount {
      currency_code = "USD"
      units         = "100"
    }
  }

  dynamic "threshold_rules" {
    for_each = [0.5, 0.9, 1.0]
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = module.baseline.budget_notification_channel_ids
    disable_default_iam_recipients   = true
  }
}

import {
  to = google_billing_budget.legacy["tapshalkar-vista-hackathon-26"]
  id = "billingAccounts/01580F-EF92F2-574531/budgets/216f2ce1-7d67-460a-bbcb-001938a826a7"
}

import {
  to = google_billing_budget.legacy["vista-hackathon-2026"]
  id = "billingAccounts/01580F-EF92F2-574531/budgets/8fa31d42-f418-44b7-bae6-cfddddb8e937"
}
