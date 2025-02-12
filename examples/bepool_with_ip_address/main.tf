terraform {
  required_version = ">= 1.9, < 2.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
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

# Helps pick a random region from the list of regions.
resource "random_integer" "region_index" {
  max = length(local.azure_regions) - 1
  min = 0
}

# This is required for resource modules

# Creates a resource group
resource "azurerm_resource_group" "this" {
  location = local.azure_regions[random_integer.region_index.result]
  name     = module.naming.resource_group.name_unique
}

# Creates a virtual network
resource "azurerm_virtual_network" "example" {
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
}

# Creates a subnet
resource "azurerm_subnet" "example" {
  address_prefixes     = ["10.1.1.0/26"]
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_virtual_network.example.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
}

resource "azurerm_network_interface" "example_1" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.network_interface.name_unique}-1"
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.example.id
  }
}

resource "azurerm_network_interface" "example_2" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.network_interface.name_unique}-2"
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.example.id
  }
}

module "loadbalancer" {

  source = "../../"

  # source = "Azure/avm-res-network-loadbalancer/azurerm"
  # version = "0.2.2"

  enable_telemetry = var.enable_telemetry

  name                = "default-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = "myFrontend"
      # Creates a public IP address
      create_public_ip_address        = true
      public_ip_address_resource_name = module.naming.public_ip.name_unique
      # zones = ["1", "2", "3"] # Zone-redundant
      # zones = ["None"] # Non-zonal
    }
  }

  /*
  # Virtual Network for Backend Address Pool(s) if using backend addresses
  # Use if using only backend addresses via private IP
  # Leave empty if using network interfaces or mix of network interfaces and backend addresses
  backend_address_pool_configuration = azurerm_virtual_network.example.id
  

  
  # Backend Address Pool(s)
  backend_address_pools = {
    pool1 = {
      name                        = "primaryPool"
      virtual_network_resource_id = azurerm_virtual_network.example.id
    }
  }

  
  backend_address_pool_addresses = {
    address1 = {
      name                             = "${azurerm_network_interface.example_1.name}-ipconfig1" # must be unique if multiple addresses are used
      backend_address_pool_object_name = "pool1"
      ip_address                       = azurerm_network_interface.example_1.private_ip_address
      # virtual_network_resource_id      = azurerm_virtual_network.example.id
    }
    address2 = {
      name                             = "${azurerm_network_interface.example_2.name}-ipconfig1" # must be unique if multiple addresses are used
      backend_address_pool_object_name = "pool1"
      ip_address                       = azurerm_network_interface.example_2.private_ip_address
      # virtual_network_resource_id      = azurerm_virtual_network.example.id

    }
  }

  
  backend_address_pool_network_interfaces = {

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
  */

  depends_on = [
    # To ensure that the backend address pool is created before the network interfaces' ip addresses are associated
    azurerm_network_interface.example_1,
    azurerm_network_interface.example_2
  ]

}
