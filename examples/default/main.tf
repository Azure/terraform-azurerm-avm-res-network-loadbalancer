module "naming" {
  source  = "Azure/naming/azurerm"
  version = "0.3.0"
}

module "regions" {
  source  = "Azure/regions/azurerm"
  version = "0.4.0"
}

# Helps pick a random region from the list of regions.
resource "random_integer" "region_index" {
  max = length(local.azure_regions) - 1
  min = 0
}

resource "random_integer" "zone_index" {
  max = length(module.regions.regions_by_name[local.azure_regions[random_integer.region_index.result]].zones) - 1
  min = 1
}

resource "azurerm_resource_group" "example" {
  location = local.azure_regions[random_integer.region_index.result]
  name     = module.naming.resource_group.name_unique
}

resource "azurerm_virtual_network" "example" {
  location            = azurerm_resource_group.example.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "example" {
  address_prefixes     = ["10.1.1.0/26"]
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_virtual_network.example.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
}

resource "azurerm_network_interface" "example_1" {
  location            = azurerm_resource_group.example.location
  name                = "${module.naming.network_interface.name_unique}-1"
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.example.id
  }
}

resource "azurerm_network_interface" "example_2" {
  location            = azurerm_resource_group.example.location
  name                = "${module.naming.network_interface.name_unique}-2"
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "ipconfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.example.id
  }
}

module "loadbalancer" {
  source = "../../"

  # Internal
  # Standard SKU
  # Regional
  # Zone-redundant
  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name                                   = "myFrontend"
      frontend_private_ip_subnet_resource_id = azurerm_subnet.example.id
      # zones = ["1", "2", "3"] # Zone-redundant
      # zones = ["None"] # Non-zonal
    }
  }
  location            = azurerm_resource_group.example.location
  name                = "default-lb"
  resource_group_name = azurerm_resource_group.example.name
  enable_telemetry    = var.enable_telemetry
}
