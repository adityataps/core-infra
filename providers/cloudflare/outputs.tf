output "zone_ids" {
  description = "Map of zone name to Cloudflare zone ID"
  value       = { for k, v in module.zones : k => v.zone_id }
}
