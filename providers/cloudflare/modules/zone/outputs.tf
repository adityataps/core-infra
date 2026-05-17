output "zone_id" {
  description = "Cloudflare zone ID"
  value       = cloudflare_zone.this.id
}

output "zone_name" {
  description = "Domain name"
  value       = cloudflare_zone.this.name
}
