# Payload regression only: mocks do not execute the provider HTTP path or ARM.
# The failed real addition remains FAIL even when every assertion here passes.
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
  location         = "westus2"
  enable_telemetry = false
  frontend_ip_configurations = {
    public = { public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/public" }
  }
  backend_address_pools = {
    app      = { name = "app", backend_address_type = "NIC" }
    ip       = { name = "ip", backend_address_type = "IP" }
    retained = { name = "retained", backend_address_type = "NIC" }
  }
  backend_address_pool_configuration = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab"
}

run "original_ip_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      static = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.10" }
    }
  }
  assert {
    condition = (
      length(local.backend_pool_properties.ip.loadBalancerBackendAddresses) == 1 &&
      local.backend_pool_properties.ip.loadBalancerBackendAddresses[0].properties.virtualNetwork.id == var.backend_address_pool_configuration &&
      local.backend_pool_properties.app.loadBalancerBackendAddresses == null &&
      local.backend_pool_properties.retained.loadBalancerBackendAddresses == null
    )
    error_message = "The IP pool must have a concrete member/VNet; separate NIC projections must remain unspecified."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "exact_failed_addition_payload_not_persistence" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      static = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.10" }
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.11" }
    }
  }
  assert {
    condition = (
      { for a in azapi_resource.this.body.properties.backendAddressPools[1].properties.loadBalancerBackendAddresses : a.name => a.properties.ipAddress } == jsondecode(file("tests/fixtures/ip-member-persistence.json")).expected &&
      jsondecode(file("tests/fixtures/ip-member-persistence.json")).observed != jsondecode(file("tests/fixtures/ip-member-persistence.json")).expected &&
      jsondecode(file("tests/fixtures/ip-member-persistence.json")).result == "FAIL" &&
      azapi_resource.this.ignore_body_changes == null &&
      azapi_resource.this.ignore_other_items_in_list == null &&
      alltrue([for a in local.backend_pool_properties.ip.loadBalancerBackendAddresses :
        a.properties.virtualNetwork.id == var.backend_address_pool_configuration &&
        !contains(keys(a.properties), "networkInterfaceIPConfiguration")
      ])
    )
    error_message = "Reproduce the failed desired list without filtering members or mistaking the historical GET mismatch for success."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "update_member_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      static = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.10" }
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.12" }
    }
  }
  assert {
    condition = (
      { for a in local.backend_pool_properties.ip.loadBalancerBackendAddresses : a.name => a.properties.ipAddress } == { second = "10.40.1.12", static = "10.40.1.10" } &&
      local.backend_pool_properties.app.loadBalancerBackendAddresses == null &&
      local.backend_pool_properties.retained.loadBalancerBackendAddresses == null
    )
    error_message = "Updating one IP must retain the other IP without writing NIC projections."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "remove_one_member_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.12" }
    }
  }
  assert {
    condition     = { for a in local.backend_pool_properties.ip.loadBalancerBackendAddresses : a.name => a.properties.ipAddress } == { second = "10.40.1.12" }
    error_message = "Removing static must retain exactly second; deletion cannot be represented by omission of the whole list."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "last_member_clear_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {}
  }
  assert {
    condition = (
      length(azapi_resource.this.body.properties.backendAddressPools[1].properties.loadBalancerBackendAddresses) == 0 &&
      azapi_resource.this.body.properties.backendAddressPools[1].properties.loadBalancerBackendAddresses != null &&
      var.backend_address_pools.ip.backend_address_type == "IP" &&
      local.backend_pool_properties.app.loadBalancerBackendAddresses == null &&
      local.backend_pool_properties.retained.loadBalancerBackendAddresses == null &&
      azapi_resource.this.ignore_body_changes == null
    )
    error_message = "Last-member removal must emit a compared [] in IP mode, not null, NIC mode or an ignore."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
