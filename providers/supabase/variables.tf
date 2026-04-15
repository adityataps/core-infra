variable "access_token" {
  type        = string
  description = "Supabase personal access token. Generate from Supabase Dashboard → Account → Access Tokens → Generate New Token."
  sensitive   = true
}
