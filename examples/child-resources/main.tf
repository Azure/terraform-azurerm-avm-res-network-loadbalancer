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

# This externally managed LB explicitly delegates pool/NAT collections.
# Never use the root module in this example: its collections are authoritative.
resource "azapi_resource" "loadbalancer" {
  location  = var.location
  name      = "lb-children-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/loadBalancers@2025-01-01"
  body = {
    sku = { name = "Standard", tier = "Regional" }
    properties = {
      frontendIPConfigurations = [{
        name       = "public"
        properties = { publicIPAddress = { id = azapi_resource.public_ip.id } }
      }]
      backendAddressPools = []
      inboundNatRules     = []
    }
  }
  ignore_body_changes    = ["properties.backendAddressPools", "properties.inboundNatRules"]
  locks                  = ["${azapi_resource.resource_group.id}/providers/Microsoft.Network/loadBalancers/lb-children-${random_id.example.hex}"]
  response_export_values = []
}

module "backend_address_pool" {
  source = "../../modules/backend-address-pool"

  location         = var.location
  name             = "app"
  parent_id        = azapi_resource.loadbalancer.id
  properties       = {}
  enable_telemetry = var.enable_telemetry
}

module "inbound_nat_rule" {
  source = "../../modules/inbound-nat-rule"

  location  = var.location
  name      = "ssh"
  parent_id = azapi_resource.loadbalancer.id
  properties = {
    frontendIPConfiguration = { id = "${azapi_resource.loadbalancer.id}/frontendIPConfigurations/public" }
    backendAddressPool      = { id = module.backend_address_pool.resource_id }
    protocol                = "Tcp"
    frontendPortRangeStart  = 50000
    frontendPortRangeEnd    = 50100
    backendPort             = 22
  }
  enable_telemetry = var.enable_telemetry
}
