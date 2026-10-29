resource "random_id" "example" {
  byte_length = 4
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-lb-${random_id.example.hex}"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  response_export_values = []
}

resource "azapi_resource" "virtual_network" {
  location  = var.location
  name      = "vnet-lb"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/virtualNetworks@2025-01-01"
  body = {
    properties = {
      addressSpace = { addressPrefixes = ["10.1.0.0/16"] }
      subnets      = [{ name = "backend", properties = { addressPrefix = "10.1.1.0/24" } }]
    }
  }
  response_export_values = []
}

module "loadbalancer" {
  source = "../../"

  frontend_ip_configurations = {
    internal = {
      name                                   = "internal"
      frontend_private_ip_subnet_resource_id = "${azapi_resource.virtual_network.id}/subnets/backend"
    }
  }
  location                                   = var.location
  name                                       = "lb-${random_id.example.hex}"
  parent_id                                  = azapi_resource.resource_group.id
  backend_address_pool_child_modules_enabled = true
  backend_address_pools                      = { app = { name = "app" } }
  enable_telemetry                           = var.enable_telemetry
}

# The NIC owns its IP configurations and backend memberships.
resource "azapi_resource" "network_interface" {
  location  = var.location
  name      = "nic-app"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/networkInterfaces@2025-01-01"
  body = {
    properties = {
      ipConfigurations = [{
        name = "primary"
        properties = {
          privateIPAllocationMethod       = "Dynamic"
          subnet                          = { id = "${azapi_resource.virtual_network.id}/subnets/backend" }
          loadBalancerBackendAddressPools = [{ id = module.loadbalancer.backend_address_pool_resource_ids["app"] }]
        }
      }]
    }
  }
  response_export_values = []
}
