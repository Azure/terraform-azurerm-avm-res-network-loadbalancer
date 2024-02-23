# THIS IS CURRENTLY WORKING
# false positive with public ip address and private ip address version

terraform {
  required_version = "~> 1.5"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.7"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
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
  max = length(local.azure_regions) - 1
  min = 0
}

# This is required for resource modules
resource "azurerm_resource_group" "this" {
  location = local.azure_regions[random_integer.region_index.result]
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "example" {
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

resource "azurerm_subnet" "example" {
  address_prefixes     = ["10.1.1.0/26"]
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_virtual_network.example.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
}

module "loadbalancer" {

  source = "../../"

  # source = "Azure/avm-res-network-loadbalancer/azurerm"
  # version = 0.1.3

  enable_telemetry = var.enable_telemetry

  name                = "public-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  # Frontend IP Configuration
  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = "myFrontend"
      # Creates Public IP Address
      create_public_ip_address        = true
      public_ip_address_resource_name = module.naming.public_ip.name_unique
    }
  }

  # Virtual Network for Backend Address Pool(s)
  backend_address_pool_configuration = azurerm_virtual_network.example.id

  # Backend Address Pool(s)
  backend_address_pools = {
    pool1 = {
      name = "myBackendPool"
    }
  }

  # Health Probe(s)
  lb_probes = {
    tcp1 = {
      name     = "myHealthProbe"
      protocol = "Tcp"
    }
  }

  # Load Balaner rule(s)
  lb_rules = {
    http1 = {
      name                           = "myHTTPRule"
      frontend_ip_configuration_name = "myFrontend"

      backend_address_pool_object_names = ["pool1"]
      protocol                          = "Tcp"
      frontend_port                     = 80
      backend_port                      = 80

      probe_object_name = "tcp1"

      idle_timeout_in_minutes = 15
      enable_tcp_reset        = true
    }
  }

}

# output "azurerm_lb" {
#   value       = module.loadbalancer.azurerm_lb
#   description = "Outputs the entire Azure Load Balancer resource"
# }

# output "azurerm_public_ip" {
#   value       = module.loadbalancer.azurerm_public_ip
#   description = "Outputs each Public IP Address resource in it's entirety"
# }
