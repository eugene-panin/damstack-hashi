output "ui_urls" {
  description = "Addresses of the Consul, Nomad and Vault UIs."
  value       = module.stack.ui_urls
}

output "mailboxes" {
  description = "Mailboxes and the aliases each one receives."
  value       = merge({}, [for m in module.mail : m.mailboxes]...)
}

output "mail_passwords" {
  description = "Password of each mailbox."
  value       = merge({}, [for m in module.mail : m.passwords]...)
  sensitive   = true
}

output "manual_records" {
  description = "DNS records to create by hand: those of domains outside the zones the dns provider of stack.yaml publishes to."
  value = {
    for d in distinct(flatten([for set in local.records : keys(set)])) :
    d => flatten([for set in local.records : lookup(set, d, [])])
    if !contains(flatten([for z in module.dns : keys(z.zone_ids)]), d)
  }

  precondition {
    condition     = contains(["cloudflare", "manual"], local.stack.dns.provider)
    error_message = "dns.provider in stack.yaml must be cloudflare or manual."
  }
}
