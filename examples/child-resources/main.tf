resource "random_id" "example" {
  byte_length = 4
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-lb-children-${random_id.example.hex}"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  response_export_values = []
}

resource "azapi_resource" "public_ip" {
  location  = var.location
  name      = "pip-lb-children"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/publicIPAddresses@2025-01-01"
  body = {
    sku   = { name = "Standard", tier = "Regional" }
    zones = ["1", "2", "3"]
    properties = {
      publicIPAllocationMethod = "Static"
      publicIPAddressVersion   = "IPv4"
    }
  }
  response_export_values = []
}

# The parent must preserve pools created by direct consumers of its submodule.
module "loadbalancer" {
  source = "../../"

  frontend_ip_configurations = {
    public = { name = "public", public_ip_address_resource_id = azapi_resource.public_ip.id }
  }
  location                                   = var.location
  name                                       = "lb-children-${random_id.example.hex}"
  parent_id                                  = azapi_resource.resource_group.id
  backend_address_pool_child_modules_enabled = true
  enable_telemetry                           = var.enable_telemetry
}

module "backend_address_pool" {
  source = "../../modules/backend-address-pool"

  location         = var.location
  name             = "app"
  parent_id        = module.loadbalancer.resource_id
  properties       = {}
  enable_telemetry = var.enable_telemetry
}

module "inbound_nat_rule" {
  source = "../../modules/inbound-nat-rule"

  location  = var.location
  name      = "ssh"
  parent_id = module.loadbalancer.resource_id
  properties = {
    frontendIPConfiguration = { id = "${module.loadbalancer.resource_id}/frontendIPConfigurations/public" }
    backendAddressPool      = { id = module.backend_address_pool.resource_id }
    protocol                = "Tcp"
    frontendPortRangeStart  = 50000
    frontendPortRangeEnd    = 50100
    backendPort             = 22
  }
  enable_telemetry = var.enable_telemetry
}
