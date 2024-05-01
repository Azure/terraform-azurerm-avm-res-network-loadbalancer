resource "azurerm_management_lock" "this" {
  count = var.lock != null ? 1 : 0

  lock_level = var.lock.kind
  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_lb.this.id
  notes      = var.lock.kind == "CanNotDelete" ? "Cannot delete the resource or its child resources." : "Cannot delete or modify the resource or its child resources."

  depends_on = [
    azurerm_lb.this,
    azurerm_public_ip.this,
    azurerm_lb_backend_address_pool.this,
    azurerm_lb_backend_address_pool_address.this,
    azurerm_lb_nat_rule.this,
    azurerm_lb_probe.this,
    azurerm_lb_rule.this,
    azurerm_lb_outbound_rule.this,
    azurerm_monitor_diagnostic_setting.this,
    azurerm_role_assignment.this
  ]
}

resource "azurerm_management_lock" "pip" {
  for_each = { for frontend, frontend_values in var.frontend_ip_configurations : frontend => frontend_values if frontend_values.create_public_ip_address && (frontend_values.lock_type_if_not_inherited != "None" || (frontend_values.inherit_lock && var.lock != null)) }

  lock_level = each.value.inherit_lock ? var.lock.kind : each.value.lock_type_if_not_inherited
  name       = "lock-${each.value.public_ip_address_resource_name}"
  scope      = azurerm_public_ip.this[each.key].id

  depends_on = [
    azurerm_lb.this,
    azurerm_public_ip.this,
    azurerm_lb_backend_address_pool.this,
    azurerm_lb_backend_address_pool_address.this,
    azurerm_lb_nat_rule.this,
    azurerm_lb_probe.this,
    azurerm_lb_rule.this,
    azurerm_lb_outbound_rule.this,
    azurerm_monitor_diagnostic_setting.this,
    azurerm_monitor_diagnostic_setting.pip,
    azurerm_role_assignment.this,
    azurerm_role_assignment.pip
  ]
}
