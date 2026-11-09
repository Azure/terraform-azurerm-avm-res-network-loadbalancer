resource "random_id" "example" {
  byte_length = 4
}

data "azapi_client_config" "current" {}

resource "azapi_resource" "resource_group" {
  location               = var.location
  name                   = "rg-lb-complete-${random_id.example.hex}"
  parent_id              = data.azapi_client_config.current.subscription_resource_id
  type                   = "Microsoft.Resources/resourceGroups@2025-04-01"
  response_export_values = []
}

resource "azapi_resource" "public_ip" {
  location  = var.location
  name      = "pip-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.Network/publicIPAddresses@2025-01-01"
  body = {
    sku = { name = "Standard", tier = "Regional" }
    # ARM can return the same zones in a different order.
    zones = toset(["1", "2", "3"])
    properties = {
      publicIPAllocationMethod = "Static"
      publicIPAddressVersion   = "IPv4"
      idleTimeoutInMinutes     = 10
      ddosSettings             = { protectionMode = "VirtualNetworkInherited" }
      dnsSettings              = { domainNameLabel = "lb-${random_id.example.hex}" }
      ipTags                   = []
    }
  }
  response_export_values = []
  tags                   = { example = "load-balancer" }
}

resource "azapi_resource" "workspace" {
  location  = var.location
  name      = "log-${random_id.example.hex}"
  parent_id = azapi_resource.resource_group.id
  type      = "Microsoft.OperationalInsights/workspaces@2023-09-01"
  body = {
    properties = {
      sku             = { name = "PerGB2018" }
      retentionInDays = 30
    }
  }
  response_export_values = []
}

module "loadbalancer" {
  source = "../../"

  frontend_ip_configurations = {
    public = { name = "public", public_ip_address_resource_id = azapi_resource.public_ip.id }
  }
  location              = var.location
  name                  = "lb-${random_id.example.hex}"
  parent_id             = azapi_resource.resource_group.id
  backend_address_pools = { app = { name = "app" } }
  diagnostic_settings = {
    metrics = {
      workspace_resource_id = azapi_resource.workspace.id
      metrics               = [{ category = "AllMetrics" }]
    }
  }
  enable_telemetry = var.enable_telemetry
  lb_nat_rules = {
    ssh = {
      name                             = "ssh"
      frontend_ip_configuration_name   = "public"
      frontend_port_start              = 50000
      frontend_port_end                = 50100
      backend_port                     = 22
      backend_address_pool_object_name = "app"
    }
  }
  lb_outbound_rules = {
    internet = {
      name                             = "internet"
      frontend_ip_configurations       = [{ name = "public" }]
      backend_address_pool_object_name = "app"
      protocol                         = "All"
      enable_tcp_reset                 = true
    }
  }
  lb_probes = {
    http = { name = "http", protocol = "Http", port = 8080, request_path = "/health" }
  }
  lb_rules = {
    web = {
      name                              = "web"
      frontend_ip_configuration_name    = "public"
      frontend_port                     = 443
      backend_port                      = 8080
      backend_address_pool_object_names = ["app"]
      probe_object_name                 = "http"
      disable_outbound_snat             = true
      enable_tcp_reset                  = true
    }
  }
  lock = { kind = "CanNotDelete" }
  role_assignments = {
    reader = {
      role_definition_id_or_name = "Reader"
      principal_id               = data.azapi_client_config.current.object_id
      principal_type             = "ServicePrincipal"
    }
  }
  tags = { example = "interfaces" }
}
