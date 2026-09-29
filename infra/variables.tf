variable "project" {
  description = "Directory of the project: stack.yaml and ca.pem are read from it. damstack sets it."
  type        = string
}

variable "state_passphrase" {
  description = "Passphrase the state and plans are encrypted with; kept in vault.yml of the project."
  type        = string
  sensitive   = true
}

variable "traefik_cloudflare_token" {
  description = "Cloudflare token Traefik answers DNS-01 challenges with when certificates.dns_provider is cloudflare; kept in vault.yml of the project."
  type        = string
  sensitive   = true
  ephemeral   = true
  default     = ""
}

variable "acme_dns_env" {
  description = "Credentials of another DNS provider for the DNS-01 challenge, as NAME=value pairs separated by spaces; kept in vault.yml of the project."
  type        = string
  sensitive   = true
  ephemeral   = true
  default     = ""

  validation {
    condition     = alltrue([for pair in compact(split(" ", var.acme_dns_env)) : can(regex("^[A-Z][A-Z0-9_]*=.+$", pair))])
    error_message = "acme_dns_env must be NAME=value pairs separated by spaces, such as HETZNER_API_TOKEN=abc."
  }
}

variable "traefik_cloudflare_token_version" {
  description = "Raise to write a changed traefik_cloudflare_token to Vault."
  type        = number
  default     = 1
}
