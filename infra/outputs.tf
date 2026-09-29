output "ui_urls" {
  description = "Addresses of the Consul, Nomad and Vault UIs."
  value       = module.stack.ui_urls
}

output "dns_records" {
  description = "DNS records of the platform, keyed by domain; the dns step publishes them with those of the apps."
  value       = module.stack.dns_records
}
