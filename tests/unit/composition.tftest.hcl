mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
  }
}

override_resource {
  target = module.backend_address_pool["app"].azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/backendAddressPools/azure-pool"
  }
}

override_resource {
  target = module.inbound_nat_rule["admin"].azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/inboundNatRules/ssh"
  }
}

variables {
  name                                       = "lab"
  parent_id                                  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab"
  location                                   = "eastus2"
  enable_telemetry                           = false
  backend_address_pool_child_modules_enabled = true
  backend_address_pools                      = { app = { name = "azure-pool" } }
  frontend_ip_configurations = {
    internal = {
      name                                   = "internal"
      frontend_private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/default"
    }
  }
  lb_nat_rules = {
    admin = {
      name                             = "ssh"
      frontend_ip_configuration_name   = "internal"
      frontend_port_start              = 50000
      frontend_port_end                = 50100
      backend_port                     = 22
      backend_address_pool_object_name = "app"
    }
  }
}

run "composes_writable_children_and_retains_frontend" {
  command = apply
  assert {
    condition     = length(module.backend_address_pool) == 1 && length(module.inbound_nat_rule) == 1 && length(azapi_resource.this.body.properties.backendAddressPools) == 0 && length(azapi_resource.this.body.properties.inboundNatRules) == 0
    error_message = "Children must be root-composed, never simultaneously owned in the parent body."
  }
  assert {
    condition     = output.backend_address_pool_resource_ids.app == module.backend_address_pool["app"].resource_id && endswith(output.backend_address_pool_resource_ids.app, "/backendAddressPools/azure-pool") && output.inbound_nat_rule_resource_ids.admin == module.inbound_nat_rule["admin"].resource_id && endswith(output.inbound_nat_rule_resource_ids.admin, "/inboundNatRules/ssh")
    error_message = "Outputs must depend on child creation and retain input keys rather than Azure names."
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.frontendIPConfigurations) == 1 && azapi_resource.this.body.properties.frontendIPConfigurations[0].name == "internal" && local.nat_rule_properties.admin.backendAddressPool.id == local.pool_ids.app
    error_message = "The frontend must exist in the first parent PUT; NAT references must resolve to the requested pool."
  }
  assert {
    condition     = azapi_resource.this.locks == tolist([local.resource_id]) && length(local.parent_referenced_pool_ids) == 0
    error_message = "Parent writes must use the shared LB mutex and avoid a pool creation cycle."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "propagates_nested_controls_and_interfaces" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = {
        role_definition_id_or_name = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id               = "22222222-2222-2222-2222-222222222222"
        principal_type             = "ServicePrincipal"
      }
    }
    resource_types = {
      network_load_balancers_backend_address_pools = {
        network_load_balancers_backend_address_pools = "Microsoft.Network/loadBalancers/backendAddressPools@2024-10-01"
      }
      network_load_balancers_inbound_nat_rules = {
        network_load_balancers_inbound_nat_rules = "Microsoft.Network/loadBalancers/inboundNatRules@2024-10-01"
      }
    }
    ignore_body_changes = {
      network_load_balancers = ["properties.scope"]
      network_load_balancers_backend_address_pools = {
        network_load_balancers_backend_address_pools = ["properties.virtualNetwork"]
      }
      network_load_balancers_inbound_nat_rules = {
        network_load_balancers_inbound_nat_rules = ["properties.idleTimeoutInMinutes"]
      }
    }
    retry    = { error_message_regex = ["RetryableError"], interval_seconds = 3, max_interval_seconds = 12 }
    timeouts = { create = "41m", read = "4m", update = "42m", delete = "11m" }
  }
  assert {
    condition     = length(module.backend_address_pool) == 1 && length(module.inbound_nat_rule) == 1 && azapi_resource.lock[0].body.properties.level == "CanNotDelete" && length(azapi_resource.role_assignments) == 1 && time_sleep.lock_removal[0].destroy_duration == "30s"
    error_message = "Child composition must remain available alongside RBAC and the lock removal barrier."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "rejects_inline_rule_reference_cycle" {
  command = plan
  variables {
    lb_rules = {
      web = {
        frontend_ip_configuration_name    = "internal"
        backend_address_pool_object_names = ["app"]
      }
    }
  }
  expect_failures = [azapi_resource.this]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "rejects_inline_outbound_reference_cycle_even_by_id" {
  command = plan
  variables {
    lb_outbound_rules = {
      internet = {
        frontend_ip_configurations       = [{ name = "internal" }]
        backend_address_pool_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/backendAddressPools/azure-pool"
      }
    }
  }
  expect_failures = [azapi_resource.this]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "retains_inline_pool_support_without_double_ownership" {
  command   = apply
  state_key = "inline-coupled"
  variables {
    backend_address_pool_child_modules_enabled = false
    lb_rules = {
      web = {
        frontend_ip_configuration_name    = "internal"
        backend_address_pool_object_names = ["app"]
      }
    }
  }
  assert {
    condition     = length(module.backend_address_pool) == 0 && length(module.inbound_nat_rule) == 1 && azapi_resource.this.body.properties.backendAddressPools[0].name == "azure-pool"
    error_message = "Coupled inline rules must keep their pool in the first parent PUT while NAT remains composed."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
