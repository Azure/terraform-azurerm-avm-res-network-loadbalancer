mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}
variables {
  location         = "eastus2"
  name             = "app"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
  properties       = {}
  enable_telemetry = false
}
run "default_pool" {
  command = apply
  assert {
    condition     = length(azapi_resource.this.body.properties.loadBalancerBackendAddresses) == 0 && length(azapi_resource.this.body.properties.tunnelInterfaces) == 0 && output.resource_id != null
    error_message = "Empty pool defaults and scalar ID output must be supported."
  }
  assert {
    condition     = azapi_resource.this.locks == tolist([var.parent_id]) && !contains(keys(azapi_resource.this.body.properties), "backendIPConfigurations")
    error_message = "Pool operations must share the LB mutex and must not write NIC-owned back references."
  }
}
run "pool_addresses_and_controls" {
  command = apply
  variables {
    properties = {
      virtualNetwork               = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab" }
      loadBalancerBackendAddresses = [{ name = "app", properties = { ipAddress = "10.0.0.4" } }]
      tunnelInterfaces             = [{ identifier = 800, port = 10800, protocol = "VXLAN", type = "Internal" }]
    }
    retry          = { error_message_regex = ["RetryableError"], interval_seconds = 5 }
    timeouts       = { create = "1h", delete = "30m" }
    resource_types = { network_load_balancers_backend_address_pools = "Microsoft.Network/loadBalancers/backendAddressPools@2024-10-01" }
  }
  assert {
    condition     = azapi_resource.this.body.properties.loadBalancerBackendAddresses[0].properties.ipAddress == "10.0.0.4" && azapi_resource.this.body.properties.tunnelInterfaces[0].identifier == 800 && azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.this.timeouts.delete == "30m" && endswith(azapi_resource.this.type, "@2024-10-01")
    error_message = "Pool ARM shapes and nondefault controls must reach the resource."
  }
}
run "invalid_parent" {
  command = plan
  variables { parent_id = "/invalid" }
  expect_failures = [var.parent_id]
}
run "invalid_vnet" {
  command = plan
  variables { properties = { virtualNetwork = { id = "/invalid" } } }
  expect_failures = [var.properties]
}
