locals {
  stack = yamldecode(file("${var.project}/stack.yaml"))
  sets  = [for f in sort(fileset("${var.project}/dns", "*.json")) : jsondecode(file("${var.project}/dns/${f}"))]
}

module "cloudflare" {
  source  = "eugene-panin/hashistack/nomad//modules/dns-cloudflare"
  version = "~> 0.8"
  count   = local.stack.dns.provider == "cloudflare" ? 1 : 0

  records = local.sets
  zones   = local.stack.dns.zones
}
