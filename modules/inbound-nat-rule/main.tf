resource "azapi_resource" "this" {
  name                   = var.name
  parent_id              = var.parent_id
  type                   = var.resource_types.network_load_balancers_inbound_nat_rules
  body                   = { properties = var.properties }
  ignore_body_changes    = length(var.ignore_body_changes.network_load_balancers_inbound_nat_rules) > 0 ? var.ignore_body_changes.network_load_balancers_inbound_nat_rules : null
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
}
