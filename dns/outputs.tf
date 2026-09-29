output "manual_records" {
  description = "DNS records to create by hand: those of domains the dns provider of stack.yaml does not publish to."
  value = {
    for d in distinct(flatten([for set in local.sets : keys(set)])) :
    d => flatten([for set in local.sets : lookup(set, d, [])])
    if !contains(flatten([for m in module.cloudflare : keys(m.zone_ids)]), d)
  }

  precondition {
    condition     = contains(["cloudflare", "manual"], local.stack.dns.provider)
    error_message = "dns.provider in stack.yaml must be cloudflare or manual."
  }
}
