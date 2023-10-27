# THIS IS CURRENTLY WORKING
# false positive with public ip address and private ip address version

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.71.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "azurerm" {
  features {
  }
}

module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

# This picks a random region from the list of regions.
resource "random_integer" "region_index" {
  min = 0
  max = length(local.azure_regions) - 1
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  name     = module.naming.resource_group.name_unique
  location = local.azure_regions[random_integer.region_index.result]
}

resource "azurerm_virtual_network" "example" {
  name                = module.naming.virtual_network.name_unique
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_virtual_network.example.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.1.1.0/26"]
}

module "loadbalancer" {

  source = "../../"

  name                = "public-lb"
  enable_telemetry    = false # var.enable_telemetry
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  # Frontend IP Configuration
  frontend_ip_configurations = [
    {
      name = "myFrontend"
      # Creates Public IP Address
      create_public_ip_address = true
    }
  ]

  # Backend Address Pool(s)
  backend_address_pools = [
    {
      name = "myBackendPool"
    }
  ]

  # Virtual Network for Backend Address Pool(s)
  backend_address_pool_configuration = azurerm_virtual_network.example.id

  # Health Probe(s)
  lb_probes = [
    {
      name     = "myHealthProbe"
      protocol = "Tcp" # default
    }
  ]

  # Load Balaner rule(s)
  lb_rules = [
    {
      name                           = "myHTTPRule"
      frontend_ip_configuration_name = "myFrontend"

      backend_address_pool_resource_names = ["myBackendPool"]
      protocol                            = "Tcp" # default
      frontend_port                       = 80
      backend_port                        = 80

      probe_resource_name = "myHealthProbe"

      idle_timeout_in_minutes = 15
      enable_tcp_reset        = true
    }
  ]

}

# data "azurerm_resource_group" "azlb" {
#   count = (var.resource_group_name != null) ? 1 : 0

#   name = var.resource_group_name
# }

# data "azurerm_subnet" "snet" {
#   count = (var.frontend_subnet_resource_name != null && var.frontend_subnet_resource_name != "") ? 1 : 0

#   name                 = var.frontend_subnet_resource_name
#   resource_group_name  = var.resource_group_name # data.azurerm_resource_group.azlb.name # going to have to create a variable for the frontend_vnet_resource_group / frontend_subnet_resource_group
#   virtual_network_name = var.frontend_vnet_resource_name
# }

# data "azurerm_virtual_network" "vnet" {
#   count               = (var.backend_address_pool_configuration != null) ? 1 : 0
#   name                = var.backend_address_pool_configuration
#   resource_group_name = coalesce(var.backend_vnet_resource_group_name, var.resource_group_name) # going to have to create a variable for the backend_vnet_resource_group
# }
