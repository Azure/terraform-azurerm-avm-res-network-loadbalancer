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
run "partial_controls_and_consumer_ignore" {
  command = apply
  variables {
    retry    = { error_message_regex = ["RetryableError"], max_interval_seconds = 17 }
    timeouts = { read = "6m", update = "41m" }
  }
  assert {
    condition     = azapi_resource.this.retry.max_interval_seconds == 17 && var.retry.interval_seconds == null && azapi_resource.this.retry.error_message_regex == tolist(["RetryableError"]) && azapi_resource.this.timeouts.read == "6m" && azapi_resource.this.timeouts.update == "41m" && azapi_resource.this.timeouts.create == null && azapi_resource.this.timeouts.delete == null
    error_message = "Partial controls must not invent values; consumer ignores must be accepted without asserting provider-private state."
  }
}
run "consumer_ignore_paths_accepted" {
  command = apply
  variables {
    ignore_body_changes = { network_load_balancers_backend_address_pools = ["properties.tunnelInterfaces"] }
  }
  assert {
    condition     = var.ignore_body_changes.network_load_balancers_backend_address_pools == tolist(["properties.tunnelInterfaces"])
    error_message = "Consumer paths must be accepted; the write-only argument cannot be verified through state."
  }
}
run "explicit_null_controls_and_empty_address_removal" {
  command = apply
  variables {
    properties          = { virtualNetwork = null, tunnelInterfaces = null, loadBalancerBackendAddresses = [] }
    retry               = null
    timeouts            = null
    resource_types      = { network_load_balancers_backend_address_pools = null }
    ignore_body_changes = { network_load_balancers_backend_address_pools = [] }
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && endswith(azapi_resource.this.type, "@2025-01-01") && azapi_resource.this.body.properties.virtualNetwork == null && length(azapi_resource.this.body.properties.loadBalancerBackendAddresses) == 0 && length(azapi_resource.this.body.properties.tunnelInterfaces) == 0
    error_message = "Null optional controls use owning defaults; empty address lists remain explicit removals, not omitted lists."
  }
}
run "invalid_address_vnet" {
  command = plan
  variables {
    properties = { loadBalancerBackendAddresses = [{ name = "bad", properties = { ipAddress = "10.0.0.4", virtualNetwork = { id = "/invalid" } } }] }
  }
  expect_failures = [var.properties]
}
