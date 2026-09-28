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
  description = "Cloudflare token Traefik answers DNS-01 challenges with; kept in vault.yml of the project."
  type        = string
  sensitive   = true
  ephemeral   = true
}

variable "traefik_cloudflare_token_version" {
  description = "Raise to write a changed traefik_cloudflare_token to Vault."
  type        = number
  default     = 1
}
