output "backend_address_pool_resource_id" {
  description = "Backend pool ID for the resource/module that owns a NIC."
  value       = module.backend_address_pool.resource_id
}

output "inbound_nat_rule_resource_id" {
  description = "Independently managed NAT rule ID."
  value       = module.inbound_nat_rule.resource_id
}
