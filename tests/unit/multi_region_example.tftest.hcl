mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}
mock_provider "random" {}
mock_provider "time" {}

run "multi_region_composition" {
  command = apply
  module {
    source = "./examples/multi-region"
  }
  variables {
    enable_telemetry = false
  }
  override_resource {
    target = azapi_resource.resource_group
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab" }
  }
  override_resource {
    target = azapi_resource.public_ip["east"]
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/east" }
  }
  override_resource {
    target = azapi_resource.public_ip["west"]
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/west" }
  }
  override_resource {
    target = azapi_resource.public_ip["global"]
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/global" }
  }
  override_resource {
    target = azapi_resource.virtual_network["east"]
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/east" }
  }
  override_resource {
    target = azapi_resource.virtual_network["west"]
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/west" }
  }
  assert {
    condition = (
      keys(output.regional_frontend_resource_ids) == ["east", "west"] &&
      alltrue([for id in output.regional_frontend_resource_ids : can(provider::azapi::parse_resource_id("Microsoft.Network/loadBalancers/frontendIPConfigurations", id))]) &&
      alltrue([for key, pools in output.regional_backend_pool_resource_ids :
        keys(pools) == ["explicit", "native"] &&
        azapi_resource.network_interface[key].body.properties.ipConfigurations[0].properties.loadBalancerBackendAddressPools[0].id == pools.native
      ]) &&
      azapi_resource.public_ip["global"].location == "eastus2" &&
      azapi_resource.public_ip["global"].body.sku.tier == "Global"
    )
    error_message = "The runnable example must compose actual regional frontend IDs, separate native/IP pools, NIC-owner memberships and a Global PIP in East US 2."
  }
}
