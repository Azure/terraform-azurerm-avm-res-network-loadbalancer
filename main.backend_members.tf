# Partial-field owner, not a second pool lifecycle owner. Delete is a no-op;
# the parent exclusively creates/removes pools and manages their metadata.
resource "azapi_update_resource" "backend_members" {
  for_each = local.backend_pool_members

  resource_id = local.pool_ids[each.key]
  type        = var.resource_types.network_load_balancers_backend_address_pools
  body = {
    properties = { loadBalancerBackendAddresses = each.value }
  }
  ignore_missing_property = false
  locks                   = [local.resource_id]
  response_export_values  = []
  retry                   = var.retry

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }

  lifecycle {
    # Also recreate this partial binding after a parent update/replacement.
    # Its deletion never deletes the pool or clears any member.
    replace_triggered_by = [azapi_resource.this]
  }
  depends_on = [azapi_resource.this]
}

# Deliberately replay only an empty exclusively owned list, never a saved
# snapshot of live NICs. The action is NOT a refreshing member owner.
resource "azapi_resource_action" "clear_backend_members" {
  for_each = local.backend_pool_members

  method      = "PUT"
  resource_id = azapi_update_resource.backend_members[each.key].resource_id
  type        = var.resource_types.network_load_balancers_backend_address_pools
  body = {
    properties = { loadBalancerBackendAddresses = [] }
  }
  locks                  = [local.resource_id]
  response_export_values = []
  retry                  = var.retry
  when                   = "destroy"

  dynamic "timeouts" {
    for_each = var.timeouts == null ? [] : [var.timeouts]
    content {
      create = timeouts.value.create
      read   = timeouts.value.read
      update = timeouts.value.update
      delete = timeouts.value.delete
    }
  }
}
