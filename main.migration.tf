moved {
  from = azurerm_lb.this
  to   = azapi_resource.this
}

# backend_members is a partial-field updater of an already-existing pool, not
# a pool lifecycle binding: its first apply writes through the dedicated
# endpoint after the parent adopts metadata. No pool import or second
# azapi_resource owner is introduced. clear_backend_members initially stores
# only an empty destroy-time request and performs no Azure write on creation.
# The stateless write_backend_members action has no state/import and runs
# before updater create/update. Existing partial binding addresses are unchanged.
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

moved {
  from = azurerm_role_assignment.this
  to   = azapi_resource.role_assignments
}

moved {
  from = azurerm_management_lock.this
  to   = azapi_resource.lock
}

moved {
  from = azurerm_monitor_diagnostic_setting.this
  to   = azapi_resource.diagnostic_settings
}

# Experimental (unreleased) child-composition drafts only. Forget every keyed
# instance without deleting Azure children; the complete LB body adopts them.
# Standalone callers outside this root are not addressed by these declarations.
removed {
  from = module.backend_address_pool
  lifecycle {
    destroy = false
  }
}

removed {
  from = module.inbound_nat_rule
  lifecycle {
    destroy = false
  }
}
