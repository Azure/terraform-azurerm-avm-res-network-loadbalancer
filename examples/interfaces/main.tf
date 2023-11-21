terraform {
  required_version = ">= 1.5.2"
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

# Helps pick a random region from the list of regions.
resource "random_integer" "region_index" {
  min = 0
  max = length(local.azure_regions) - 1
}

data "azurerm_client_config" "this" {

}


resource "azurerm_resource_group" "example" {
  name     = module.naming.resource_group.name_unique
  location = local.azure_regions[random_integer.region_index.result]
}

resource "azurerm_virtual_network" "example" {
  name                = module.naming.virtual_network.name_unique
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["10.1.0.0/16"]
}

resource "azurerm_subnet" "example" {
  name                 = module.naming.subnet.name_unique
  resource_group_name  = azurerm_virtual_network.example.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["10.1.1.0/26"]
}

resource "azurerm_log_analytics_workspace" "example" {
  name                = "law-test-001"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

data "azurerm_role_definition" "example" {
  name = "Contributor"

}



module "loadbalancer" {

  source = "../../"

  # source = "Azure/avm-res-network-loadbalancer/azurerm"
  # version = 0.1.0

  enable_telemetry = false

  name                = "interfaces-lb"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name


  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = "myFrontend"

      create_public_ip_address        = true
      public_ip_address_resource_name = module.naming.public_ip.name_unique
      tags = {
        createdBy = "tf-infra-team"
      }

      inherit_lock = true
      inherit_tags = true

      role_assignments = {
        role_assignment_1 = {
          role_definition_id_or_name = data.azurerm_role_definition.example.name
          principal_id               = data.azurerm_client_config.this.object_id
        }
      }

      diagnostic_settings = {
        diagnotic_settings_1 = {
          name                  = "pip-diag_settings_1"
          workspace_resource_id = azurerm_log_analytics_workspace.example.id
        }
      }
    }
  }

  lock = {
    kind = "None"

    /*
    kind = "ReadOnly"
    */

    /*
    kind = "CanNotDelete"
    */
  }

  diagnostic_settings = {
    diagnostic_settings_1 = {
      name                  = "diag_settings_1"
      workspace_resource_id = azurerm_log_analytics_workspace.example.id
    }
  }

  role_assignments = {
    role_assignment_1 = {
      role_definition_id_or_name = data.azurerm_role_definition.example.name
      principal_id               = data.azurerm_client_config.this.object_id
    }
  }

  tags = {
    environment = "dev-tf"
  }
}
