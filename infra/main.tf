locals {
  stack = yamldecode(file("${var.project}/stack.yaml"))
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
