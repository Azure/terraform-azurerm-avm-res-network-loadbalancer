# The response excerpts record the real failure, not optimistic mock defaults.
# Assertions pin the request + AzAPI controls needed by UpdateObject and
# RemoveNullProperty (AzAPI v2.13.0 utils/json.go). Mocks do NOT execute those
# provider functions, a PUT, a refresh or an upgrade. Independent live rerun is
# still mandatory, including a real NIC-owner write and IP-member removal.
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

variables {
  name             = "lab"
  location         = "eastus2"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab"
  enable_telemetry = false
  frontend_ip_configurations = {
    public = { public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/public" }
  }
}

run "nic_response_projection_is_unspecified_not_empty" {
  command = apply
  variables {
    backend_address_pools = {
      app      = { name = "app", backend_address_type = "NIC" }
      retained = { name = "retained", backend_address_type = "NIC" }
    }
  }
  assert {
    condition = (
      length(jsondecode(file("tests/fixtures/observed-normalization.json")).nic_pool.properties.loadBalancerBackendAddresses) == 1 &&
      can(jsondecode(file("tests/fixtures/observed-normalization.json")).nic_pool.properties.loadBalancerBackendAddresses[0].properties.networkInterfaceIPConfiguration.id) &&
      can(jsondecode(file("tests/fixtures/observed-normalization.json")).nic_pool.properties.loadBalancerBackendAddresses[0].properties.inboundNatRulesPortMapping) &&
      alltrue([for p in azapi_resource.this.body.properties.backendAddressPools : p.properties.loadBalancerBackendAddresses == null]) &&
      azapi_resource.this.ignore_null_property &&
      azapi_resource.this.ignore_body_changes == null &&
      azapi_resource.this.ignore_other_items_in_list == null
    )
    error_message = "NIC projections must be unspecified with null omission enabled, never [] or a blanket list ignore/replay of read-only NIC and NAT backrefs."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "omitted_null_and_explicit_ip_modes_keep_empty_lists" {
  command = apply
  variables {
    backend_address_pools = {
      omitted  = { name = "omitted" }
      nullable = { name = "nullable", backend_address_type = null }
      explicit = { name = "explicit", backend_address_type = "IP" }
    }
    backend_address_pool_addresses = {}
  }
  assert {
    condition = (
      alltrue([for p in azapi_resource.this.body.properties.backendAddressPools : p.properties.loadBalancerBackendAddresses != null && length(p.properties.loadBalancerBackendAddresses) == 0]) &&
      alltrue([for p in var.backend_address_pools : p.backend_address_type == "IP"]) &&
      azapi_resource.this.ignore_other_items_in_list == null
    )
    error_message = "Empty IP lists must still be sent/compared; absence/null mode must not silently delegate last-member removal."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "ip_addition_and_nic_projection_can_coexist_in_separate_pools" {
  command = apply
  variables {
    backend_address_pools = {
      app = { name = "app", backend_address_type = "NIC" }
      ip  = { name = "ip" }
    }
    backend_address_pool_addresses = {
      static = {
        name                             = "static"
        backend_address_pool_object_name = "ip"
        ip_address                       = "10.40.1.10"
        virtual_network_resource_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab"
      }
    }
  }
  assert {
    condition = (
      azapi_resource.this.body.properties.backendAddressPools[0].properties.loadBalancerBackendAddresses == null &&
      azapi_resource.this.body.properties.backendAddressPools[1].properties.loadBalancerBackendAddresses[0].properties.ipAddress == "10.40.1.10" &&
      !can(azapi_resource.this.body.properties.backendAddressPools[1].properties.loadBalancerBackendAddresses[0].properties.networkInterfaceIPConfiguration)
    )
    error_message = "IP configuration must remain writable on the IP pool without replaying NIC read-only properties."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "removing_last_ip_member_does_not_select_nic_mode" {
  command = apply
  variables {
    backend_address_pools = {
      app = { name = "app", backend_address_type = "NIC" }
      ip  = { name = "ip" }
    }
    backend_address_pool_addresses = {}
  }
  assert {
    condition     = azapi_resource.this.body.properties.backendAddressPools[0].properties.loadBalancerBackendAddresses == null && length(azapi_resource.this.body.properties.backendAddressPools[1].properties.loadBalancerBackendAddresses) == 0
    error_message = "Removing the last IP must leave an explicit authoritative [] beside an unspecified NIC projection."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_ip_members_on_nic_pool" {
  command = plan
  variables {
    backend_address_pools = { app = { backend_address_type = "NIC" } }
    backend_address_pool_addresses = {
      bad = { name = "bad", backend_address_pool_object_name = "app", ip_address = "10.40.1.10" }
    }
  }
  expect_failures = [var.backend_address_pool_addresses]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_unknown_pool_mode" {
  command = plan
  variables {
    backend_address_pools = { app = { backend_address_type = "" } }
  }
  expect_failures = [var.backend_address_pools]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_all_conflicting_nic_pools_among_valid_ip_members" {
  command = plan
  variables {
    backend_address_pools = {
      appliances = { name = "nvas", backend_address_type = "NIC" }
      app        = { name = "app", backend_address_type = "NIC" }
      ip         = { name = "static", backend_address_type = "IP" }
    }
    backend_address_pool_addresses = {
      nva_address = { name = "nva", backend_address_pool_object_name = "appliances", ip_address = "10.40.1.10" }
      app_address = { name = "app", backend_address_pool_object_name = "app", ip_address = "10.40.1.11" }
      valid       = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.12" }
    }
  }
  expect_failures = [var.backend_address_pool_addresses]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_lowercase_pool_mode" {
  command = plan
  variables {
    backend_address_pools = {
      app = { name = "app", backend_address_type = "nic" }
      ip  = { name = "ip", backend_address_type = "IP" }
    }
  }
  expect_failures = [var.backend_address_pools]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "omitted_null_empty_logs_do_not_compare_disabled_expansion" {
  command = apply
  variables {
    diagnostic_settings = {
      omitted  = { workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/logs", metrics = [{ category = "AllMetrics" }] }
      nullable = { workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/logs", logs = null, metrics = [{ category = "AllMetrics" }] }
      empty    = { workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/logs", logs = [], metrics = [{ category = "AllMetrics" }] }
    }
  }
  assert {
    condition = (
      alltrue([for l in jsondecode(file("tests/fixtures/observed-normalization.json")).lb_diagnostics.logs : !l.enabled && l.categoryGroup == null]) &&
      alltrue([for d in azapi_resource.diagnostic_settings :
        d.body.properties.logs == null && d.ignore_null_property &&
        d.body.properties.metrics[0].enabled && d.ignore_body_changes == null &&
        d.ignore_other_items_in_list == null
      ])
    )
    error_message = "Utility null entries must use provider null omission, not [] or blanket log ignores; explicitly configured metrics must remain managed."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_disabled_category_is_not_unspecified" {
  command = apply
  variables {
    diagnostic_settings = {
      logs = {
        workspace_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/logs"
        logs                  = [{ category = "LoadBalancerHealthEvent", enabled = false }]
      }
    }
  }
  assert {
    condition = (
      jsonencode(azapi_resource.diagnostic_settings["logs"].body.properties.logs) == jsonencode(jsondecode(file("tests/fixtures/observed-normalization.json")).lb_diagnostics.logs) &&
      azapi_resource.diagnostic_settings["logs"].list_unique_id_property["properties.logs"] == "category,categoryGroup" &&
      azapi_resource.diagnostic_settings["logs"].ignore_other_items_in_list == null
    )
    error_message = "An explicit disabled category must remain a concrete compared entry, matching the real disabled-category response."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "category_group_enabled_and_destinations_remain_managed" {
  command = apply
  variables {
    diagnostic_settings = {
      logs = {
        event_hub_authorization_rule_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.EventHub/namespaces/events/authorizationRules/send"
        event_hub_name                           = "sink"
        logs                                     = [{ category_group = "allLogs", enabled = true, retention_policy = { days = 7, enabled = true } }]
        metrics                                  = [{ category = "AllMetrics", enabled = false }]
      }
    }
  }
  assert {
    condition = (
      azapi_resource.diagnostic_settings["logs"].body.properties.logs[0].categoryGroup == "allLogs" &&
      azapi_resource.diagnostic_settings["logs"].body.properties.logs[0].enabled &&
      azapi_resource.diagnostic_settings["logs"].body.properties.logs[0].retentionPolicy.days == 7 &&
      azapi_resource.diagnostic_settings["logs"].body.properties.logs[0].retentionPolicy.enabled &&
      !azapi_resource.diagnostic_settings["logs"].body.properties.metrics[0].enabled &&
      azapi_resource.diagnostic_settings["logs"].body.properties.eventHubName == "sink" &&
      azapi_resource.diagnostic_settings["logs"].body.properties.eventHubAuthorizationRuleId == var.diagnostic_settings.logs.event_hub_authorization_rule_resource_id &&
      azapi_resource.diagnostic_settings["logs"].ignore_body_changes == null
    )
    error_message = "Null normalization must not suppress category/group, enabled, retention or destination changes."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
