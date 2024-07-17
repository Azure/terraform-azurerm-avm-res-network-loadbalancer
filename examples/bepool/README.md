<!-- BEGIN_TF_DOCS -->
# Default example

This deploys the module as a Standard SKU Public Load Balancer with two backend pools: one configured to use private IPs and one configured to use network interfaces (ip configurations).

```hcl
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
  # version = "0.2.1"

  enable_telemetry = var.enable_telemetry

  name                = "bepool-lb"
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
  # Use if using only backend addresses via private IPs in all pools
  # Leave empty if using backend pools with network interfaces or backend pools with a mix of network interfaces and backend addresses
  backend_address_pool_configuration = azurerm_virtual_network.example.id


  
  # Backend Address Pool(s)
  backend_address_pools = {
    pool1 = {
      name                        = "primaryPool"
      virtual_network_resource_id = azurerm_virtual_network.example.id # set a virtual_network_resource_id if using backend_address_pool_addresses
    }
    pool2 = {
      name = "secondaryPool"

    }
  }
  

  
  backend_address_pool_addresses = {
    address1 = {
      name                             = "${azurerm_network_interface.example_1.name}-ipconfig1" # must be unique if multiple addresses are used
      backend_address_pool_object_name = "pool1"
      ip_address                       = azurerm_network_interface.example_1.private_ip_address
      virtual_network_resource_id      = azurerm_virtual_network.example.id
    }
  }
  

  
  backend_address_pool_network_interfaces = {
    node1 = {
      backend_address_pool_object_name = "pool2"
      ip_configuration_name            = "ipconfig1"
      network_interface_resource_id    = azurerm_network_interface.example_2.id
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
      name                           = "primaryRule"
      frontend_ip_configuration_name = "myFrontend"

      backend_address_pool_object_names = ["pool1"]
      protocol                          = "Tcp"
      frontend_port                     = 80
      backend_port                      = 80

      probe_object_name = "tcp1"

      idle_timeout_in_minutes = 15
      enable_tcp_reset        = true
    }
    http2 = {
      name                           = "secondaryRule"
      frontend_ip_configuration_name = "myFrontend"

      backend_address_pool_object_names = ["pool2"]
      protocol                          = "Tcp"
      frontend_port                     = 81
      backend_port                      = 81

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
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (~> 1.5)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (~> 3.7)

- <a name="requirement_random"></a> [random](#requirement\_random) (~> 3.5)

## Resources

The following resources are used by this module:

- [azurerm_network_interface.example_1](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_network_interface.example_2](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface) (resource)
- [azurerm_resource_group.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/resource_group) (resource)
- [azurerm_subnet.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/subnet) (resource)
- [azurerm_virtual_network.example](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/virtual_network) (resource)
- [random_integer.region_index](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/integer) (resource)

<!-- markdownlint-disable MD013 -->
## Required Inputs

No required inputs.

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description: This variable controls whether or not telemetry is enabled for the module.  
For more information see https://aka.ms/avm/telemetryinfo.  
If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

## Outputs

The following outputs are exported:

### <a name="output_azurerm_lb_backend_address_pool"></a> [azurerm\_lb\_backend\_address\_pool](#output\_azurerm\_lb\_backend\_address\_pool)

Description: Outputs each backend address pool

### <a name="output_resource"></a> [resource](#output\_resource)

Description: Outputs the entire Azure Load Balancer resource

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: Outputs the entire Azure Load Balancer resource

## Modules

The following Modules are called:

### <a name="module_loadbalancer"></a> [loadbalancer](#module\_loadbalancer)

Source: ../../

Version:

### <a name="module_naming"></a> [naming](#module\_naming)

Source: Azure/naming/azurerm

Version: 0.3.0

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->