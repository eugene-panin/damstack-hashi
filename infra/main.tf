locals {
  stack        = yamldecode(file("${var.project}/stack.yaml"))
  dns_provider = try(local.stack.certificates.dns_provider, "cloudflare")
  acme_dns_env = {
    for pair in compact(split(" ", var.acme_dns_env)) : split("=", pair)[0] => join("=", slice(split("=", pair), 1, length(split("=", pair))))
  }
}

module "stack" {
  source = "git::https://github.com/eugene-panin/terraform-nomad-hashistack.git?ref=v0.9.0"

  infra_domain             = local.stack.infra_domain
  address                  = cidrhost(local.stack.network.cidr, 1)
  ca_pem                   = file("${var.project}/ca.pem")
  acme_email               = local.stack.acme_email
  dns_provider             = local.dns_provider
  dns_provider_env         = local.dns_provider == "cloudflare" ? { CF_DNS_API_TOKEN = var.traefik_cloudflare_token } : local.acme_dns_env
  dns_provider_env_version = var.traefik_cloudflare_token_version
}

removed {
  from = module.mail

  lifecycle {
    destroy = false
  }
}

removed {
  from = module.dns

  lifecycle {
    destroy = false
  }
}
