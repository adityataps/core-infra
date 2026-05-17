module "zones" {
  for_each = local.zones
  source   = "./modules/zone"

  zone_name     = each.key
  account_id    = var.account_id
  a_records     = lookup(each.value, "a_records", [])
  mx_records    = lookup(each.value, "mx_records", [])
  cname_records = lookup(each.value, "cname_records", [])
  txt_records   = lookup(each.value, "txt_records", [])
  srv_records   = lookup(each.value, "srv_records", [])
}
