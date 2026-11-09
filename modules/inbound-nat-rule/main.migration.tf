import {
  for_each = var.avm_managed_migration_enabled ? { this = true } : {}
  to       = azapi_resource.this
  id       = "${var.parent_id}/inboundNatRules/${var.name}?api-version=${split("@", var.resource_types.network_load_balancers_inbound_nat_rules)[1]}"
}
