mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource_list" {
    defaults = {
      output = {
        results = [{
          role_name = "Reader"
          id        = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        }]
      }
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

run "telemetry_enabled" {
  command = apply
  variables {
    enable_telemetry = true
  }
  assert {
    condition     = length(azapi_resource.telemetry) == 1 && azapi_resource.telemetry[0].body.properties.mode == "Incremental" && length(azapi_resource.telemetry[0].body.properties.template.resources) == 0
    error_message = "Enabled managed telemetry must use an empty incremental subscription deployment."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "frontend_addition_does_not_replace_lb" {
  command = apply
  variables {
    frontend_ip_configurations = {
      internal = {
        name                                   = "internal"
        frontend_private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/default"
      }
      secondary = {
        name                                   = "secondary"
        frontend_private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/default"
        zones                                  = ["None"]
      }
    }
  }
  assert {
    condition     = !contains(keys(azapi_resource.this.replace_triggers_external_values), "frontend_zones") && length(azapi_resource.this.body.properties.frontendIPConfigurations) == 2
    error_message = "Adding a frontend must not add a whole-collection replacement trigger."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

variables {
  name             = "lab"
  location         = "eastus2"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab"
  enable_telemetry = false
  frontend_ip_configurations = {
    internal = {
      name                                   = "internal"
      frontend_private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/default"
    }
  }
}

run "defaults_and_empty_outputs" {
  command = apply
  assert {
    condition     = length(output.backend_address_pool_resource_ids) == 0 && length(output.probe_resource_ids) == 0 && length(output.inbound_nat_rule_resource_ids) == 0 && length(output.outbound_rule_resource_ids) == 0
    error_message = "Empty child collections must return empty maps."
  }
  assert {
    condition     = azapi_resource.this.body.sku.name == "Standard" && azapi_resource.this.body.sku.tier == "Regional"
    error_message = "SKU defaults must be Standard/Regional."
  }
  assert {
    condition     = local.frontend_properties.internal.privateIPAllocationMethod == "Dynamic" && local.frontend_properties.internal.privateIPAddressVersion == "IPv4" && local.frontend_properties.internal.publicIPAddress == null
    error_message = "Private frontend defaults must be Dynamic/IPv4 and omit public IP."
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.frontendIPConfigurations) == 1 && length(azapi_resource.this.body.properties.backendAddressPools) == 0
    error_message = "The parent must configure the requested inline collections."
  }
  assert {
    condition     = length(azapi_resource.lock) == 0 && length(azapi_resource.role_assignments) == 0 && length(azapi_resource.diagnostic_settings) == 0 && length(azapi_resource.telemetry) == 0
    error_message = "Optional interfaces and telemetry must not create resources when disabled."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "all_child_shapes_and_nondefaults" {
  command = apply
  variables {
    tags = { owner = "test" }
    backend_address_pools = {
      app = {
        name                        = "web-pool"
        virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab"
      }
      batch = { name = "worker-pool" }
    }
    backend_address_pool_addresses = {
      web = {
        name                             = "web"
        backend_address_pool_object_name = "app"
        ip_address                       = "10.0.0.4"
      }
    }
    lb_probes = {
      health = { name = "health", protocol = "Https", port = 443, request_path = "/ready", probe_threshold = 3, interval_in_seconds = 10, number_of_probes_before_removal = 4 }
    }
    lb_rules = {
      web = {
        name                              = "web", frontend_ip_configuration_name = "internal", frontend_port = 443, backend_port = 8443
        backend_address_pool_object_names = ["app"], probe_object_name = "health"
        enable_floating_ip                = true, enable_tcp_reset = true, disable_outbound_snat = true
        idle_timeout_in_minutes           = 15, load_distribution = "SourceIPProtocol"
      }
    }
    lb_nat_rules = {
      admin = { name = "admin", frontend_ip_configuration_name = "internal", frontend_port_start = 50000, frontend_port_end = 50100, backend_port = 22, backend_address_pool_object_name = "app", enable_tcp_reset = true }
    }
    lb_outbound_rules = {
      egress = { name = "egress", frontend_ip_configurations = [{ name = "internal" }], backend_address_pool_object_name = "app", protocol = "All", number_of_allocated_outbound_ports = 2048, idle_timeout_in_minutes = 10, enable_tcp_reset = true }
    }
  }
  assert {
    condition     = toset(keys(output.backend_address_pool_resource_ids)) == toset(["app", "batch"]) && length(output.load_balancing_rule_resource_ids) == 1 && length(output.inbound_nat_rule_resource_ids) == 1 && length(output.outbound_rule_resource_ids) == 1
    error_message = "Parent cardinality and stable consumer keys must be preserved."
  }
  assert {
    condition     = local.backend_pool_properties.app.loadBalancerBackendAddresses[0].properties.ipAddress == "10.0.0.4" && local.backend_pool_properties.app.loadBalancerBackendAddresses[0].properties.virtualNetwork.id == var.backend_address_pools.app.virtual_network_resource_id
    error_message = "Backend address shape and VNet fallback must match the ARM contract."
  }
  assert {
    condition     = local.probe_properties.health.protocol == "Https" && local.probe_properties.health.requestPath == "/ready" && local.probe_properties.health.probeThreshold == 3 && local.probe_properties.health.numberOfProbes == 4
    error_message = "Probe nondefaults must map to correctly cased ARM fields."
  }
  assert {
    condition     = endswith(local.rule_properties.web.probe.id, "/probes/health") && endswith(local.rule_properties.web.backendAddressPools[0].id, "/backendAddressPools/web-pool") && local.rule_properties.web.disableOutboundSnat && local.rule_properties.web.enableTcpReset && local.rule_properties.web.enableFloatingIP && local.rule_properties.web.loadDistribution == "SourceIPProtocol" && local.rule_properties.web.backendPort == 8443
    error_message = "Rule references and nondefault ARM properties must survive conversion."
  }
  assert {
    condition     = local.nat_rule_properties.admin.frontendPort == null && local.nat_rule_properties.admin.frontendPortRangeStart == 50000 && endswith(local.nat_rule_properties.admin.backendAddressPool.id, "/backendAddressPools/web-pool")
    error_message = "NAT v2 must use range fields and a backend pool ID object."
  }
  assert {
    condition     = local.outbound_rule_properties.egress.allocatedOutboundPorts == 2048 && local.outbound_rule_properties.egress.protocol == "All" && length(local.outbound_rule_properties.egress.frontendIPConfigurations) == 1 && azapi_resource.this.tags.owner == "test"
    error_message = "Outbound shapes, nondefault ports and tags must be forwarded."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "external_probe_and_pool_references" {
  command = apply
  variables {
    lb_rules = {
      external = {
        frontend_ip_configuration_name    = "internal"
        probe_resource_id                 = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/other/probes/live"
        backend_address_pool_resource_ids = ["/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/other/backendAddressPools/live"]
      }
    }
    lb_nat_rules = {
      v1 = { frontend_ip_configuration_name = "internal", frontend_port = 50001, backend_port = 22 }
    }
  }
  assert {
    condition     = endswith(local.rule_properties.external.probe.id, "/other/probes/live") && local.nat_rule_properties.v1.frontendPort == 50001 && local.nat_rule_properties.v1.backendAddressPool == null
    error_message = "External probe fallback must not index a null probe key; scalar NAT must omit a pool."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "public_cross_scope_frontend" {
  command = apply
  variables {
    frontend_ip_configurations = {
      public = {
        public_ip_address_resource_id = "/subscriptions/11111111-1111-1111-1111-111111111111/resourceGroups/other/providers/Microsoft.Network/publicIPAddresses/existing"
      }
    }
  }
  assert {
    condition     = local.frontend_properties.public.publicIPAddress.id == var.frontend_ip_configurations.public.public_ip_address_resource_id && local.frontend_properties.public.privateIPAllocationMethod == null && local.frontend_properties.public.subnet == null
    error_message = "Cross-scope PIP IDs must be used verbatim without inventing scope or private defaults."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "interfaces_lock_rbac_diagnostics" {
  command = apply
  variables {
    lock = { kind = "CanNotDelete" }
    role_assignments = {
      reader = { role_definition_id_or_name = "rEaDeR", principal_id = "22222222-2222-2222-2222-222222222222", skip_service_principal_aad_check = true, description = "test" }
    }
    diagnostic_settings = {
      events = {
        logs                                     = [{ category = "LoadBalancerHealthEvent", enabled = false }, { category_group = "allLogs" }]
        metrics                                  = [{ category = "AllMetrics" }]
        event_hub_authorization_rule_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.EventHub/namespaces/events/authorizationRules/send"
        event_hub_name                           = "lb-events"
        log_analytics_destination_type           = "AzureDiagnostics"
      }
    }
    retry    = { error_message_regex = ["ScopeLocked"], interval_seconds = 5, max_interval_seconds = 30 }
    timeouts = { create = "45m", read = "5m", update = "45m", delete = "10m" }
  }
  assert {
    condition     = azapi_resource.lock[0].name == "lock-lab" && azapi_resource.lock[0].body.properties.notes == "Cannot delete the resource or its child resources." && time_sleep.lock_removal[0].destroy_duration == "30s"
    error_message = "Released lock name, notes and removal delay must be preserved."
  }
  assert {
    condition     = azapi_resource.role_assignments["reader"].body.properties.principalType == "ServicePrincipal" && endswith(azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId, "/acdd72a7-3385-48ef-bd42-f606fba81ae7")
    error_message = "Role names must resolve case-insensitively and skip-check must set principal type."
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["events"].body.properties.eventHubName == "lb-events" && azapi_resource.diagnostic_settings["events"].body.properties.logAnalyticsDestinationType == "AzureDiagnostics" && length(azapi_resource.diagnostic_settings["events"].body.properties.logs) == 2 && length(azapi_resource.diagnostic_settings["events"].body.properties.metrics) == 1
    error_message = "Diagnostics must preserve event hub names, category/group distinction and metrics."
  }
  assert {
    condition     = azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.lock[0].retry.max_interval_seconds == 30 && azapi_resource.diagnostic_settings["events"].timeouts.create == "45m"
    error_message = "Retry and timeouts must reach each root resource."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_parent" {
  command = plan
  variables {
    parent_id = "/not/a/resource/group"
  }
  expect_failures = [var.parent_id]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_frontend_id" {
  command = plan
  variables {
    frontend_ip_configurations = { bad = { public_ip_address_resource_id = "/bad" } }
  }
  expect_failures = [var.frontend_ip_configurations]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "duplicate_frontend_names" {
  command = plan
  variables {
    frontend_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/default"
    frontend_ip_configurations  = { a = {}, b = {} }
  }
  expect_failures = [var.frontend_ip_configurations]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_probe" {
  command = plan
  variables {
    lb_probes = { bad = { protocol = "Http" } }
  }
  expect_failures = [var.lb_probes]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_rule_reference" {
  command = plan
  variables {
    lb_rules = { bad = { frontend_ip_configuration_name = "missing" } }
  }
  expect_failures = [var.lb_rules]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_diagnostic_destination" {
  command = plan
  variables {
    diagnostic_settings = { bad = {} }
  }
  expect_failures = [var.diagnostic_settings]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_diagnostic_log" {
  command = plan
  variables {
    diagnostic_settings = {
      bad = { marketplace_partner_resource_id = "/providers/vendor/resource/test", logs = [{ category = "a", category_group = "allLogs" }] }
    }
  }
  expect_failures = [var.diagnostic_settings]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_lock" {
  command = plan
  variables {
    lock = { kind = "invalid" }
  }
  expect_failures = [var.lock]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "gateway_tunnels_and_static_ipv6_frontend" {
  command = apply
  variables {
    sku = "Gateway"
    frontend_ip_configurations = {
      internal = {
        name                                   = "internal"
        frontend_private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/default"
        frontend_private_ip_address            = "fd00::4"
        frontend_private_ip_address_allocation = "Static"
        frontend_private_ip_address_version    = "IPv6"
        zones                                  = ["None"]
      }
    }
    backend_address_pools = {
      appliances = {
        name = "appliances"
        tunnel_interfaces = {
          internal = { identifier = 800, port = 10800, protocol = "VXLAN", type = "Internal" }
          external = { identifier = 801, port = 10801, protocol = "VXLAN", type = "External" }
        }
      }
    }
  }
  assert {
    condition     = local.frontend_properties.internal.privateIPAddress == "fd00::4" && azapi_resource.this.body.properties.frontendIPConfigurations[0].zones == null && length(local.backend_pool_properties.appliances.tunnelInterfaces) == 2 && local.backend_pool_properties.appliances.tunnelInterfaces[0].protocol == "VXLAN"
    error_message = "IPv6/static/nonzonal and Gateway tunnel settings must retain their ARM shapes."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "nat_pools_are_inline" {
  command = apply
  variables {
    lb_nat_pools = {
      vmss = { name = "vmss", frontend_ip_configuration_name = "internal", frontend_port_start = 30000, frontend_port_end = 30100, backend_port = 22, enable_tcp_reset = true, enable_floating_ip = true, idle_timeout_in_minutes = 10 }
    }
  }
  assert {
    condition     = azapi_resource.this.body.properties.inboundNatPools[0].name == "vmss" && azapi_resource.this.body.properties.inboundNatPools[0].properties.frontendPortRangeStart == 30000 && azapi_resource.this.body.properties.inboundNatPools[0].properties.enableTcpReset
    error_message = "Legacy NAT pools must be inline LB properties, not invented child resources."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "explicit_role_id_and_custom_lock" {
  command = apply
  variables {
    lock = { kind = "ReadOnly", name = "existing-lock", notes = "existing notes" }
    role_assignments = {
      reader = {
        name                                   = "33333333-3333-3333-3333-333333333333"
        role_definition_id_or_name             = "/providers/Microsoft.Authorization/roleDefinitions/acdd72a7-3385-48ef-bd42-f606fba81ae7"
        principal_id                           = "22222222-2222-2222-2222-222222222222"
        principal_type                         = "Group"
        condition                              = "@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:name] StringEquals 'example'"
        condition_version                      = "2.0"
        delegated_managed_identity_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.ManagedIdentity/userAssignedIdentities/delegated"
      }
    }
  }
  assert {
    condition     = azapi_resource.lock[0].name == "existing-lock" && azapi_resource.lock[0].body.properties.notes == "existing notes" && azapi_resource.role_assignments["reader"].body.properties.principalType == "Group" && startswith(azapi_resource.role_assignments["reader"].body.properties.roleDefinitionId, "/subscriptions/00000000-0000-0000-0000-000000000000/") && azapi_resource.role_assignments["reader"].body.properties.conditionVersion == "2.0"
    error_message = "Custom lock notes, subscription-qualified role IDs and principal/condition settings must survive composition."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "diagnostic_workspace_storage_and_retention" {
  command = apply
  variables {
    diagnostic_settings = {
      destinations = {
        name                            = "existing-diag"
        workspace_resource_id           = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/logs"
        storage_account_resource_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Storage/storageAccounts/lablogs"
        marketplace_partner_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/vendor/type/partner"
        metrics                         = [{ category = "AllMetrics", enabled = false, retention_policy = { days = 7, enabled = true } }]
      }
    }
  }
  assert {
    condition     = azapi_resource.diagnostic_settings["destinations"].name == "existing-diag" && endswith(azapi_resource.diagnostic_settings["destinations"].body.properties.workspaceId, "/workspaces/logs") && endswith(azapi_resource.diagnostic_settings["destinations"].body.properties.storageAccountId, "/storageAccounts/lablogs") && azapi_resource.diagnostic_settings["destinations"].body.properties.metrics[0].retentionPolicy.days == 7 && !azapi_resource.diagnostic_settings["destinations"].body.properties.metrics[0].enabled && azapi_resource.diagnostic_settings["destinations"].body.properties.logs == null
    error_message = "Diagnostic destination IDs, retention objects, disabled metrics and omitted logs must be retained."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "resource_controls_and_empty_tags" {
  command = apply
  variables {
    tags           = {}
    resource_types = { network_load_balancers = "Microsoft.Network/loadBalancers@2024-10-01" }
    timeouts       = { update = "1h" }
    retry          = { error_message_regex = ["RetryableError"] }
    edge_zone      = "example-edge"
  }
  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/loadBalancers@2024-10-01" && length(azapi_resource.this.tags) == 0 && azapi_resource.this.body.extendedLocation.type == "EdgeZone" && azapi_resource.this.timeouts.update == "1h" && azapi_resource.this.retry.error_message_regex[0] == "RetryableError"
    error_message = "Resource version overrides, empty tags, edge zone and nullable partial controls must be honored."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_duplicate_pools" {
  command = plan
  variables {
    backend_address_pools = { a = { name = "same" }, b = { name = "same" } }
  }
  expect_failures = [var.backend_address_pools]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_address_reference" {
  command = plan
  variables {
    backend_address_pool_addresses = { bad = { name = "bad", backend_address_pool_object_name = "missing", ip_address = "10.0.0.4" } }
  }
  expect_failures = [var.backend_address_pool_addresses]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_outbound_reference" {
  command = plan
  variables {
    lb_outbound_rules = { bad = { frontend_ip_configurations = [{ name = "missing" }], backend_address_pool_resource_id = "/invalid" } }
  }
  expect_failures = [var.lb_outbound_rules]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_nat_mode" {
  command = plan
  variables {
    lb_nat_rules = { bad = { frontend_ip_configuration_name = "internal", frontend_port = 22, frontend_port_start = 30000, frontend_port_end = 30100, backend_port = 22 } }
  }
  expect_failures = [var.lb_nat_rules]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_diagnostic_workspace_id" {
  command = plan
  variables {
    diagnostic_settings = { bad = { workspace_resource_id = "/invalid" } }
  }
  expect_failures = [var.diagnostic_settings]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "invalid_delegated_identity" {
  command = plan
  variables {
    role_assignments = { bad = { role_definition_id_or_name = "Reader", principal_id = "22222222-2222-2222-2222-222222222222", delegated_managed_identity_resource_id = "/invalid" } }
  }
  expect_failures = [var.role_assignments]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
