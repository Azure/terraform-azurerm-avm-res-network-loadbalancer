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
    condition     = azapi_resource.this.body.properties.frontendPort == null && azapi_resource.this.body.properties.frontendPortRangeEnd == 50100 && azapi_resource.this.body.properties.enableTcpReset && azapi_resource.this.retry.interval_seconds == 5 && azapi_resource.this.timeouts.create == "1h"
    error_message = "NAT v2 shapes and controls must reach the resource."
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
