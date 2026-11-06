mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "random" {}

variables {
  name                 = "regions"
  location             = "eastus2"
  parent_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/global"
  sku_tier             = "Global"
  backend_address_type = "Frontend"
  enable_telemetry     = false
  properties = {
    loadBalancerBackendAddresses = [{
      name = "west"
      properties = {
        loadBalancerFrontendIPConfiguration = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/west/frontendIPConfigurations/public" }
      }
    }]
  }
}

run "standalone_frontend_endpoint" {
  command = apply
  module {
    source = "./modules/backend-address-pool"
  }
  assert {
    condition = (
      azapi_resource.this.body.properties.loadBalancerBackendAddresses[0].properties.ipAddress == null &&
      endswith(azapi_resource.this.body.properties.loadBalancerBackendAddresses[0].properties.loadBalancerFrontendIPConfiguration.id, "/west/frontendIPConfigurations/public") &&
      azapi_resource.this.ignore_null_property &&
      azapi_resource_action.clear_backend_members[0].resource_id == "${var.parent_id}/backendAddressPools/${var.name}" &&
      azapi_resource_action.clear_backend_members[0].when == "destroy" &&
      length(azapi_resource_action.clear_backend_members[0].body.properties.loadBalancerBackendAddresses) == 0
    )
    error_message = "Standalone pools must support actual frontend references and fixed-empty cleanup at their dedicated endpoint."
  }
}

run "standalone_reject_wrong_frontend_type" {
  command = plan
  module {
    source = "./modules/backend-address-pool"
  }
  variables {
    properties = { loadBalancerBackendAddresses = [{ name = "bad", properties = { loadBalancerFrontendIPConfiguration = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/west" } } }] }
  }
  expect_failures = [var.properties]
}

run "standalone_reject_regional_frontend_pool" {
  command = plan
  module {
    source = "./modules/backend-address-pool"
  }
  variables {
    sku_tier = "Regional"
  }
  expect_failures = [azapi_resource.this]
}

run "standalone_nic_omission" {
  command = apply
  module {
    source = "./modules/backend-address-pool"
  }
  variables {
    sku_tier             = "Regional"
    backend_address_type = "NIC"
    properties           = {}
  }
  assert {
    condition     = !contains(keys(azapi_resource.this.body.properties), "loadBalancerBackendAddresses") && length(azapi_resource_action.clear_backend_members) == 0
    error_message = "NIC mode must omit server projections and never run explicit-member cleanup."
  }
}
