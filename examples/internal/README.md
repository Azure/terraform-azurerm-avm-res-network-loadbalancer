<!-- BEGIN_TF_DOCS -->
# Internal Load Balancer \ Standard SKU example

This deploys the module as a common internal load balancer quick start.

```hcl
# THIS IS CURRENTLY WORKING

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

  # source = "Azure/avm-res-network-loadbalancer/azurerm"
  # version = 0.1.0

  name                = "internal-lb"
  enable_telemetry    = false # var.enable_telemetry
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name

  # Virtual Network and Subnet for Internal LoadBalancer
  # frontend_vnet_resource_id   = azurerm_virtual_network.example.id
  frontend_subnet_resource_id = azurerm_subnet.example.id

  # Frontend IP Configuration
  frontend_ip_configurations = [
    {
      name = "myFrontend"
    }
  ]

  # Backend Address Pool
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

output "azurerm_lb" {
  value       = module.loadbalancer.azurerm_lb
  description = "Outputs the entire Azure Load Balancer resource"
}
```

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.5.2)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.71.0)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0)

## Providers

The following providers are used by this module:

- <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) (>= 3.71.0)

- <a name="provider_random"></a> [random](#provider\_random) (>= 3.5.0)

## Resources

The following resources are used by this module:

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

### <a name="output_azurerm_lb"></a> [azurerm\_lb](#output\_azurerm\_lb)

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