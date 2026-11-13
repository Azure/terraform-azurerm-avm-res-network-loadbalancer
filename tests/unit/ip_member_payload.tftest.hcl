# Payload regression only: mocks do not execute the provider HTTP path or ARM.
# The failed real addition remains FAIL even when every assertion here passes.
mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
}

mock_provider "random" {}

mock_provider "time" {}

override_resource {
  target = azapi_resource.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/loadBalancers/lab"
  }
}

variables {
  name             = "lab"
  parent_id        = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab"
  location         = "westus2"
  enable_telemetry = false
  frontend_ip_configurations = {
    public = { public_ip_address_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/publicIPAddresses/public" }
  }
  backend_address_pools = {
    app      = { name = "app", backend_address_type = "NIC" }
    ip       = { name = "ip", backend_address_type = "IP" }
    retained = { name = "retained", backend_address_type = "NIC" }
  }
  backend_address_pool_configuration = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab"
}

run "original_ip_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      static = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.10" }
    }
  }
  assert {
    condition = (
      length(local.backend_pool_members.ip) == 1 &&
      local.backend_pool_members.ip[0].properties.virtualNetwork.id == var.backend_address_pool_configuration &&
      !contains(keys(local.backend_pool_members), "app") &&
      !contains(keys(local.backend_pool_members), "retained")
    )
    error_message = "The IP pool must have a concrete member/VNet; separate NIC projections must remain unspecified."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "ip_members_use_address_level_network_scope" {
  command = apply
  variables {
    backend_address_pool_configuration = null
    backend_address_pool_addresses = {
      subnet = {
        name                             = "subnet-member"
        backend_address_pool_object_name = "ip"
        ip_address                       = "10.40.1.31"
        subnet_resource_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/backend"
      }
      vnet = {
        name                             = "vnet-member"
        backend_address_pool_object_name = "ip"
        ip_address                       = "10.40.1.32"
        virtual_network_resource_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/other"
      }
    }
  }
  assert {
    condition = (
      { for address in local.backend_pool_members.ip : address.name => address.properties } == {
        subnet-member = {
          ipAddress = "10.40.1.31"
          subnet    = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/lab/subnets/backend" }
        }
        vnet-member = {
          ipAddress      = "10.40.1.32"
          virtualNetwork = { id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/lab/providers/Microsoft.Network/virtualNetworks/other" }
        }
      }
    )
    error_message = "Backend members must serialize their address-level subnet or VNet without adding the other network scope."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "exact_failed_addition_payload_not_persistence" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      static = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.10" }
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.11" }
    }
  }
  assert {
    condition = (
      { for a in azapi_update_resource.backend_members["ip"].body.properties.loadBalancerBackendAddresses : a.name => a.properties.ipAddress } == jsondecode(file("tests/fixtures/ip-member-persistence.json")).expected &&
      jsondecode(file("tests/fixtures/ip-member-persistence.json")).observed != jsondecode(file("tests/fixtures/ip-member-persistence.json")).expected &&
      jsondecode(file("tests/fixtures/ip-member-persistence.json")).result == "FAIL" &&
      azapi_resource.this.ignore_body_changes == null &&
      azapi_resource.this.ignore_other_items_in_list == null &&
      alltrue([for a in local.backend_pool_members.ip :
        a.properties.virtualNetwork.id == var.backend_address_pool_configuration &&
        !contains(keys(a.properties), "networkInterfaceIPConfiguration")
      ])
    )
    error_message = "Reproduce the failed desired list without filtering members or mistaking the historical GET mismatch for success."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "update_member_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      static = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.10" }
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.12" }
    }
  }
  assert {
    condition = (
      { for a in local.backend_pool_members.ip : a.name => a.properties.ipAddress } == { second = "10.40.1.12", static = "10.40.1.10" } &&
      !contains(keys(local.backend_pool_members), "app") &&
      !contains(keys(local.backend_pool_members), "retained")
    )
    error_message = "Updating one IP must retain the other IP without writing NIC projections."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "remove_one_member_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.12" }
    }
  }
  assert {
    condition     = { for a in local.backend_pool_members.ip : a.name => a.properties.ipAddress } == { second = "10.40.1.12" }
    error_message = "Removing static must retain exactly second; deletion cannot be represented by omission of the whole list."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "last_member_clear_payload" {
  command = apply
  variables {
    backend_address_pool_addresses = {}
  }
  assert {
    condition = (
      length(azapi_update_resource.backend_members["ip"].body.properties.loadBalancerBackendAddresses) == 0 &&
      azapi_update_resource.backend_members["ip"].body.properties.loadBalancerBackendAddresses != null &&
      var.backend_address_pools.ip.backend_address_type == "IP" &&
      !contains(keys(local.backend_pool_members), "app") &&
      !contains(keys(local.backend_pool_members), "retained") &&
      azapi_resource.this.ignore_body_changes == null
    )
    error_message = "Last-member removal must emit a compared [] in IP mode, not null, NIC mode or an ignore."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "restore_ip_after_empty" {
  command = apply
  variables {
    backend_address_pool_addresses = {
      static = { name = "static", backend_address_pool_object_name = "ip", ip_address = "10.40.1.10" }
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.11" }
    }
  }
  assert {
    condition     = length(azapi_update_resource.backend_members["ip"].body.properties.loadBalancerBackendAddresses) == 2 && length(azapi_update_resource.backend_members) == 1
    error_message = "Restore both explicit IPs without adding writers for either native NIC pool."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}

run "same_count_ip_rename_retarget_and_omit_vnet" {
  command = apply
  variables {
    backend_address_pool_configuration = null
    backend_address_pool_addresses = {
      static = { name = "renamed", backend_address_pool_object_name = "ip", ip_address = "10.40.1.21", virtual_network_resource_id = null }
      second = { name = "second", backend_address_pool_object_name = "ip", ip_address = "10.40.1.22" }
    }
  }
  assert {
    condition = (
      { for a in local.backend_pool_members.ip : a.name => a.properties.ipAddress } == { renamed = "10.40.1.21", second = "10.40.1.22" } &&
      alltrue([for a in local.backend_pool_members.ip : !contains(keys(a.properties), "virtualNetwork")]) &&
      alltrue([for p in azapi_resource.this.body.properties.backendAddressPools : !contains(keys(p.properties), "loadBalancerBackendAddresses")])
    )
    error_message = "Same-count IP mutations and null VNet must not copy former member fields or move membership into the parent skeleton."
  }
  providers = {
    azapi  = azapi
    random = random
    time   = time
  }
}
