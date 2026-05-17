variable "zone_name" {
  description = "Domain name for the zone (e.g. example.com)"
  type        = string
}

variable "account_id" {
  description = "Cloudflare account ID"
  type        = string
}

variable "a_records" {
  description = "List of A records"
  type = list(object({
    name    = string
    content = string
    proxied = bool
    ttl     = number
  }))
  default = []
}

variable "mx_records" {
  description = "List of MX records"
  type = list(object({
    name     = string
    content  = string
    priority = number
    ttl      = number
  }))
  default = []
}

variable "cname_records" {
  description = "List of CNAME records"
  type = list(object({
    name    = string
    content = string
    proxied = bool
    ttl     = number
  }))
  default = []
}

variable "txt_records" {
  description = "List of TXT records"
  type = list(object({
    name    = string
    content = string
    ttl     = number
  }))
  default = []
}

variable "srv_records" {
  description = "List of SRV records"
  type = list(object({
    service  = string
    proto    = string
    priority = number
    weight   = number
    port     = number
    target   = string
    ttl      = number
  }))
  default = []
}
