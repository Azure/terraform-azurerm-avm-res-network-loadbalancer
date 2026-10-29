output "backend_address_pool_resource_ids" {
  depends_on  = [azapi_resource.this, module.backend_address_pool]
  description = "Backend pool IDs keyed by backend_address_pools input keys. Pass these to the module that owns the NIC."
  value       = var.backend_address_pool_child_modules_enabled ? { for key, pool in module.backend_address_pool : key => pool.resource_id } : local.pool_ids
}

output "frontend_ip_configuration_resource_ids" {
  depends_on  = [azapi_resource.this]
  description = "Frontend IDs keyed by frontend_ip_configurations input keys."
  value       = local.frontend_ids
}

output "inbound_nat_rule_resource_ids" {
  description = "NAT rule IDs keyed by lb_nat_rules input keys (not Azure rule names)."
  value       = { for key, rule in module.inbound_nat_rule : key => rule.resource_id }
}

output "load_balancing_rule_resource_ids" {
  depends_on  = [azapi_resource.this]
  description = "Load balancing rule IDs keyed by lb_rules input keys."
  value       = { for key, rule in var.lb_rules : key => "${local.resource_id}/loadBalancingRules/${coalesce(rule.name, "rule-${var.name}")}" }
}

output "name" {
  description = "The load balancer name."
  value       = azapi_resource.this.name
}

output "outbound_rule_resource_ids" {
  depends_on  = [azapi_resource.this]
  description = "Outbound rule IDs keyed by lb_outbound_rules input keys."
  value       = { for key, rule in var.lb_outbound_rules : key => "${local.resource_id}/outboundRules/${coalesce(rule.name, "outbound-rule-${var.name}")}" }
}

output "probe_resource_ids" {
  depends_on  = [azapi_resource.this]
  description = "Probe IDs keyed by lb_probes input keys."
  value       = local.probe_ids
}

output "resource_id" {
  description = "The load balancer ARM resource ID."
  value       = azapi_resource.this.id
}
