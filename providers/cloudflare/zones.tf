locals {
  zones = {
    "tapshalkar.com" = {
      # Excluded from Terraform — managed by cloudflare-ddns (dynamic home IP):
      #   ddns.tapshalkar.com, homelab.tapshalkar.com, vpn.tapshalkar.com, etc.
      # Excluded — Cloudflare-auto-managed DCV CNAME (no TLD target):
      #   _41a23e238f189aadd2dec8aa46729106.tapshalkar.com
      a_records = [
        { name = "@", content = "34.149.115.30", proxied = true, ttl = 1 },
        { name = "aditya", content = "34.149.115.30", proxied = true, ttl = 1 },
        { name = "www", content = "34.149.115.30", proxied = true, ttl = 1 },
      ]
      mx_records = [
        { name = "@", content = "smtp.google.com", priority = 1, ttl = 1 },
        { name = "send", content = "feedback-smtp.us-east-1.amazonses.com", priority = 10, ttl = 1 },
      ]
      cname_records = [
        { name = "cdn", content = "d2eusg8vbwmww2.cloudfront.net", proxied = true, ttl = 1 },
        { name = "fsnlhxs2v7hu", content = "gv-lamvn5qc53y2q7.dv.googlehosted.com", proxied = true, ttl = 1 },
      ]
      txt_records = [
        { name = "_dmarc", content = "v=DMARC1; p=none; rua=mailto:a33fb186693e4eb99964e77c8e27b952@dmarc-reports.cloudflare.net", ttl = 1 },
        { name = "google._domainkey", content = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEArnmFh/2EAJT8Stb0WxH7sEdosUPWXtal63NwVVoPswNv62NAwrd9wafUtLkaE5uSlw+9ot3JJ2E3yOH05WsK+DqSZm7oKcRtbOzgymJmUzjWRESM3hjZ9m+Kd2PR2LfWdZ+/aKERKW+1l+y84wF7+n8BZQ9UJhMz1K8bpcxuY3xGXZLpZ1eZbVynhymwv1okSt6JZLZ4GeDsBkAfcnaHu3a0vAUa7z39UIMqFMtoTWP3EIGY1KSnqvnaW4TsRiKRVROd+FY00awh6aGNZDzB8MrO/Fb/hs7Q4RjQUnxiGfOJfC/CtKs/JxcLn/3RCLCF340caITwaVBl5B0I+72plQIDAQAB", ttl = 1 },
        { name = "resend._domainkey", content = "p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCmIeO+JxXSPAkAnkIiuYx5cOTDseUKx+QJN4bUZjZHOtj9KnvND8cAfwMkkANpHEWuJCKVbm+md/zqzBlOf5n/yIqOcqaNGEkvJTD4/RY6rrEKhubwgP4kFhb1KxA5civ7gKr7JvV0Pwj8HLRvFJja5mdC9E7Kt0iP6y/GUrkVWQIDAQAB", ttl = 1 },
        { name = "send", content = "v=spf1 include:amazonses.com ~all", ttl = 1 },
        { name = "@", content = "v=spf1 include:_spf.google.com ~all", ttl = 1 },
      ]
      srv_records = []
    }
  }
}
