# Payload and source-graph regressions only, not Azure lifecycle proof.
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
  sku_tier         = "Global"
  enable_telemetry = false
  frontend_ip_configurations = {
    public = { name = "public", public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/global" }
  }
  backend_address_pools = {
    regions = { name = "regions", backend_address_type = "Frontend" }
  }
  backend_address_pool_addresses = {
    west = {
      name                                                = "west"
      backend_address_pool_object_name                    = "regions"
      load_balancer_frontend_ip_configuration_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/west/frontendIPConfigurations/public"
    }
    east = {
      name                                                = "east"
      backend_address_pool_object_name                    = "regions"
      load_balancer_frontend_ip_configuration_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/east/frontendIPConfigurations/public"
    }
  }
  lb_rules = {
    http = { frontend_ip_configuration_name = "public", backend_address_pool_object_names = ["regions"], frontend_port = 80, backend_port = 80, disable_outbound_snat = true }
  }
}

run "dedicated_owner_and_bootstrap" {
  command = apply
  variables {
    resource_types = { network_load_balancers_backend_address_pools = "Microsoft.Network/loadBalancers/backendAddressPools@2024-10-01" }
    retry          = { error_message_regex = ["RetryableError"] }
    timeouts       = { create = "41m", delete = "17m" }
    lock           = { kind = "CanNotDelete" }
  }
  assert {
    condition = (
      length(azapi_update_resource.backend_members) == 1 &&
      azapi_update_resource.backend_members["regions"].resource_id == local.pool_ids.regions &&
      !azapi_update_resource.backend_members["regions"].ignore_missing_property &&
      keys(azapi_update_resource.backend_members["regions"].body.properties) == ["loadBalancerBackendAddresses"] &&
      alltrue([for p in azapi_resource.this.body.properties.backendAddressPools : !contains(keys(p.properties), "loadBalancerBackendAddresses") && !contains(keys(p.properties), "backendIPConfigurations")]) &&
      azapi_resource.this.body.properties.loadBalancingRules[0].properties.backendAddressPool.id == local.pool_ids.regions &&
      azapi_resource.this.body.properties.loadBalancingRules[0].properties.backendAddressPools == null &&
      output.backend_address_pool_resource_ids.regions == local.pool_ids.regions
    )
    error_message = "The parent must bootstrap pool metadata/rules without member fields; only a refreshing dedicated endpoint owns explicit lists."
  }
  assert {
    condition = (
      [for a in azapi_update_resource.backend_members["regions"].body.properties.loadBalancerBackendAddresses : a.name] == ["east", "west"] &&
      alltrue([for a in azapi_update_resource.backend_members["regions"].body.properties.loadBalancerBackendAddresses :
        contains(keys(a.properties), "loadBalancerFrontendIPConfiguration") &&
        !contains(keys(a.properties), "ipAddress") &&
        !contains(keys(a.properties), "networkInterfaceIPConfiguration")
      ]) &&
      length(azapi_resource.this.body.properties.probes) == 0 &&
      azapi_resource.this.body.properties.loadBalancingRules[0].properties.probe == null
    )
    error_message = "Global members must contain writable actual regional frontend IDs, without IP/NIC snapshots or Global probe references."
  }
  assert {
    condition = (
      azapi_resource_action.clear_backend_members["regions"].when == "destroy" &&
      azapi_resource_action.clear_backend_members["regions"].method == "PUT" &&
      length(azapi_resource_action.clear_backend_members["regions"].body.properties.loadBalancerBackendAddresses) == 0 &&
      azapi_resource_action.clear_backend_members["regions"].resource_id == azapi_update_resource.backend_members["regions"].resource_id &&
      azapi_update_resource.backend_members["regions"].locks == tolist([local.resource_id]) &&
      azapi_resource_action.clear_backend_members["regions"].locks == tolist([local.resource_id]) &&
      azapi_update_resource.backend_members["regions"].type == var.resource_types.network_load_balancers_backend_address_pools &&
      azapi_resource_action.clear_backend_members["regions"].type == var.resource_types.network_load_balancers_backend_address_pools &&
      azapi_update_resource.backend_members["regions"].retry.error_message_regex == var.retry.error_message_regex &&
      azapi_resource_action.clear_backend_members["regions"].retry.error_message_regex == var.retry.error_message_regex &&
      azapi_update_resource.backend_members["regions"].timeouts == var.timeouts &&
      azapi_resource_action.clear_backend_members["regions"].timeouts == var.timeouts
    )
    error_message = "One fixed-empty cleanup action must share endpoint, mutex and supported controls, not replay former members or pretend to refresh."
  }
  assert {
    condition = (
      var.lock != null &&
      can(regex("events\\s*=\\s*\\[before_create, before_update\\]", file("main.backend_members.tf"))) &&
      strcontains(file("main.backend_members.tf"), "action.azapi_resource_action.write_backend_members[each.key]") &&
      can(regex("on_failure\\s*=\\s*halt", file("main.backend_members.tf"))) &&
      strcontains(file("main.backend_members.tf"), "properties = merge({ for key, value in local.backend_pool_properties[each.key] : key => value if value != null }, {") &&
      can(regex("replace_triggered_by\\s*=\\s*\\[azapi_resource.this\\]", file("main.backend_members.tf"))) &&
      strcontains(file("main.interfaces.tf"), "azapi_resource_action.clear_backend_members,") &&
      strcontains(file("main.interfaces.tf"), "azapi_update_resource.backend_members,")
    )
    error_message = "Exact writes must precede refreshing-owner create/update, halt on failure, retain configured metadata and keep existing parent/cleanup ordering. This source guard is not provider request or live graph proof."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "remove_one_frontend" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      west = { name = "west", backend_address_pool_object_name = "regions", load_balancer_frontend_ip_configuration_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/west/frontendIPConfigurations/public" }
    }
  }
  assert {
    condition     = length(azapi_update_resource.backend_members["regions"].body.properties.loadBalancerBackendAddresses) == 1 && endswith(azapi_update_resource.backend_members["regions"].body.properties.loadBalancerBackendAddresses[0].properties.loadBalancerFrontendIPConfiguration.id, "/west/frontendIPConfigurations/public")
    error_message = "Removing east must retain exactly the real west frontend reference."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "clear_last_frontend" {
  command = apply
  variables {
    backend_address_pool_addresses = {}
  }
  assert {
    condition     = length(azapi_update_resource.backend_members["regions"].body.properties.loadBalancerBackendAddresses) == 0 && length(azapi_resource_action.clear_backend_members) == 1
    error_message = "Empty desired membership must be an authoritative [] with cleanup retained."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "restore_frontends_after_empty" {
  command = apply
  assert {
    condition     = [for a in azapi_update_resource.backend_members["regions"].body.properties.loadBalancerBackendAddresses : a.name] == ["east", "west"]
    error_message = "Restoring from [] must retain the refreshing owner and restore both configured frontend names."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "same_count_frontend_rename_retarget" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      east = { name = "renamed", backend_address_pool_object_name = "regions", load_balancer_frontend_ip_configuration_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/west/frontendIPConfigurations/other" }
      west = { name = "west", backend_address_pool_object_name = "regions", load_balancer_frontend_ip_configuration_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/east/frontendIPConfigurations/public" }
    }
  }
  assert {
    condition = (
      [for a in local.backend_pool_members.regions : a.name] == ["renamed", "west"] &&
      endswith(local.backend_pool_members.regions[0].properties.loadBalancerFrontendIPConfiguration.id, "/west/frontendIPConfigurations/other") &&
      alltrue([for a in local.backend_pool_members.regions : !contains(keys(a.properties), "ipAddress") && !contains(keys(a.properties), "networkInterfaceIPConfiguration")])
    )
    error_message = "Same-cardinality frontend changes must be built from configuration without old synthesized IP or NIC properties."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_two_member_forms" {
  command = plan
  variables {
    backend_address_pool_addresses = {
      bad = { name = "bad", backend_address_pool_object_name = "regions", ip_address = "10.0.0.4", load_balancer_frontend_ip_configuration_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/west/frontendIPConfigurations/public" }
    }
  }
  expect_failures = [var.backend_address_pool_addresses]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_wrong_frontend_type" {
  command = plan
  variables {
    backend_address_pool_addresses = {
      bad = { name = "bad", backend_address_pool_object_name = "regions", load_balancer_frontend_ip_configuration_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/west" }
    }
  }
  expect_failures = [var.backend_address_pool_addresses]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_null_member_forms" {
  command = plan
  variables {
    backend_address_pool_addresses = { bad = { name = "bad", backend_address_pool_object_name = "regions", ip_address = null, load_balancer_frontend_ip_configuration_resource_id = null } }
  }
  expect_failures = [var.backend_address_pool_addresses]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_regional_frontend_pool" {
  command = plan
  variables {
    sku_tier = "Regional"
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_native_pool" {
  command = plan
  variables {
    backend_address_pools          = { regions = { name = "regions", backend_address_type = "NIC" } }
    backend_address_pool_addresses = {}
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_health_probe" {
  command = plan
  variables {
    lb_probes = { health = { port = 80 } }
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_external_probe_reference" {
  command = plan
  variables {
    lb_rules = { http = { frontend_ip_configuration_name = "public", backend_address_pool_object_names = ["regions"], probe_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/probes/health" } }
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_outbound" {
  command = plan
  variables {
    lb_outbound_rules = { internet = { frontend_ip_configurations = [{ name = "public" }], backend_address_pool_object_name = "regions" } }
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_nat" {
  command = plan
  variables {
    lb_nat_rules = { ssh = { frontend_ip_configuration_name = "public", frontend_port = 22, backend_port = 22 } }
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_tcp_reset" {
  command = plan
  variables {
    lb_rules = { http = { frontend_ip_configuration_name = "public", backend_address_pool_object_names = ["regions"], enable_tcp_reset = true } }
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_port_translation" {
  command = plan
  variables {
    lb_rules = { http = { frontend_ip_configuration_name = "public", backend_address_pool_object_names = ["regions"], frontend_port = 81, backend_port = 80 } }
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reject_global_multiple_pools" {
  command = plan
  variables {
    lb_rules = { http = { frontend_ip_configuration_name = "public", backend_address_pool_object_names = ["regions", "regions"] } }
  }
  expect_failures = [var.sku_tier]
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "remove_whole_pool" {
  command = apply
  variables {
    backend_address_pools          = {}
    backend_address_pool_addresses = {}
    lb_rules                       = {}
  }
  assert {
    condition     = length(azapi_update_resource.backend_members) == 0 && length(azapi_resource_action.clear_backend_members) == 0 && length(azapi_resource.this.body.properties.backendAddressPools) == 0
    error_message = "Individual removal must remove partial bindings and include an explicit empty parent collection."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
