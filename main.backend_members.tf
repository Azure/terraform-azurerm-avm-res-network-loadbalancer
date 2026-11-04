# Exact writes and refreshing state are coupled in one partial-field lifecycle.
# The updater alone MERGES named arrays and cannot remove a nonempty subset.
# Its before-action first PUTs the desired list without merging a remote body.
action "azapi_resource_action" "write_backend_members" {
  for_each = local.backend_pool_members

  config {
    method      = "PUT"
    resource_id = local.pool_ids[each.key]
    type        = var.resource_types.network_load_balancers_backend_address_pools
    body = {
      # PUT must retain this root's configured pool metadata as well as members.
      # No live NIC projection or synthesized member property is copied here.
      properties = merge({ for key, value in local.backend_pool_properties[each.key] : key => value if value != null }, {
        loadBalancerBackendAddresses = each.value
      })
    }
    locks = [local.resource_id]
  }
}

# Partial-field owner, not a second pool lifecycle owner. Delete is a no-op.
# After the exact PUT, the updater sees the already-correct member collection;
# its normal refresh remains responsible for detecting added/changed members.
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
    action_trigger {
      events     = [before_create, before_update]
      actions    = [action.azapi_resource_action.write_backend_members[each.key]]
      on_failure = halt
    }

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
