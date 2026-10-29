import {
  for_each = var.avm_managed_migration_enabled ? { this = true } : {}
  to       = azapi_resource.this
  id       = "${var.parent_id}/backendAddressPools/${var.name}?api-version=${split("@", var.resource_types.network_load_balancers_backend_address_pools)[1]}"
}
