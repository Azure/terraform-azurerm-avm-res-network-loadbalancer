mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}
variables {
  location  = "eastus2"
  name      = "ssh"
  parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
  properties = {
    frontendIPConfiguration = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/frontendIPConfigurations/public" }
    frontendPort            = 50000
    backendPort             = 22
  }
  enable_telemetry = false
}
run "scalar_nat_defaults" {
  command = apply
  assert {
    condition     = azapi_resource.this.body.properties.protocol == "Tcp" && azapi_resource.this.body.properties.frontendPort == 50000 && azapi_resource.this.body.properties.backendAddressPool == null && !azapi_resource.this.body.properties.enableTcpReset && output.resource_id != null
    error_message = "NAT v1 defaults and output must be supported."
  }
  assert {
    condition     = azapi_resource.this.ignore_null_property && azapi_resource.this.body.properties.frontendPortRangeStart == null && azapi_resource.this.body.properties.frontendPortRangeEnd == null && azapi_resource.this.locks == tolist([var.parent_id]) && !contains(keys(azapi_resource.this.body.properties), "backendIPConfiguration")
    error_message = "Scalar NAT must omit unspecified range/pool properties, share the LB mutex and exclude read-only NIC back references."
  }
}
run "range_nat_and_controls" {
  command = apply
  variables {
    properties = {
      frontendIPConfiguration = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/frontendIPConfigurations/public" }
      backendAddressPool      = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/backendAddressPools/app" }
      frontendPortRangeStart  = 50000
      frontendPortRangeEnd    = 50100
      backendPort             = 22
      enableTcpReset          = true
    }
    retry    = { error_message_regex = ["RetryableError"], interval_seconds = 5 }
    timeouts = { create = "1h", delete = "30m" }
  }
  assert {
    condition     = azapi_resource.this.ignore_null_property && azapi_resource.this.body.properties.frontendPort == null && azapi_resource.this.body.properties.frontendPortRangeStart == 50000 && azapi_resource.this.body.properties.frontendPortRangeEnd == 50100 && azapi_resource.this.body.properties.enableTcpReset && azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.this.timeouts.create == "1h"
    error_message = "Range NAT must omit an unspecified scalar port so Azure's returned zero does not cause drift, while managing explicit ranges and controls."
  }
}
run "explicit_zero_scalar_port_is_not_null" {
  command = apply
  variables {
    properties = {
      frontendIPConfiguration = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/frontendIPConfigurations/public" }
      backendAddressPool      = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/backendAddressPools/app" }
      frontendPort            = 0
      frontendPortRangeStart  = 50000
      frontendPortRangeEnd    = 50100
      backendPort             = 22
    }
  }
  assert {
    condition     = azapi_resource.this.ignore_null_property && azapi_resource.this.body.properties.frontendPort == 0 && azapi_resource.this.body.properties.backendPort == 22 && !azapi_resource.this.body.properties.enableTcpReset
    error_message = "Null omission must preserve explicit zero, false and non-null port values."
  }
}
run "invalid_parent" {
  command = plan
  variables { parent_id = "/invalid" }
  expect_failures = [var.parent_id]
}
run "invalid_frontend" {
  command = plan
  variables { properties = { frontendIPConfiguration = { id = "/invalid" }, backendPort = 22 } }
  expect_failures = [var.properties]
}
run "api_override_partial_controls_and_consumer_ignore" {
  command = apply
  variables {
    resource_types = { network_load_balancers_inbound_nat_rules = "Microsoft.Network/loadBalancers/inboundNatRules@2024-10-01" }
    retry          = { error_message_regex = ["RetryableError"], max_interval_seconds = 17 }
    timeouts       = { read = "6m", update = "41m" }
  }
  assert {
    condition     = endswith(azapi_resource.this.type, "@2024-10-01") && azapi_resource.this.retry.max_interval_seconds == 17 && var.retry.interval_seconds == null && azapi_resource.this.retry.error_message_regex == tolist(["RetryableError"]) && azapi_resource.this.timeouts.read == "6m" && azapi_resource.this.timeouts.update == "41m" && azapi_resource.this.timeouts.create == null && azapi_resource.this.timeouts.delete == null
    error_message = "NAT must apply its API override and partial controls without inventing unspecified values."
  }
}
run "consumer_ignore_paths_accepted" {
  command = apply
  variables {
    ignore_body_changes = { network_load_balancers_inbound_nat_rules = ["properties.idleTimeoutInMinutes"] }
  }
  assert {
    condition     = var.ignore_body_changes.network_load_balancers_inbound_nat_rules == tolist(["properties.idleTimeoutInMinutes"])
    error_message = "Consumer paths must be accepted; the write-only argument cannot be verified through state."
  }
}
run "explicit_null_controls_and_optional_nat_fields" {
  command = apply
  variables {
    properties = {
      frontendIPConfiguration = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/frontendIPConfigurations/public" }
      frontendPort            = 50000
      backendPort             = 22
      protocol                = null
      enableFloatingIP        = null
      enableTcpReset          = null
      idleTimeoutInMinutes    = null
      backendAddressPool      = null
    }
    retry               = null
    timeouts            = null
    resource_types      = null
    ignore_body_changes = null
  }
  assert {
    condition     = azapi_resource.this.retry == null && azapi_resource.this.timeouts == null && endswith(azapi_resource.this.type, "@2025-01-01") && azapi_resource.this.body.properties.protocol == "Tcp" && !azapi_resource.this.body.properties.enableFloatingIP && !azapi_resource.this.body.properties.enableTcpReset && azapi_resource.this.body.properties.idleTimeoutInMinutes == 4 && azapi_resource.this.body.properties.backendAddressPool == null
    error_message = "Explicit null optional fields must select their defaults without manufacturing a pool."
  }
}
run "invalid_backend_pool" {
  command = plan
  variables {
    properties = {
      frontendIPConfiguration = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab/frontendIPConfigurations/public" }
      backendAddressPool      = { id = "/invalid" }
      backendPort             = 22
    }
  }
  expect_failures = [var.properties]
}
