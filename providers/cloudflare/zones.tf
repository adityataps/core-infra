locals {
  zones = {
    "tapshalkar.com" = {
      # NOTE: home.tapshalkar.com is excluded — managed by favonia/cloudflare-ddns
      a_records     = []
      mx_records    = []
      cname_records = []
      txt_records   = []
      srv_records   = []
    }
  }
}
