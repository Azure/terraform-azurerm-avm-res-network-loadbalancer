mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
      object_id                = "11111111-1111-1111-1111-111111111111"
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

run "zones" {
  command = apply
  module {
    source = "./examples/complete"
  }
  variables {
    enable_telemetry = false
  }
  override_resource {
    target = azapi_resource.resource_group
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab" }
  }
  override_resource {
    target = azapi_resource.public_ip
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/public" }
  }
  override_resource {
    target = azapi_resource.workspace
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.OperationalInsights/workspaces/logs" }
  }
  override_resource {
    target = module.loadbalancer.azapi_resource.this
    values = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab" }
  }
  assert {
    condition = (
      azapi_resource.public_ip.body.zones == toset(jsondecode(file("tests/fixtures/observed-normalization.json")).pip_zones) &&
      azapi_resource.public_ip.body.zones != toset(["1", "2"]) &&
      azapi_resource.public_ip.ignore_body_changes == null
    )
    error_message = "The complete example must type zones as a set: actual ARM reorder equal, changed membership unequal, no ignore or replacement-trigger workaround."
  }
}
