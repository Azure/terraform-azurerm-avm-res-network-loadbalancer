locals {
  regions = {
    east = { location = "eastus2", cidr = "10.75.1.0/24", backend_ip = "10.75.1.10", nic_ip = "10.75.1.11" }
    west = { location = "westus2", cidr = "10.76.1.0/24", backend_ip = "10.76.1.10", nic_ip = "10.76.1.11" }
  }
}
