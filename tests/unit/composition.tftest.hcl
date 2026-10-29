# These mocks verify request construction, not provider refresh or Azure no-op
# plans. Protected verify-composition-local.ps1 compares verbose run bodies.
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
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab"
  location         = "eastus2"
  enable_telemetry = false
  backend_address_pools = {
    z = { name = "z-pool" }
    a = { name = "a-pool" }
  }
  frontend_ip_configurations = {
    z = { name = "z-front", public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/z" }
    a = { name = "a-front", public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/a" }
  }
  lb_probes = {
    health = { name = "health", port = 8080 }
  }
  lb_rules = {
    web = { name = "web", frontend_ip_configuration_name = "a-front", backend_address_pool_object_names = ["z", "a"], probe_object_name = "health", disable_outbound_snat = true }
  }
  lb_nat_rules = {
    admin = { name = "ssh", frontend_ip_configuration_name = "a-front", frontend_port_start = 50000, frontend_port_end = 50100, backend_port = 22, backend_address_pool_object_name = "a" }
  }
  lb_outbound_rules = {
    internet = { name = "internet", frontend_ip_configurations = [{ name = "z-front" }, { name = "a-front" }], backend_address_pool_object_name = "a" }
  }
}

run "complete_parent_body" {
  command = apply
  assert {
    condition = (
      [for p in azapi_resource.this.body.properties.backendAddressPools : p.name] == ["a-pool", "z-pool"] &&
      [for f in azapi_resource.this.body.properties.frontendIPConfigurations : f.name] == ["a-front", "z-front"] &&
      azapi_resource.this.body.properties.inboundNatRules[0].name == "ssh" &&
      azapi_resource.this.body.properties.inboundNatRules[0].properties.backendAddressPool.id == local.pool_ids.a &&
      azapi_resource.this.body.properties.loadBalancingRules[0].properties.backendAddressPools[0].id == local.pool_ids.a &&
      azapi_resource.this.body.properties.outboundRules[0].properties.backendAddressPool.id == local.pool_ids.a
    )
    error_message = "All coupled collections must be present in one parent request, ordered by stable map keys with sorted references."
  }
  assert {
    condition     = output.backend_address_pool_resource_ids.a == local.pool_ids.a && endswith(output.inbound_nat_rule_resource_ids.admin, "/inboundNatRules/ssh") && azapi_resource.this.locks == tolist([local.resource_id])
    error_message = "Keyed IDs must refer to the parent-owned children and the parent must retain its resource mutex."
  }
  assert {
    condition     = azapi_resource.this.ignore_null_property && alltrue([for p in azapi_resource.this.body.properties.backendAddressPools : !contains(keys(p.properties), "backendIPConfigurations") && !contains(keys(p.properties), "provisioningState")]) && !contains(keys(azapi_resource.this.body.properties.inboundNatRules[0].properties), "backendIPConfiguration")
    error_message = "Null optional properties must be omitted on the wire and service-owned NIC back-references must not be written."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "identical_inputs" {
  command = apply
  assert {
    condition     = azapi_resource.this.body.properties.inboundNatRules[0].properties.frontendPortRangeStart == 50000 && azapi_resource.this.body.properties.probes[0].properties.port == 8080
    error_message = "Identical inputs must retain the same configured properties."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "reordered_maps_and_references" {
  command = apply
  variables {
    backend_address_pools = {
      a = { name = "a-pool" }
      z = { name = "z-pool" }
    }
    frontend_ip_configurations = {
      a = { name = "a-front", public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/a" }
      z = { name = "z-front", public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/z" }
    }
    lb_rules = {
      web = { name = "web", frontend_ip_configuration_name = "a-front", backend_address_pool_object_names = ["a", "z"], probe_object_name = "health", disable_outbound_snat = true }
    }
    lb_outbound_rules = {
      internet = { name = "internet", frontend_ip_configurations = [{ name = "a-front" }, { name = "z-front" }], backend_address_pool_object_name = "a" }
    }
  }
  assert {
    condition     = [for p in azapi_resource.this.body.properties.backendAddressPools : p.name] == ["a-pool", "z-pool"] && endswith(azapi_resource.this.body.properties.outboundRules[0].properties.frontendIPConfigurations[0].id, "/a-front")
    error_message = "Map declaration order and equivalent reference order must not change the constructed request."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "mutable_rule_and_tag_change" {
  command = apply
  variables {
    tags = { purpose = "mutable-check" }
    lb_nat_rules = {
      admin = { name = "ssh", frontend_ip_configuration_name = "a-front", frontend_port_start = 51000, frontend_port_end = 51100, backend_port = 2222, backend_address_pool_object_name = "a" }
    }
  }
  assert {
    condition     = azapi_resource.this.body.properties.inboundNatRules[0].properties.backendPort == 2222 && azapi_resource.this.tags.purpose == "mutable-check"
    error_message = "Managed NAT edits must reach the parent body, not an ignored placeholder."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "adds_owned_pool_and_nat" {
  command = apply
  variables {
    backend_address_pools = { a = { name = "a-pool" }, z = { name = "z-pool" }, extra = { name = "new-pool" } }
    lb_nat_rules = {
      admin = { name = "ssh", frontend_ip_configuration_name = "a-front", frontend_port_start = 50000, frontend_port_end = 50100, backend_port = 22, backend_address_pool_object_name = "a" }
      new   = { name = "new-nat", frontend_ip_configuration_name = "z-front", frontend_port = 50222, backend_port = 22 }
    }
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.backendAddressPools) == 3 && length(azapi_resource.this.body.properties.inboundNatRules) == 2 && contains([for p in azapi_resource.this.body.properties.backendAddressPools : p.name], "new-pool")
    error_message = "New children must be included in the authoritative body without imports or second writers."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "removes_owned_collections" {
  command = apply
  variables {
    backend_address_pools = {}
    lb_rules              = {}
    lb_probes             = {}
    lb_nat_rules          = {}
    lb_outbound_rules     = {}
  }
  assert {
    condition     = alltrue([for k in ["backendAddressPools", "probes", "loadBalancingRules", "inboundNatRules", "outboundRules", "inboundNatPools"] : length(azapi_resource.this.body.properties[k]) == 0])
    error_message = "Empty configured collections must remain empty lists (not omission/preservation) so removal is managed."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "frontend_edit_not_in_immutable_triggers" {
  command = apply
  variables {
    frontend_ip_configurations = {
      a = { name = "a-front", public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/replacement-pip" }
      z = { name = "z-front", public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/z" }
    }
  }
  assert {
    condition     = azapi_resource.this.replace_triggers_refs == tolist(["sku.name", "sku.tier"]) && sort(keys(azapi_resource.this.replace_triggers_external_values)) == tolist(["edge_zone", "sku", "sku_tier"])
    error_message = "Only deliberate immutable inputs belong to replacement triggers, never a frontend/child collection."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "immutable_sku_change" {
  command = apply
  variables {
    sku = "Gateway"
  }
  assert {
    condition     = azapi_resource.this.body.sku.name == "Gateway" && azapi_resource.this.replace_triggers_external_values.sku == "Gateway"
    error_message = "SKU changes must be represented in both the body and stable immutable controls."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "immutable_tier_change" {
  command = apply
  variables {
    sku_tier = "Global"
  }
  assert {
    condition     = azapi_resource.this.body.sku.tier == "Global" && azapi_resource.this.replace_triggers_external_values.sku_tier == "Global"
    error_message = "Tier changes must reach immutable controls."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "immutable_edge_zone_change" {
  command = apply
  variables {
    edge_zone = "example-edge"
  }
  assert {
    condition     = azapi_resource.this.body.extendedLocation.name == "example-edge" && azapi_resource.this.replace_triggers_external_values.edge_zone == "example-edge"
    error_message = "Edge-zone null-to-value transitions must remain replacement-relevant."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "edge_zone_return_to_null" {
  command = apply
  assert {
    condition     = !contains(keys(azapi_resource.this.body), "extendedLocation") && azapi_resource.this.replace_triggers_external_values.edge_zone == null
    error_message = "Edge-zone removal must retain null inside the non-null replacement object."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "root_controls_with_interfaces" {
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
    resource_types = { network_load_balancers = "Microsoft.Network/loadBalancers@2024-10-01" }
    retry          = { error_message_regex = ["RetryableError"], interval_seconds = 3, max_interval_seconds = 12 }
    timeouts       = { create = "41m", read = "4m", update = "42m", delete = "11m" }
  }
  assert {
    condition     = azapi_resource.this.type == "Microsoft.Network/loadBalancers@2024-10-01" && azapi_resource.this.retry.interval_seconds == 3 && azapi_resource.this.timeouts.update == "42m" && azapi_resource.lock[0].body.properties.level == "CanNotDelete" && length(azapi_resource.role_assignments) == 1 && time_sleep.lock_removal[0].destroy_duration == "30s"
    error_message = "Root-owned collections must coexist with root controls, RBAC and the lock removal barrier."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
