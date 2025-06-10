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

# Creates a resource group
resource "azurerm_resource_group" "example" {
  location = local.azure_regions[random_integer.region_index.result]
  name     = module.naming.resource_group.name_unique
}

# Creates a virtual network
resource "azurerm_virtual_network" "example" {
  address_space       = ["10.7.0.0/16"]
  location            = azurerm_resource_group.example.location
  name                = module.naming.virtual_network.name_unique
  resource_group_name = azurerm_resource_group.example.name
}

# Azure Bastion
resource "azurerm_subnet" "bastion_subnet" {
  address_prefixes     = ["10.7.1.0/26"]
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
}

resource "azurerm_bastion_host" "bastion" {
  location            = azurerm_resource_group.example.location
  name                = module.naming.bastion_host.name_unique
  resource_group_name = azurerm_resource_group.example.name

  ip_configuration {
    name                 = "${module.naming.bastion_host.name_unique}-ipconf"
    public_ip_address_id = azurerm_public_ip.bastionpip.id
    subnet_id            = azurerm_subnet.bastion_subnet.id
  }
}

resource "azurerm_public_ip" "bastionpip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.example.location
  name                = module.naming.public_ip.name_unique
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "Standard"
}

# Creates a subnet
resource "azurerm_subnet" "example" {
  address_prefixes     = ["10.7.0.0/24"]
  name                 = "backend-${module.naming.subnet.name_unique}"
  resource_group_name  = azurerm_virtual_network.example.resource_group_name
  virtual_network_name = azurerm_virtual_network.example.name
}

# NAT Gateway
resource "azurerm_nat_gateway" "example" {
  location            = azurerm_resource_group.example.location
  name                = "lb-nat-gateway"
  resource_group_name = azurerm_resource_group.example.name
  sku_name            = "Standard"
}

resource "azurerm_public_ip" "nat_gateway_pip" {
  allocation_method   = "Static"
  location            = azurerm_resource_group.example.location
  name                = "${azurerm_subnet.example.name}-pip"
  resource_group_name = azurerm_resource_group.example.name
  sku                 = "Standard"
}

resource "azurerm_nat_gateway_public_ip_association" "example" {
  nat_gateway_id       = azurerm_nat_gateway.example.id
  public_ip_address_id = azurerm_public_ip.nat_gateway_pip.id
}

resource "azurerm_network_security_group" "example" {
  location            = azurerm_resource_group.example.location
  name                = module.naming.network_security_group.name_unique
  resource_group_name = azurerm_resource_group.example.name
}

resource "azurerm_network_security_rule" "example_inbound" {
  access                      = "Allow"
  direction                   = "Inbound"
  name                        = "${azurerm_network_security_group.example.name}-Rule-AllowAll-All"
  network_security_group_name = azurerm_network_security_group.example.name
  priority                    = 100
  protocol                    = "*"
  resource_group_name         = azurerm_resource_group.example.name
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  source_port_range           = "*"
}

resource "azurerm_network_security_rule" "example_outbound" {
  access                      = "Allow"
  direction                   = "Outbound"
  name                        = "${azurerm_network_security_group.example.name}-Rule-AllowAll-TCP-Out"
  network_security_group_name = azurerm_network_security_group.example.name
  priority                    = 100
  protocol                    = "Tcp"
  resource_group_name         = azurerm_resource_group.example.name
  destination_address_prefix  = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  source_port_range           = "*"
}

module "gateway_loadbalancer" {
  source = "../.."

  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name                                   = "gatewayFrontend-IP"
      frontend_private_ip_address_version    = "IPv4"
      frontend_private_ip_address_allocation = "Dynamic"
      # zones = ["1", "2", "3"] # Zone-redundant
      zones = ["None"] # Non-zonal

    }
  }
  location                           = azurerm_resource_group.example.location
  name                               = "gateway-lb"
  resource_group_name                = azurerm_resource_group.example.name
  backend_address_pool_configuration = azurerm_virtual_network.example.id
  backend_address_pools = {
    pool_1 = {
      name = "lb-backend-pool"
      tunnel_interfaces = {
        internal_tunnel = {
          identifier = 800
          type       = "Internal"
          protocol   = "VXLAN"
          port       = 10800
        }
        external_tunnel = {
          identifier = 801
          type       = "External"
          protocol   = "VXLAN"
          port       = 10801
        }
      }
    }
  }
  enable_telemetry            = var.enable_telemetry
  frontend_subnet_resource_id = azurerm_subnet.example.id
  # Health Probe(s)
  lb_probes = {
    probe_1 = {
      name     = "lb-health-probe"
      protocol = "Tcp"
    }
  }
  lb_rules = {
    rule_1 = {
      name                           = "lb-rule"
      frontend_ip_configuration_name = "gatewayFrontend-IP"

      backend_address_pool_object_names = ["pool_1"]
      protocol                          = "All"
      frontend_port                     = 0
      backend_port                      = 0

      probe_object_name = "probe_1"

      idle_timeout_in_minutes = 4
      enable_tcp_reset        = false
    }
  }
  sku      = "Gateway"
  sku_tier = "Regional"
}

