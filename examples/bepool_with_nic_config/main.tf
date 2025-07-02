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
  location            = azurerm_resource_group.this.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.1.0.0/16"]
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
    name                          = "ipconfig1" # -${module.naming.network_interface.name_unique}"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.example.id
  }
}

resource "azurerm_network_interface" "example_2" {
  location            = azurerm_resource_group.this.location
  name                = "${module.naming.network_interface.name_unique}-2"
  resource_group_name = azurerm_resource_group.this.name

  ip_configuration {
    name                          = "ipconfig1" # -${module.naming.network_interface.name_unique}"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.example.id
  }
}

module "loadbalancer" {
  source = "../../"

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
  location            = azurerm_resource_group.this.location
  name                = "default-lb"
  resource_group_name = azurerm_resource_group.this.name
  enable_telemetry    = var.enable_telemetry
}
