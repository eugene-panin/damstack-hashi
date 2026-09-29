locals {
  stack = yamldecode(file("${var.project}/stack.yaml"))
  apps  = coalesce(try(local.stack.apps, null), {})
}

module "stack" {
  source  = "eugene-panin/hashistack/nomad"
  version = "~> 0.8"

  infra_domain             = local.stack.infra_domain
  address                  = cidrhost(local.stack.network.cidr, 1)
  ca_pem                   = file("${var.project}/ca.pem")
  acme_email               = local.stack.acme_email
  dns_provider_env         = { CF_DNS_API_TOKEN = var.traefik_cloudflare_token }
  dns_provider_env_version = var.traefik_cloudflare_token_version
}

module "mail" {
  source   = "eugene-panin/stalwart/nomad"
  version  = "~> 0.1"
  for_each = { for name, app in local.apps : name => app if name == "mail" }

  hostname      = each.value.hostname
  domains       = each.value.domains
  mailboxes     = try(each.value.mailboxes, ["info"])
  acme_email    = try(each.value.acme_email, local.stack.acme_email)
  vault_kv_path = module.stack.vault_kv_path
}

module "dns" {
  source  = "eugene-panin/hashistack/nomad//modules/dns-cloudflare"
  version = "~> 0.8"
  count   = local.stack.dns.provider == "cloudflare" ? 1 : 0

  records = local.records
  zones   = local.stack.dns.zones
}

locals {
  records = concat([module.stack.dns_records], [for m in module.mail : m.dns_records])
}
