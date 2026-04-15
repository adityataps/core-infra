variable "public_key" {
  type        = string
  description = "MongoDB Atlas API public key. Generate from Atlas → Access Manager → API Keys → Create API Key."
}

variable "private_key" {
  type        = string
  description = "MongoDB Atlas API private key."
  sensitive   = true
}

variable "org_id" {
  type        = string
  description = "MongoDB Atlas organization ID. Found in Atlas → Organization Settings → Organization ID."
}
