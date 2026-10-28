moved {
  from = azurerm_lb.this
  to   = azapi_resource.this
}

removed {
  from = azurerm_lb_backend_address_pool.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_lb_backend_address_pool_address.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_network_interface_backend_address_pool_association.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_lb_probe.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_lb_rule.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_lb_nat_rule.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_lb_outbound_rule.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_lb_nat_pool.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_public_ip.this
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_management_lock.pip
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_role_assignment.pip
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_monitor_diagnostic_setting.pip
  lifecycle {
    destroy = false
  }
}

removed {
  from = azurerm_role_assignment.this
  lifecycle {
    destroy = false
  }
}

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.lock
}

moved {
  from = azurerm_monitor_diagnostic_setting.this
  to   = azapi_resource.diagnostic_settings
}

import {
  for_each = var.avm_managed_migration_enabled ? var.migration_role_assignment_resource_ids : {}
  to       = azapi_resource.role_assignments[each.key]
  id       = "${each.value}?api-version=${split("@", var.resource_types.authorization_role_assignments)[1]}"
}
