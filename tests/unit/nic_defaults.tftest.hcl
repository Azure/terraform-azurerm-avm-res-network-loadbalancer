# Provider mocks prove ownership selection, not real existing-state conversion.
mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

variables {
  name             = "lab"
  location         = "eastus2"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab"
  enable_telemetry = false
  frontend_ip_configurations = {
    internal = { frontend_private_ip_subnet_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/app" }
  }
  backend_address_pools = {
    omitted = { name = "omitted" }
    null    = { name = "null", backend_address_type = null }
  }
}

run "default_and_null_nic_have_no_member_owners" {
  command = apply
  assert {
    condition = (
      alltrue([for p in var.backend_address_pools : p.backend_address_type == "NIC"]) &&
      length(local.backend_pool_members) == 0 &&
      length(azapi_update_resource.backend_members) == 0 &&
      length(azapi_resource_action.clear_backend_members) == 0 &&
      alltrue([for p in azapi_resource.this.body.properties.backendAddressPools :
        !contains(keys(p.properties), "loadBalancerBackendAddresses") &&
        !contains(keys(p.properties), "backendIPConfigurations")
      ])
    )
    error_message = "Default/null NIC pools must omit projections and create no explicit-member updater or cleanup."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "standalone_default_nic_has_no_cleanup" {
  command = apply
  module {
    source = "./modules/backend-address-pool"
  }
  variables {
    parent_id  = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
    properties = {}
  }
  assert {
    condition     = var.backend_address_type == "NIC" && !contains(keys(azapi_resource.this.body.properties), "loadBalancerBackendAddresses") && length(azapi_resource_action.clear_backend_members) == 0
    error_message = "Standalone omission must select NIC and never initialize explicit-member cleanup."
  }
}

run "standalone_null_nic_has_no_cleanup" {
  command = apply
  module {
    source = "./modules/backend-address-pool"
  }
  variables {
    parent_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
    backend_address_type = null
    properties           = {}
  }
  assert {
    condition     = var.backend_address_type == "NIC" && !contains(keys(azapi_resource.this.body.properties), "loadBalancerBackendAddresses") && length(azapi_resource_action.clear_backend_members) == 0
    error_message = "Standalone null must use the non-null NIC default without cleanup."
  }
}

run "standalone_default_rejects_explicit_ip_members" {
  command = plan
  module {
    source = "./modules/backend-address-pool"
  }
  variables {
    parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
    properties = {
      loadBalancerBackendAddresses = [{ name = "static", properties = { ipAddress = "10.40.1.10" } }]
    }
  }
  expect_failures = [var.properties]
}

run "standalone_ip_opt_in_keeps_empty_list_and_cleanup" {
  command = apply
  module {
    source = "./modules/backend-address-pool"
  }
  variables {
    parent_id            = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
    backend_address_type = "IP"
    properties           = {}
  }
  assert {
    condition     = length(azapi_resource.this.body.properties.loadBalancerBackendAddresses) == 0 && length(azapi_resource_action.clear_backend_members) == 1 && length(azapi_resource_action.clear_backend_members[0].body.properties.loadBalancerBackendAddresses) == 0
    error_message = "Explicit IP must remain an authoritative empty list with fixed-empty cleanup."
  }
}