module "standard_loadbalancer" {
  source = "../.."

  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = "standardFrontend"

      gateway_load_balancer_frontend_ip_configuration_id = module.gateway_loadbalancer.azurerm_lb.frontend_ip_configuration[0].id

      create_public_ip_address        = true
      public_ip_address_resource_name = "standard-lb-${module.naming.public_ip.name_unique}"
      tags = {
        createdBy = "tf-infra-team"
      }

      inherit_lock = true
      inherit_tags = true

    }

  }
  location            = azurerm_resource_group.example.location
  name                = "standard-lb"
  resource_group_name = azurerm_resource_group.example.name
  enable_telemetry    = var.enable_telemetry
  tags = {
    environment = "dev-tf"
  }
}

# # /*
# # VM to test private endpoint connectivity

# module "regions" {
#   source  = "Azure/regions/azurerm"
#   version = ">= 0.4.0"
# }

# #seed the test regions 
# # locals {
# #   test_regions = ["centralus", "eastasia", "westus2", "eastus2", "westeurope", "japaneast"]
# # }

# # This allows us to randomize the region for the resource group.
# resource "random_integer" "region_index_vm" {
#   max = length(local.azure_regions) - 1
#   min = 0
# }

# resource "random_integer" "zone_index" {
#   max = length(module.regions.regions_by_name[local.azure_regions[random_integer.region_index_vm.result]].zones)
#   min = 1
# }

# resource "random_integer" "deploy_sku" {
#   max = length(local.deploy_skus) - 1
#   min = 0
# }

# ### this segment of code gets valid vm skus for deployment in the current subscription
# data "azurerm_subscription" "current" {}

# #get the full sku list (azapi doesn't currently have a good way to filter the api call)
# data "azapi_resource_list" "example" {
#   parent_id              = data.azurerm_subscription.current.id
#   type                   = "Microsoft.Compute/skus@2021-07-01"
#   response_export_values = ["*"]
# }

# locals {
#   #filter the region virtual machines by desired capabilities (v1/v2 support, 2 cpu, and encryption at host)
#   deploy_skus = [
#     for sku in local.location_valid_vms : sku
#     if length([
#       for capability in sku.capabilities : capability
#       if(capability.name == "HyperVGenerations" && capability.value == "V1,V2") ||
#       (capability.name == "vCPUs" && capability.value == "2") ||
#       (capability.name == "EncryptionAtHostSupported" && capability.value == "True") ||
#       (capability.name == "CpuArchitectureType" && capability.value == "x64")
#     ]) == 4
#   ]
#   #filter the location output for the current region, virtual machine resources, and filter out entries that don't include the capabilities list
#   location_valid_vms = [
#     for location in jsondecode(data.azapi_resource_list.example.output).value : location
#     if contains(location.locations, local.azure_regions[random_integer.region_index_vm.result]) && # if the sku location field matches the selected location
#     length(location.restrictions) < 1 &&                                                           # and there are no restrictions on deploying the sku (i.e. allowed for deployment)
#     location.resourceType == "virtualMachines" &&                                                  # and the sku is a virtual machine
#     !strcontains(location.name, "C") &&                                                            # no confidential vm skus
#     !strcontains(location.name, "B") &&                                                            # no B skus
#     length(try(location.capabilities, [])) > 1                                                     # avoid skus where the capabilities list isn't defined
#     # try(location.capabilities, []) != []                                                           # avoid skus where the capabilities list isn't defined
#   ]
# }

# #create the virtual machine
# module "avm_res_compute_virtualmachine" {
#   # source = "../../"
#   source  = "Azure/avm-res-compute-virtualmachine/azurerm"
#   version = "0.4.0"

#   resource_group_name     = azurerm_resource_group.example.name
#   location                = azurerm_resource_group.example.location
#   name                    = "${module.naming.virtual_machine.name_unique}-tf"
#   virtualmachine_sku_size = local.deploy_skus[random_integer.deploy_sku.result].name

#   virtualmachine_os_type = "Windows"
#   zone                   = random_integer.zone_index.result

#   generate_admin_password_or_ssh_key = false
#   admin_username                     = "TestAdmin"
#   admin_password                     = "P@ssw0rd1234!"

#   source_image_reference = {
#     publisher = "MicrosoftWindowsServer"
#     offer     = "WindowsServer"
#     sku       = "2019-Datacenter"
#     version   = "latest"
#   }

#   network_interfaces = {
#     network_interface_1 = {
#       name = "nic-${module.naming.network_interface.name_unique}-tf"
#       ip_configurations = {
#         ip_configuration_1 = {
#           name                          = "${module.naming.network_interface.name_unique}-ipconfig1-public"
#           private_ip_subnet_resource_id = azurerm_subnet.example.id
#           create_public_ip_address      = true
#           public_ip_address_name        = "pip-${module.naming.virtual_machine.name_unique}-tf"
#           is_primary_ipconfiguration    = true
#         }
#       }
#     }
#   }

#   tags = {

#   }

# }

