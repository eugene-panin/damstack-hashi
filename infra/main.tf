locals {
  stack        = yamldecode(file("${var.project}/stack.yaml"))
  cert_mode    = try(local.stack.certificates.mode, "letsencrypt-dns")
  internal_ca  = local.cert_mode == "internal-ca"
  dns_provider = try(local.stack.certificates.dns_provider, "cloudflare")
  acme_dns_env = {
    for pair in compact(split(" ", var.acme_dns_env)) : split("=", pair)[0] => join("=", slice(split("=", pair), 1, length(split("=", pair))))
  }

  ca_pem = file("${var.project}/ca.pem")

  internal_tls = local.internal_ca ? {
    mode     = "ca"
    cert_pem = "${tls_locally_signed_cert.internal[0].cert_pem}${local.ca_pem}"
    key_pem  = tls_private_key.internal[0].private_key_pem
  } : { mode = "acme-dns" }

  dns_provider_env = local.internal_ca ? {} : (
    local.dns_provider == "cloudflare" ? { CF_DNS_API_TOKEN = var.traefik_cloudflare_token } : local.acme_dns_env
  )
}

# Internal-CA mode: a wildcard for the admin pages, signed by the project's CA.
resource "tls_private_key" "internal" {
  count     = local.internal_ca ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "internal" {
  count           = local.internal_ca ? 1 : 0
  private_key_pem = tls_private_key.internal[0].private_key_pem

  subject {
    common_name = "*.${local.stack.infra_domain}"
  }

  dns_names = ["*.${local.stack.infra_domain}", local.stack.infra_domain]
}

resource "tls_locally_signed_cert" "internal" {
  count                 = local.internal_ca ? 1 : 0
  cert_request_pem      = tls_cert_request.internal[0].cert_request_pem
  ca_private_key_pem    = var.stack_ca_key
  ca_cert_pem           = local.ca_pem
  validity_period_hours = 87600
  early_renewal_hours   = 720

  allowed_uses = ["digital_signature", "key_encipherment", "server_auth"]
}

module "stack" {
  source = "git::https://github.com/eugene-panin/terraform-nomad-hashistack.git?ref=v0.10.0"

  infra_domain             = local.stack.infra_domain
  address                  = cidrhost(local.stack.network.cidr, 1)
  ca_pem                   = local.ca_pem
  acme_email               = local.stack.acme_email
  dns_provider             = local.dns_provider
  dns_provider_env         = local.dns_provider_env
  dns_provider_env_version = var.traefik_cloudflare_token_version
  internal_tls             = local.internal_tls
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
