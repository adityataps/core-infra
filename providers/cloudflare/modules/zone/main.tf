resource "cloudflare_zone" "this" {
  name    = var.zone_name
  account = { id = var.account_id }
}

resource "cloudflare_dns_record" "a" {
  for_each = { for r in var.a_records : "${r.name}:${r.content}" => r }

  zone_id = cloudflare_zone.this.id
  type    = "A"
  name    = each.value.name
  content = each.value.content
  proxied = each.value.proxied
  ttl     = each.value.ttl
}

resource "cloudflare_dns_record" "mx" {
  for_each = { for r in var.mx_records : "${r.name}:${r.content}" => r }

  zone_id  = cloudflare_zone.this.id
  type     = "MX"
  name     = each.value.name
  content  = each.value.content
  priority = each.value.priority
  ttl      = each.value.ttl
}

resource "cloudflare_dns_record" "cname" {
  for_each = { for r in var.cname_records : r.name => r }

  zone_id = cloudflare_zone.this.id
  type    = "CNAME"
  name    = each.value.name
  content = each.value.content
  proxied = each.value.proxied
  ttl     = each.value.ttl
}

resource "cloudflare_dns_record" "txt" {
  for_each = { for r in var.txt_records : "${r.name}:${r.content}" => r }

  zone_id = cloudflare_zone.this.id
  type    = "TXT"
  name    = each.value.name
  content = each.value.content
  ttl     = each.value.ttl
}

resource "cloudflare_dns_record" "srv" {
  for_each = { for r in var.srv_records : "${r.service}.${r.proto}:${r.port}" => r }

  zone_id  = cloudflare_zone.this.id
  type     = "SRV"
  name     = "${each.value.service}.${each.value.proto}"
  priority = each.value.priority
  ttl      = each.value.ttl
  data = {
    weight = each.value.weight
    port   = each.value.port
    target = each.value.target
  }
}
