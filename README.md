<!-- BEGIN_TF_DOCS -->
# terraform-azurerm-avm-res-network-loadbalancer

Module to deploy load balancers in Azure.

<!-- markdownlint-disable MD033 -->
## Requirements

The following requirements are needed by this module:

- <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) (>= 1.7.0)

- <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) (>= 3.71.0, < 5.0.0)

- <a name="requirement_modtm"></a> [modtm](#requirement\_modtm) (~> 0.3)

- <a name="requirement_random"></a> [random](#requirement\_random) (>= 3.5.0)

## Resources

The following resources are used by this module:

- [azurerm_lb.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb) (resource)
- [azurerm_lb_backend_address_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool) (resource)
- [azurerm_lb_backend_address_pool_address.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_backend_address_pool_address) (resource)
- [azurerm_lb_nat_pool.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_nat_pool) (resource)
- [azurerm_lb_nat_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_nat_rule) (resource)
- [azurerm_lb_outbound_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_outbound_rule) (resource)
- [azurerm_lb_probe.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_probe) (resource)
- [azurerm_lb_rule.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/lb_rule) (resource)
- [azurerm_management_lock.pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_management_lock.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/management_lock) (resource)
- [azurerm_monitor_diagnostic_setting.pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) (resource)
- [azurerm_monitor_diagnostic_setting.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/monitor_diagnostic_setting) (resource)
- [azurerm_network_interface_backend_address_pool_association.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/network_interface_backend_address_pool_association) (resource)
- [azurerm_public_ip.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/public_ip) (resource)
- [azurerm_role_assignment.pip](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [azurerm_role_assignment.this](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) (resource)
- [modtm_telemetry.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/resources/telemetry) (resource)
- [random_uuid.telemetry](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/uuid) (resource)
- [azurerm_client_config.telemetry](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) (data source)
- [modtm_module_source.telemetry](https://registry.terraform.io/providers/azure/modtm/latest/docs/data-sources/module_source) (data source)

<!-- markdownlint-disable MD013 -->
## Required Inputs

The following input variables are required:

### <a name="input_frontend_ip_configurations"></a> [frontend\_ip\_configurations](#input\_frontend\_ip\_configurations)

Description:   A map of objects that builds frontend ip configurations for the load balancer.   
  You need at least one frontend ip configuration to deploy a load balancer.

  - `name`: (Optional) The name of the frontend IP configuration. Changing this forces a new resource to be created
  - `frontend_private_ip_address`: (Optional) A string parameter that is the private IP address to assign to the Load Balancer. The last one and first four IPs in any range are reserved and cannot be manually assigned.
  - `frontend_private_ip_address_version`: (Optional) A string parameter that is the version of IP that the private IP address is. Possible values are IPv4 or IPv6
  - `frontend_private_ip_address_allocation`: (Optional) A string parameter that is the allocation method for the private IP address used by this Load Balancer. Possible values include `Dynamic` or `Static`. If value is set to `Static`, then user must provide `frontend_private_ip_address` as parameter.
  - `frontend_private_ip_subnet_resource_id`: (Optional) A string parameter that is the ID of the subnet which should be associated with the IP configuration. If desired to use the same subnet for each frontend ip configuration, use frontend\_subnet\_resource\_id, or use frontend\_vnet\_name and frontend\_subnet\_name. If for public ip configuration, leave parameter empty/null.
  - `public_ip_address_resource_name`: (Optional) A string parameter that is the name of the public ip address to be created AND associated with the Load Balancer. Changing this forces a new Public IP to be created.
  - `public_ip_address_resource_id`: (Optional) A string parameter that is the ID of a public ip address which should associated with the Load Balancer.
  - `public_ip_prefix_resource_id`: (Optional) A string parameter that is the ID of a public IP prefixes which should be associated with the Load Balancer. Public IP prefix can only be used with outbound rules
  - `frontend_private_ip_zones`: (Optional) A  set of strings that specifies a list of availability zones in which the private IP address for this Load Balancer should be located.
  - `tags`: (Optional) = A mapping of tags to assign to the individual public IP resource.
  - `create_public_ip_address`: (Optional) A boolean parameter to create a new public IP address resource for the Load Balancer
  - `new_public_ip_resource_group_name`: (Optional) A string for the name of the resource group to place the newly created public IP into. If null, will choose `location` from `public_ip_address_configuration` or `location` for the Load Balancer.
  - `new_public_ip_location`: (Optional) A string parameter for the location to deploy the public IP address resource.
  - `inherit_lock`: (Optional)  A boolean to determine if the lock from the Load Balancer will be inherited by the public IP.
  - `lock_type_if_not_inherited`: (Optional) An optional string to determine what kind of lock will be placed on the public IP is not inherited from the Load Balancer
  - `inherit_tags`: (Optional) A boolean to determine if the public IP will inherit tags from the Load Balancer.
  - `edge_zone`: (Optional) A string that specifies the Edge Zone within the Azure Region where this public IP should exist. Changing this forces a new Public IP to be created.
  - `zones`: (Optional) A list of strings that contains the availability zone to allocate the public IP in. Changing this forces a new resource to be created.
  - `role_assignments`: A map of objects that assigns a given principal (user or group) to a given role.
    - `role_definition_id_or_name`: The ID or name of the role definition to assign to the principal.
    - `principal_id`: The ID of the principal to assign the role to.
    - `description`: (Optional) A description of the role assignment.
    - `skip_service_principal_aad_check`: (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. This should only be set to true if using a service principal. Defaults to false.
    - `condition`: (Optional) A condition that will be used to scope the role assignment.
    - `condition_version`: (Optional) The version of the condition syntax. Valid values are '2.0'. Defaults to null.
    - `delegated_managed_identity_resource_id`: (Optional) The resource ID of the delegated managed identity.
  - `diagnostic_settings`: A map of objects that manage a Diagnostic Setting.
    - `name`: (Optional) The name of the diagnostic setting.
    - `log_groups`: (Optional) A set of log groups. Defaults to a set containing "allLogs".
    - `metric_categories`: (Optional) A set of metric categories. Defaults to a set containing "AllMetrics".
    - `log_analytics_destination_type`: (Optional) The destination type for log analytics. Defaults to "Dedicated".
    - `workspace_resource_id`: (Optional) The resource ID of the workspace. Defaults to null. This is a required field if `storage_account_resource_id`, `event_hub_authorization_rule_resource_id`, and `marketplace_partner_resource_id` are not set.
    - `storage_account_resource_id`: (Optional) The resource ID of the storage account. Defaults to null. This is a required field if `workspace_resource_id`, `event_hub_authorization_rule_resource_id`, and `marketplace_partner_resource_id` are not set.
    - `event_hub_authorization_rule_resource_id`: (Optional) The resource ID of the event hub authorization rule. Defaults to null. This is a required field if `workspace_resource_id`, `storage_account_resource_id`, and `marketplace_partner_resource_id` are not set.
    - `event_hub_name`: (Optional) The name of the event hub. Defaults to null.
    - `marketplace_partner_resource_id`: (Optional) The resource ID of the marketplace partner. Defaults to null. This is a required field if `workspace_resource_id`, `storage_account_resource_id`, and `event_hub_authorization_rule_resource_id` are not set.

  Example Input:
  ```terraform
  # Standard Regional IPv4 Private Ip Configuration
  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name = "internal_lb_private_ip_1_config"
      frontend_private_ip_address_version    = "IPv4"
      frontend_private_ip_address_allocation = "Dynamic"
    }

  # Standard Regional IPv4 Public IP Frontend IP Configuration
  frontend_ip_configurations = {
    frontend_configuration_1 = {
      name                     = "public_lb_public_ip_1_config"
      public_ip_address_name = "public_lb_public_ip_1"
      create_public_ip_address = true
    }
  }
```

Type:

```hcl
map(object({
    name                                               = optional(string)
    frontend_private_ip_address                        = optional(string)
    frontend_private_ip_address_version                = optional(string)
    frontend_private_ip_address_allocation             = optional(string, "Dynamic")
    frontend_private_ip_subnet_resource_id             = optional(string)
    gateway_load_balancer_frontend_ip_configuration_id = optional(string)
    public_ip_address_resource_name                    = optional(string)
    public_ip_address_resource_id                      = optional(string)
    public_ip_prefix_resource_id                       = optional(string)
    # frontend_private_ip_zones                                  = optional(set(string), [1, 2, 3])
    tags                              = optional(map(any), {})
    create_public_ip_address          = optional(bool, false)
    new_public_ip_resource_group_name = optional(string)
    new_public_ip_location            = optional(string)
    inherit_lock                      = optional(bool, true)
    lock_type_if_not_inherited        = optional(string, null)
    inherit_tags                      = optional(bool, true)
    edge_zone                         = optional(string)
    zones                             = optional(list(string), ["1", "2", "3"])

    role_assignments = optional(map(object({
      role_definition_id_or_name             = string
      principal_id                           = string
      description                            = optional(string, null)
      skip_service_principal_aad_check       = optional(bool, false) # only set to true IF using service principal
      condition                              = optional(string, null)
      condition_version                      = optional(string, null) # Valid values are 2.0
      delegated_managed_identity_resource_id = optional(string, null)
    })), {})

    diagnostic_settings = optional(map(object({
      name                                     = optional(string, null)
      log_categories                           = optional(set(string), [])
      log_groups                               = optional(set(string), ["allLogs"])
      metric_categories                        = optional(set(string), ["AllMetrics"])
      log_analytics_destination_type           = optional(string, "Dedicated")
      workspace_resource_id                    = optional(string, null)
      storage_account_resource_id              = optional(string, null)
      event_hub_authorization_rule_resource_id = optional(string, null)
      event_hub_name                           = optional(string, null)
      marketplace_partner_resource_id          = optional(string, null)
    })), {})
  }))
```

### <a name="input_location"></a> [location](#input\_location)

Description:   The Azure region where the resources should be deployed.  
  The full list of Azure regions can be found at: https://azure.microsoft.com/regions

Type: `string`

### <a name="input_name"></a> [name](#input\_name)

Description:   The name of the load balancer.

Type: `string`

### <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name)

Description:   The name of the resource group where the load balancer will be deployed.

Type: `string`

## Optional Inputs

The following input variables are optional (have default values):

### <a name="input_backend_address_pool_addresses"></a> [backend\_address\_pool\_addresses](#input\_backend\_address\_pool\_addresses)

Description:   A map of backend address pool addresses to associate with the backend address pool

  - `name`: (Optional) The name of the backend address pool address, if adding an address. Changing this forces a new backend address pool address to be created.
  - `backend_address_pool_object_name`: (Optional) The name of the backend address pool object within the virtual network. Changing this forces a new backend address pool address to be created.
  - `ip_address`: (Optional) The static IP address which should be allocated to the backend address pool.
  - `virtual_network_resource_id`: (Optional) The ID of the virtual network that the backend address pool address should be associated with. Helps with mapping to correct backend pool.

  ```terraform
  backend_address_pool_addresses = {
    address1 = {
      name                      = "backend_vm_address"
      backend_address_pool_object_name = "bepool_1"
      ip_address                = "10.10.1.5"
    }
  }
```

Type:

```hcl
map(object({
    name                             = optional(string)
    backend_address_pool_object_name = optional(string)
    ip_address                       = optional(string)
    virtual_network_resource_id      = optional(string)
  }))
```

Default: `{}`

### <a name="input_backend_address_pool_configuration"></a> [backend\_address\_pool\_configuration](#input\_backend\_address\_pool\_configuration)

Description:   String variable that determines the target virtual network for potential backend pools, at the load balancer level.  
  You can specify the `virutal_network_resource_id` at the pool level or backend address level.  
  If using network interfaces, leave this variable empty.

Type: `string`

Default: `null`

### <a name="input_backend_address_pool_network_interfaces"></a> [backend\_address\_pool\_network\_interfaces](#input\_backend\_address\_pool\_network\_interfaces)

Description:   A map of objects that associates one or more backend address pool network interfaces

  - `backend_address_pool_object_name`: (Optional) The name of the backend address pool object that this network interface should be associated with
  - `ip_configuration_name`: (Optional) The name of the IP configuration that this network interface should be associated with
  - `network_interface_resource_id`: (Optional) The ID of the network interface that should be associated with the backend address pool

  ```terraform
  backend_address_pool_network_interfaces = {
    node1 = {
      backend_address_pool_object_name = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/loadBalancers/{loadBalancerName}/backendAddressPools/{backendAddressPoolName}"
      ip_configuration_name = "ipconfig1"
      network_interface_resource_id = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Network/networkInterfaces/{networkInterfaceName}"
    }
  }
```

Type:

```hcl
map(object({
    backend_address_pool_object_name = optional(string)
    ip_configuration_name            = optional(string)
    network_interface_resource_id    = optional(string)
  }))
```

Default: `{}`

### <a name="input_backend_address_pools"></a> [backend\_address\_pools](#input\_backend\_address\_pools)

Description:   A map of objects that creates one or more backend pools

  - `name`: (Optional) The name of the backend address pool to create
  - `virtual_network_resource_id`: (Optional) The ID of the virtual network that the backend pool should be associated with. Sets pool to use only backend addresses via private IP. Leave empty if using network interfaces or mix of network interfaces and backend addresses.
  - `tunnel_interfaces`: (Optional) A map of objects that creates one or more tunnel interfaces for the backend pool
    - `identifier`: (Optional) The identifier of the tunnel interface
    - `type`: (Optional) The type of the tunnel interface
    - `protocol`: (Optional) The protocol of the tunnel interface
    - `port`: (Optional) The port of the tunnel interface

  ```terraform
  backend_address_pools = {
    pool1 = {
      name = "bepool1"
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
```

Type:

```hcl
map(object({
    name                        = optional(string, "bepool-1")
    virtual_network_resource_id = optional(string)
    tunnel_interfaces = optional(map(object({
      identifier = optional(number)
      type       = optional(string)
      protocol   = optional(string)
      port       = optional(number)
    })), {})
  }))
```

Default: `{}`

### <a name="input_diagnostic_settings"></a> [diagnostic\_settings](#input\_diagnostic\_settings)

Description:   A map of objects that manage a Diagnostic Setting.

  - `name`: (Optional) The name of the diagnostic setting.
  - `log_groups`: (Optional) A set of log groups. Defaults to a set containing "allLogs".
  - `metric_categories`: (Optional) A set of metric categories. Defaults to a set containing "AllMetrics".
  - `log_analytics_destination_type`: (Optional) The destination type for log analytics. Defaults to "Dedicated".
  - `workspace_resource_id`: (Optional) The resource ID of the workspace. Defaults to null. This is a required field if `storage_account_resource_id`, `event_hub_authorization_rule_resource_id`, and `marketplace_partner_resource_id` are not set.
  - `storage_account_resource_id`: (Optional) The resource ID of the storage account. Defaults to null. This is a required field if `workspace_resource_id`, `event_hub_authorization_rule_resource_id`, and `marketplace_partner_resource_id` are not set.
  - `event_hub_authorization_rule_resource_id`: (Optional) The resource ID of the event hub authorization rule. Defaults to null. This is a required field if `workspace_resource_id`, `storage_account_resource_id`, and `marketplace_partner_resource_id` are not set.
  - `event_hub_name`: (Optional) The name of the event hub. Defaults to null.
  - `marketplace_partner_resource_id`: (Optional) The resource ID of the marketplace partner. Defaults to null. This is a required field if `workspace_resource_id`, `storage_account_resource_id`, and `event_hub_authorization_rule_resource_id` are not set.

  Please note that at least one of `workspace_resource_id`, `storage_account_resource_id`, `marketplace_partner_resource_id`, or `event_hub_authorization_rule_resource_id` must be set.

  ```terraform
  diagnostic_settings = {
    diag_setting_1 = {
      name                                     = "diagSetting1"
      log_groups                               = ["allLogs"]
      metric_categories                        = ["AllMetrics"]
      log_analytics_destination_type           = "Dedicated"
      workspace_resource_id                    = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.OperationalInsights/workspaces/{workspaceName}"
      storage_account_resource_id              = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.Storage/storageAccounts/{storageAccountName}"
      event_hub_authorization_rule_resource_id = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/Microsoft.EventHub/namespaces/{namespaceName}/eventhubs/{eventHubName}/authorizationrules/{authorizationRuleName}"
      event_hub_name                           = "{eventHubName}"
      marketplace_partner_resource_id          = "/subscriptions/{subscriptionId}/resourceGroups/{resourceGroupName}/providers/{partnerResourceProvider}/{partnerResourceType}/{partnerResourceName}"
    }
  }
```

Type:

```hcl
map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_edge_zone"></a> [edge\_zone](#input\_edge\_zone)

Description:   Specifies the Edge Zone within the Azure Region where this Public IP and Load Balancer should exist.  
  Changing this forces new resources to be created.

Type: `string`

Default: `null`

### <a name="input_enable_telemetry"></a> [enable\_telemetry](#input\_enable\_telemetry)

Description:   This variable controls whether or not telemetry is enabled for the module.  
  For more information see https://aka.ms/avm/telemetry.  
  If it is set to false, then no telemetry will be collected.

Type: `bool`

Default: `true`

### <a name="input_frontend_subnet_resource_id"></a> [frontend\_subnet\_resource\_id](#input\_frontend\_subnet\_resource\_id)

Description:   (Optional) The frontend subnet id to use when in private mode. Can be used for all ip configurations that will use the same subnet. `frontend_private_ip_subnet_resource_id` can be set per frontend configuration for private ip.

Type: `string`

Default: `null`

### <a name="input_lb_nat_pools"></a> [lb\_nat\_pools](#input\_lb\_nat\_pools)

Description:   A map of objects that define the inbound NAT rules for a Load Balancer. Each object has the following

  - `name`: (Optional) The name of the Load Balancer rule. Changing this forces a new resource to be created.
  - `frontend_ip_configuration_name`: (Optional) The name of the frontend IP configuration to which the rule is associated with
  - `protocol`: (Optional) The transport protocol for the external endpoint. Possible values are All, Tcp, or Udp. To enable High availability ports feature, set protocol = "All", frontend_port = 0 and backend_port = 0. 
  - `frontend_port_start`: (Optional) The first port number in the range of external ports that will be used to provide Inbound NAT to NICs associated with this Load Balancer. Possible values range between 1 and 65534, inclusive.
  - `frontend_port_end`: (Optional) The last port number in the range of external ports that will be used to provide Inbound NAT to NICs associated with this Load Balancer. Possible values range between 1 and 65534, inclusive.
  - `backend_port`: (Optional) The port used for the internal endpoint. Possible values range between 1 and 65535, inclusive.
  - `idle_timeout_in_minutes`: (Optional) Specifies the idle timeout in minutes for TCP connections. Valid values are between 4 and 30 minutes. Defaults to 4 minutes.
  - `enable_floating_ip`: (Optional) A boolean parameter to determine if there are floating IPs enabled for this Load Balancer NAT rule. A "floating” IP is reassigned to a secondary server in case the primary server fails. Required to configure a SQL AlwaysOn Availability Group. Defaults to false.
  - `enable_tcp_reset`: (Optional) A boolean to determine if TCP Reset is enabled for this Load Balancer rule. Defaults to false.

  ```terraform
  lb_nat_pools = {
    lb_nat_pool_1 = {
      resource_group_name            = azurerm_resource_group.example.name
      loadbalancer_id                = azurerm_lb.example.id
      name                           = "SampleApplicationPool"
      protocol                       = "Tcp"
      frontend_port_start            = 80
      frontend_port_end              = 81
      backend_port                   = 8080
      frontend_ip_configuration_name = "PublicIPAddress"
    }
  }
```

Type:

```hcl
map(object({
    name                           = optional(string)
    frontend_ip_configuration_name = optional(string)
    protocol                       = optional(string, "Tcp")
    frontend_port_start            = optional(number, 3000)
    frontend_port_end              = optional(number, 3389)
    backend_port                   = optional(number, 3389)
    idle_timeout_in_minutes        = optional(number, 4)
    enable_floating_ip             = optional(bool, false)
    enable_tcp_reset               = optional(bool, false)
  }))
```

Default: `{}`

### <a name="input_lb_nat_rules"></a> [lb\_nat\_rules](#input\_lb\_nat\_rules)

Description:   A map of objects that specifies the creation of NAT rules.

  - `name`: (Optional) The name of the NAT rule. Changing this forces a new resource to be created
  - `frontend_ip_configuration_name`: (Optional) The name of the frontend IP configuration exposing this rule
  - `protocol`: (Optional) The transport protocol front the external endpoint. Possible values are All, Tcp, or Udp
  - `frontend_port`: (Optional) The port for the external endpoint. Port numbers for each Rule must be unique within the Load Balancer. Possible values range between 1 and 65534, inclusive. Leave null or 0 if protocol is set to All
  - `backend_port`: (Optional) The port used for internal connections on the endpoint. Possible values range between 1 and 65535, inclusive. Leave null or 0 if protocol is set to All
  - `frontend_port_start`: (Optional) The port range start for the external endpoint. This property is used together with BackendAddressPool and FrontendPortRangeEnd. Individual inbound NAT rule port mappings will be created for each backend address from BackendAddressPool. Acceptable values range from 1 to 65534, inclusive.
  - `frontend_port_end`: (Optional) The port range end for the external endpoint. This property is used together with BackendAddressPool and FrontendPortRangeStart. Individual inbound NAT rule port mappings will be created for each backend address from BackendAddressPool. Acceptable values range from 1 to 65534, inclusive.
  - `backend_address_pool_resource_id`: (Optional) The ID of the backend address pool that this NAT rule references
  - `backend_address_pool_object_name`: (Optional) The name of the backend address pool that this NAT rule references
  - `idle_timeout_in_minutes`: (Optional) Specifies the idle timeout in minutes for TCP connections. Valid values are between 4 and 30 minutes. Defaults to 4 minutes.
  - `enable_floating_ip`: (Optional) A boolean parameter to determine if there are floating IPs enabled for this Load Balancer NAT rule. A "floating” IP is reassigned to a secondary server in case the primary server fails. Required to configure a SQL AlwaysOn Availability Group. Defaults to false.
  - `enable_tcp_reset`: (Optional) A boolean parameter to determine if TCP Reset is enabled for this Load Balancer NAT rule. Defaults to false

  ```terraform
  lb_nat_rules = {
    lb_nat_rule_1 = {
      name                           = "tcp_nat_rule_1"
      frontend_ip_configuration_name = "internal_lb_private_ip_1_config"
      protocol = "Tcp"
      frontend_port = 3389
      backend_port = 3389
    }
  }
```

Type:

```hcl
map(object({
    name                             = optional(string)
    frontend_ip_configuration_name   = optional(string)
    protocol                         = optional(string)
    frontend_port                    = optional(number)
    backend_port                     = optional(number)
    frontend_port_start              = optional(number)
    frontend_port_end                = optional(number)
    backend_address_pool_resource_id = optional(string)
    backend_address_pool_object_name = optional(string)
    idle_timeout_in_minutes          = optional(number, 4)
    enable_floating_ip               = optional(bool, false)
    enable_tcp_reset                 = optional(bool, false)
  }))
```

Default: `{}`

### <a name="input_lb_outbound_rules"></a> [lb\_outbound\_rules](#input\_lb\_outbound\_rules)

Description:   A map of objects that define the outbound rules for a Load Balancer. Each object is identified by a unique key in the map and has the following properties:

  - `name`: (Optional) The name of the Load Balancer rule. Changing this forces a new resource to be created.
  - `frontend_ip_configuration_name`: (Optional) The list of names of the frontend IP configuration to which the rule is associated with
  - `backend_address_pool_resource_id`: (Optional) An ID that references a Backend Address Pool over which this Load Balancing Rule operates. Multiple backend pools only valid if Gateway SKU
  - `backend_address_pool_object_name`: (Optional) A name that references a Backend Address Pool over which this Load Balancing Rule operates. Multiple backend pools only valid if Gateway SKU
  - `protocol`: (Optional) The transport protocol for the external endpoint. Possible values are All, Tcp, or Udp.
  - `enable_tcp_reset`: A boolean to determine if TCP Reset is enabled for this Load Balancer rule. Defaults to false.
  - `number_of_allocated_outbound_ports`: (Optional)
  - `idle_timeout_in_minutes`: Specifies the idle timeout in minutes for TCP connections. Valid values are between 4 and 30 minutes. Defaults to 4 minutes.

  ```terraform
  lb_outbound_rules = {
    lb_outbound_rule_1 = {
      name = "outbound_rule_1"
      frontend_ip_configurations = [
        {
          name = "frontend_1"
        }
      ]
    }
  }
```

Type:

```hcl
map(object({
    name                               = optional(string)
    frontend_ip_configurations         = optional(list(object({ name = optional(string) })))
    backend_address_pool_resource_id   = optional(string)
    backend_address_pool_object_name   = optional(string)
    protocol                           = optional(string, "Tcp")
    enable_tcp_reset                   = optional(bool, false)
    number_of_allocated_outbound_ports = optional(number, 1024)
    idle_timeout_in_minutes            = optional(number, 4)
  }))
```

Default: `{}`

### <a name="input_lb_probes"></a> [lb\_probes](#input\_lb\_probes)

Description:   A list of objects that specify the Load Balancer probes to be created.  
  Each object has 7 parameters:

  - `name`: (Optional) The name of the probe. Changing this forces a new probe resource to be created.
  - `protocol`: (Optional) Specifies the protocol of the end point. Possible values are Http, Https or Tcp. If TCP is specified, a received ACK is required for the probe to be successful. If HTTP is specified, a 200 OK response from the specified URI is required for the probe to be successful.
  - `port`: (Optional) The port on which the probe queries the backend endpoint. Possible values range from 1 to 65535, inclusive.
  - `probe_threshold`: (Optional) The number of consecutive successful or failed probes that allow or deny traffic to this endpoint. Possible values range from 1 to 100. The default value is 1.
  - `request_path`: (Optional) The URI used for requesting health status from the backend endpoint. Required if protocol is set to Http or Https. Otherwise, it is not allowed.
  - `interval_in_seconds`: (Optional) The interval, in seconds between probes to the backend endpoint for health status. The default value is 15, the minimum value is 5.
  - `number_of_probes_before_removal`: (Optional) The number of failed probe attempts after which the backend endpoint is removed from rotation. The default value is 2. NumberOfProbes multiplied by intervalInSeconds value must be greater or equal to 10.Endpoints are returned to rotation when at least one probe is successful.

  ```terraform
  # Each type of probe
  lb_probes = {
    probe1 = {
      name     = "probe_1"
      protocol = "Tcp"
      port     = 80
      interval_in_seconds = 5
    },
    probe2 = {
      name         = "probe_2"
      protocol     = "Http"
      port         = 80
      request_path = "/"
      interval_in_seconds = 5
    },
    probe3 = {
      name         = "probe_3"
      protocol     = "Https"
      port         = 443
      request_path = "/"
      interval_in_seconds = 5
    }
  }
```

Type:

```hcl
map(object({
    name                            = optional(string)
    protocol                        = optional(string, "Tcp")
    port                            = optional(number, 80)
    interval_in_seconds             = optional(number, 15)
    probe_threshold                 = optional(number, 1)
    request_path                    = optional(string)
    number_of_probes_before_removal = optional(number, 2)
  }))
```

Default: `{}`

### <a name="input_lb_rules"></a> [lb\_rules](#input\_lb\_rules)

Description:   A list of objects that specifies the Load Balancer rules for the Load Balancer.  
  Each object has 14 parameters:

  - `name`: (Optional) The name of the Load Balancer rule. Changing this forces a new resource to be created.
  - `frontend_ip_configuration_name`: (Optional) The name of the frontend IP configuration to which the rule is associated with
  - `protocol`: (Optional) The transport protocol for the external endpoint. Possible values are All, Tcp, or Udp.
  - `frontend_port`: (Optional) The port for the external endpoint. Port numbers for each Rule must be unique within the Load Balancer. Possible values range between 0 and 65534, inclusive.
  - `backend_port`: (Optional) The port used for internal connections on the endpoint. Possible values range between 0 and 65535, inclusive.
  - `backend_address_pool_resource_ids`: (Optional) A list of IDs that reference to a Backend Address Pool over which this Load Balancing Rule operates. Multiple backend pools only valid if Gateway SKU
  - `backend_address_pool_object_names`: (Optional) A list of names reference to a Backend Address Pool object over which this Load Balancing Rule operates. Multiple backend pools only valid if Gateway SKU
  - `probe_resource_id`: The ID of the probe used by this Load balancing rule.
  - `probe_object_name`: The name of the probe object used by this Load balancing rule.
  - `enable_floating_ip`: (Optional) A boolean parameter to determine if there are floating IPs enabled for this Load Balancer NAT rule. A "floating” IP is reassigned to a secondary server in case the primary server fails. Required to configure a SQL AlwaysOn Availability Group. Defaults to false.
  - `idle_timeout_in_minutes`: Specifies the idle timeout in minutes for TCP connections. Valid values are between 4 and 30 minutes. Defaults to 4 minutes.
  - `load_distribution`: Specifies the load balancing distribution type to be used by the Load Balancer. Possible values are: Default – The load balancer is configured to use a 5 tuple hash to map traffic to available servers. SourceIP – The load balancer is configured to use a 2 tuple hash to map traffic to available servers. SourceIPProtocol – The load balancer is configured to use a 3 tuple hash to map traffic to available servers. Also known as Session Persistence, where the options are called None, Client IP and Client IP and Protocol respectively.
  - `disable_outbound_snat`: A boolean to determine if snat is enabled for this Load Balancer rules. Defaults to false.
  - `enable_tcp_reset`: A boolean to determine if TCP Reset is enabled for this Load Balancer rule. Defaults to false.

  ```terraform
  lb_rules = {
    lb_rule_1 = {
      name                               = "myHTTPRule"
      frontend_ip_configuration_name     = "myFrontend"
      backend_address_pool_object_names = ["myBackendPool"]
      protocol = "Tcp" # default
      frontend_port = 80
      backend_port = 80
      probe_object_name                = "tcp1"
      idle_timeout_in_minutes = 15
      enable_tcp_reset = true
    }
  }

```

Type:

```hcl
map(object({
    name                              = optional(string)
    frontend_ip_configuration_name    = optional(string)
    protocol                          = optional(string, "Tcp")
    frontend_port                     = optional(number, 3389)
    backend_port                      = optional(number, 3389)
    backend_address_pool_resource_ids = optional(list(string)) # multiple back end pools ONLY IF gateway sku load balancer
    backend_address_pool_object_names = optional(list(string)) # multiple back end pools ONLY IF gateway sku load balancer
    probe_resource_id                 = optional(string)
    probe_object_name                 = optional(string)
    enable_floating_ip                = optional(bool, false)
    idle_timeout_in_minutes           = optional(number, 4)
    load_distribution                 = optional(string, "Default")
    disable_outbound_snat             = optional(bool, false) # set `diasble_outbound_snat` to true when same frontend ip configuration is referenced by outbout rule and lb rule
    enable_tcp_reset                  = optional(bool, false)
  }))
```

Default: `{}`

### <a name="input_lock"></a> [lock](#input\_lock)

Description:   An object that sets a lock for the Load Balancer.

  - `name`: The name of the lock
  - `kind`: The type of lock to be created. Accepted values are `CanNotDelete` or `ReadOnly`. Defaults to None if kind is not set.

  ```terraform
  # Delete Lock for the Load Balancer
  lock = {
    name = "lock-{resourcename}"
    kind = "CanNotDelete"
  }
```

Type:

```hcl
object({
    kind = string
    name = optional(string, null)
  })
```

Default: `null`

### <a name="input_public_ip_address_configuration"></a> [public\_ip\_address\_configuration](#input\_public\_ip\_address\_configuration)

Description:   An object variable that configures the settings that will be the same for all public IPs for this Load Balancer

  - `allocation_method`: (Optional) The allocation method for this IP address. Possible valuse are `Static` or `Dynamic`
  - `resource_group_name`: (Optional) Specifies the resource group to deploy all of the public IP addresses to be created
  - `ddos_protection_mode`: (Optional) The DDoS protection mode of the public IP. Possible values are `Disabled`, `Enabled`, and `VirtualNetworkInherited`. Defaults to `VirtualNetworkInherited`.
  - `ddos_protection_plan_resource_id`: (Optional) The ID of DDoS protection plan associated with the public IP
  - `domain_name_label`: (Optional) The label for the Domain Name. This will be used to make up the FQDN. If a domain name label is specified, an A DNS record is created for the public IP in the Microsoft Azure DNS system.
  - `idle_timeout_in_minutes`: (Optional) Specifies the timeout for the TCP idle connection. The value can be set between 4 and 30 minutes.
  - `ip_tags`: (Optional) A mapping of IP tags to assign to the public IP. Changing this forces a new resource to be created.
  - `ip_version`: (Optional) The version of IP to use for the Public IPs. Possible valuse are `IPv4` or `IPv6`. Changing this forces a new resource to be created.
  - `public_ip_prefix_resource_id`: (Optional) If specified then public IP address allocated will be provided from the public IP prefix resource. Changing this forces a new resource to be created.
  - `reverse_fqdn`: (Optional) A fully qualified domain name that resolves to this public IP address. If the reverseFqdn is specified, then a PTR DNS record is created pointing from the IP address in the in-addr.arpa domain to the reverse FQDN.
  - `sku`: (Optional) The SKU of the Public IP. Accepted values are `Basic` and `Standard`. Defaults to `Standard`. Changing this forces a new resource to be created.
  - `sku_tier`: (Optional) The SKU Tier that should be used for the Public IP. Possible values are `Regional` and `Global`. Defaults to `Regional`. Changing this forces a new resource to be created.
  - `tags`: (Optional) The collection of tags to be assigned to all every Public IP.

  Example Input:
  ```terraform
  # Standard Regional IPv4 Public IP address Configuration
  public_ip_address_configuration = {
    allocation_method = "Static"
    ddos_protection_mode = "VirtualNetworkInherited"
    idle_timeout_in_minutes = 30
    ip_version = "IPv4"
    sku_tier = "Regional"
  }
```

Type:

```hcl
object({
    resource_group_name              = optional(string)
    allocation_method                = optional(string, "Static")
    ddos_protection_mode             = optional(string, "VirtualNetworkInherited")
    ddos_protection_plan_resource_id = optional(string)
    domain_name_label                = optional(string)
    idle_timeout_in_minutes          = optional(number, 4)
    ip_tags                          = optional(map(string))
    ip_version                       = optional(string, "IPv4")
    public_ip_prefix_resource_id     = optional(string)
    reverse_fqdn                     = optional(string)
    sku                              = optional(string, "Standard")
    sku_tier                         = optional(string, "Regional")
    tags                             = optional(map(any), {})
  })
```

Default: `{}`

### <a name="input_role_assignments"></a> [role\_assignments](#input\_role\_assignments)

Description:   A map of objects that assigns a given principal (user or group) to a given role.

  - `role_definition_id_or_name`: The ID or name of the role definition to assign to the principal.
  - `principal_id`: The ID of the principal to assign the role to.
  - `description`: (Optional) A description of the role assignment.
  - `skip_service_principal_aad_check`: (Optional) If set to true, skips the Azure Active Directory check for the service principal in the tenant. This should only be set to true if using a service principal. Defaults to false.
  - `condition`: (Optional) A condition that will be used to scope the role assignment.
  - `condition_version`: (Optional) The version of the condition syntax. Valid values are '2.0'. Defaults to null.
  - `delegated_managed_identity_resource_id`: (Optional) The resource ID of the delegated managed identity.

  ```terraform
  role_assignments = {
    role_assignment_1 = {
      role_definition_id_or_name             = "Contributor"
      principal_id                           = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
      skip_service_principal_aad_check       = true
    },
    role_assignment_2 = {
      role_definition_id_or_name             = "Storage Blob Data Reader"
      principal_id                           = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"
      description                            = "Example role assignment 2 of reader role"
      skip_service_principal_aad_check       = false
      condition                              = "@Resource[Microsoft.Storage/storageAccounts/blobServices/containers:ContainerName] StringEqualsIgnoreCase 'foo_storage_container'"
      condition_version                      = "2.0"
    }
  }
```

Type:

```hcl
map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false) # only set to true IF using service principal
    condition                              = optional(string, null)
    condition_version                      = optional(string, null) # Valid values are 2.0
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
```

Default: `{}`

### <a name="input_sku"></a> [sku](#input\_sku)

Description:   The SKU of the Azure Load Balancer.   
  Accepted values are `Basic`, `Standard`, and `Gateway`.  
  Microsoft recommends `Standard` for production workloads.
  `Basic` SKU is set to be retired 30 September 2025
  > The `Microsoft.Network/AllowGatewayLoadBalancer` feature is required to be registered in order to use the `Gateway` SKU. The feature can only be registered by the Azure service team, please submit an Azure support ticket for that.

Type: `string`

Default: `"Standard"`

### <a name="input_sku_tier"></a> [sku\_tier](#input\_sku\_tier)

Description:   String parameter that specifies the SKU tier of this Load Balancer.   
  Possible values are `Global` and `Regional`.   
  Defaults to `Regional`.   
  Changing this forces a new resource to be created.

Type: `string`

Default: `"Regional"`

### <a name="input_tags"></a> [tags](#input\_tags)

Description:   The tags to apply to the Load Balancer.

Type: `map(string)`

Default: `null`

## Outputs

The following outputs are exported:

### <a name="output_azurerm_lb"></a> [azurerm\_lb](#output\_azurerm\_lb)

Description: Outputs the entire Azure Load Balancer resource

### <a name="output_azurerm_lb_backend_address_pool"></a> [azurerm\_lb\_backend\_address\_pool](#output\_azurerm\_lb\_backend\_address\_pool)

Description: Outputs each backend address pool in its entirety

### <a name="output_azurerm_lb_nat_rule"></a> [azurerm\_lb\_nat\_rule](#output\_azurerm\_lb\_nat\_rule)

Description: Outputs each NAT rule in its entirety

### <a name="output_azurerm_public_ip"></a> [azurerm\_public\_ip](#output\_azurerm\_public\_ip)

Description: Outputs each Public IP Address resource in its entirety

### <a name="output_name"></a> [name](#output\_name)

Description: Outputs the entire Azure Load Balancer resource

### <a name="output_resource"></a> [resource](#output\_resource)

Description: Outputs the entire Azure Load Balancer resource

### <a name="output_resource_id"></a> [resource\_id](#output\_resource\_id)

Description: Outputs the entire Azure Load Balancer resource

## Modules

No modules.

<!-- markdownlint-disable-next-line MD041 -->
## Data Collection

The software may collect information about you and your use of the software and send it to Microsoft. Microsoft may use this information to provide services and improve our products and services. You may turn off the telemetry as described in the repository. There are also some features in the software that may enable you and Microsoft to collect data from users of your applications. If you use these features, you must comply with applicable law, including providing appropriate notices to users of your applications together with a copy of Microsoft’s privacy statement. Our privacy statement is located at <https://go.microsoft.com/fwlink/?LinkID=824704>. You can learn more about data collection and use in the help documentation and our privacy statement. Your use of the software operates as your consent to these practices.
<!-- END_TF_DOCS -->
