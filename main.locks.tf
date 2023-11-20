resource "azurerm_management_lock" "azlb" {
  count = var.lock.kind != "None" ? 1 : 0 # only one lock right now, multiple locks needed?

  name       = coalesce(var.lock.name, "lock-${var.name}")
  scope      = azurerm_lb.this.id
  lock_level = var.lock.kind
  depends_on = [
    azurerm_lb.this,
    azurerm_public_ip.azlb,
    azurerm_lb_backend_address_pool.azlb,
    azurerm_lb_backend_address_pool_address.azlb,
    azurerm_lb_nat_rule.azlb,
    azurerm_lb_probe.azlb,
    azurerm_lb_rule.azlb,
    azurerm_lb_outbound_rule.azlb,
    azurerm_monitor_diagnostic_setting.this,
    azurerm_role_assignment.this
  ]
}

resource "azurerm_management_lock" "pip_lock" {
  # for_each = { for ip_config in var.frontend_ip_configurations : ip_config.name => ip_config if ip_config.create_public_ip_address && ip_config.inherit_lock != true && ip_config.lock_type_if_not_inherited != "None" }
  for_each = { for frontend, frontend_values in var.frontend_ip_configurations : frontend => frontend_values if frontend_values.create_public_ip_address && (frontend_values.lock_type_if_not_inherited != "None" || (frontend_values.inherit_lock && var.lock.kind != "None")) }

  name       = "lock-${each.value.public_ip_address_resource_name}"
  scope      = azurerm_public_ip.azlb[each.key].id
  lock_level = each.value.inherit_lock ? var.lock.kind : each.value.lock_type_if_not_inherited
  depends_on = [
    azurerm_lb.this,
    azurerm_public_ip.azlb,
    azurerm_lb_backend_address_pool.azlb,
    azurerm_lb_backend_address_pool_address.azlb,
    azurerm_lb_nat_rule.azlb,
    azurerm_lb_probe.azlb,
    azurerm_lb_rule.azlb,
    azurerm_lb_outbound_rule.azlb,
    azurerm_monitor_diagnostic_setting.this,
    azurerm_role_assignment.this
  ]
}
