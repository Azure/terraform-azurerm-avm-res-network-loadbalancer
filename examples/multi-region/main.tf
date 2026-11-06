resource "random_id" "example" {
  byte_length = 4
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  location               = "eastus2"
  name                   = "rg-lb-global-${random_id.example.hex}"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  response_export_values = []
}

resource "azapi_resource" "public_ip" {
  for_each = {
    east   = { location = "eastus2", tier = "Regional" }
    west   = { location = "westus2", tier = "Regional" }
    global = { location = "eastus2", tier = "Global" }
  }

  location  = each.value.location
  name      = "pip-${each.key}-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/publicIPAddresses@2025-01-01"
  body = {
    sku   = { name = "Standard", tier = each.value.tier }
    zones = each.value.tier == "Regional" ? toset(["1", "2", "3"]) : null
    properties = {
      publicIPAllocationMethod = "Static"
      publicIPAddressVersion   = "IPv4"
    }
  }
  ignore_null_property   = true
  response_export_values = []
}

resource "azapi_resource" "virtual_network" {
  for_each = local.regions

  location  = each.value.location
  name      = "vnet-${each.key}-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/virtualNetworks@2025-01-01"
  body = {
    properties = {
      addressSpace = { addressPrefixes = [each.value.cidr] }
      subnets = [{
        name = "backend"
        properties = {
          addressPrefix         = each.value.cidr
          defaultOutboundAccess = false
        }
      }]
    }
  }
  response_export_values = []
}

module "regional" {
  source   = "../../"
  for_each = local.regions

  frontend_ip_configurations = {
    public = { name = "public", public_ip_address_resource_id = azapi_resource.public_ip[each.key].id }
  }
  location  = each.value.location
  name      = "lb-${each.key}-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  backend_address_pool_addresses = {
    explicit = {
      name                             = "explicit"
      backend_address_pool_object_name = "explicit"
      ip_address                       = each.value.backend_ip
      virtual_network_resource_id      = azapi_resource.virtual_network[each.key].id
    }
  }
  backend_address_pools = {
    explicit = { name = "explicit", backend_address_type = "IP" }
    native   = { name = "native", backend_address_type = "NIC" }
  }
  enable_telemetry = var.enable_telemetry
  lb_probes = {
    http = { name = "tcp", port = 80, interval_in_seconds = 5 }
  }
  lb_rules = {
    explicit = {
      name                              = "http"
      frontend_ip_configuration_name    = "public"
      frontend_port                     = 80
      backend_port                      = 80
      backend_address_pool_object_names = ["explicit"]
      probe_object_name                 = "http"
      disable_outbound_snat             = true
    }
    native = {
      name                              = "native"
      frontend_ip_configuration_name    = "public"
      frontend_port                     = 8080
      backend_port                      = 80
      backend_address_pool_object_names = ["native"]
      probe_object_name                 = "http"
      disable_outbound_snat             = true
    }
  }
}

# The NIC owner configures the native membership. There is deliberately no VM.
resource "azapi_resource" "network_interface" {
  for_each = local.regions

  location  = each.value.location
  name      = "nic-${each.key}-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/networkInterfaces@2025-01-01"
  body = {
    properties = {
      ipConfigurations = [{
        name = "primary"
        properties = {
          privateIPAllocationMethod       = "Static"
          privateIPAddress                = each.value.nic_ip
          subnet                          = { id = "${azapi_resource.virtual_network[each.key].id}/subnets/backend" }
          loadBalancerBackendAddressPools = [{ id = module.regional[each.key].backend_address_pool_resource_ids["native"] }]
        }
      }]
    }
  }
  response_export_values = []
}

module "global" {
  source = "../../"

  frontend_ip_configurations = {
    public = { name = "public", public_ip_address_resource_id = azapi_resource.public_ip["global"].id }
  }
  location  = "eastus2"
  name      = "lb-global-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  backend_address_pool_addresses = {
    for key, region in local.regions : key => {
      name                                                = key
      backend_address_pool_object_name                    = "regions"
      load_balancer_frontend_ip_configuration_resource_id = module.regional[key].frontend_ip_configuration_resource_ids["public"]
    }
  }
  backend_address_pools = {
    regions = { name = "regions", backend_address_type = "Frontend" }
  }
  enable_telemetry = var.enable_telemetry
  # Global health is inherited from regional LBs: no Global probe/NAT/outbound.
  lb_rules = {
    http = {
      name                              = "http"
      frontend_ip_configuration_name    = "public"
      frontend_port                     = 80
      backend_port                      = 80
      backend_address_pool_object_names = ["regions"]
      disable_outbound_snat             = true
    }
  }
  sku_tier = "Global"
}
