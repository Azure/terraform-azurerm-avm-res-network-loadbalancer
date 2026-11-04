resource "azapi_resource" "this" {
  name                   = var.name
  parent_id              = var.parent_id
  type                   = var.resource_types.network_load_balancers_backend_address_pools
  body                   = { properties = { for key, value in var.properties : key => value if key != "loadBalancerBackendAddresses" || var.backend_address_type != "NIC" } }
  ignore_body_changes    = length(var.ignore_body_changes.network_load_balancers_backend_address_pools) > 0 ? var.ignore_body_changes.network_load_balancers_backend_address_pools : null
  ignore_null_property   = true
  locks                  = [var.parent_id]
  response_export_values = []
  retry                  = var.retry

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
    precondition {
      condition = var.sku_tier == "Global" ? (
        var.backend_address_type == "Frontend" && var.properties.virtualNetwork == null && length(var.properties.tunnelInterfaces) == 0
      ) : var.backend_address_type != "Frontend"
      error_message = "Global pools require Frontend mode without VNet/tunnels; Regional pools require IP or NIC mode."
    }
  }
}

resource "azapi_resource_action" "clear_backend_members" {
  count = var.backend_address_type == "NIC" ? 0 : 1

  method                 = "PUT"
  resource_id            = "${var.parent_id}/backendAddressPools/${var.name}"
  type                   = var.resource_types.network_load_balancers_backend_address_pools
  body                   = { properties = { loadBalancerBackendAddresses = [] } }
  locks                  = [var.parent_id]
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

  depends_on = [azapi_resource.this]
}
