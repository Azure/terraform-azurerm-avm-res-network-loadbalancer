output "azurerm_lb_backend_address_pool" {
  description = "Outputs each backend address pool"
  value       = module.loadbalancer.azurerm_lb_backend_address_pool
}

output "resource" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = module.loadbalancer.resource
}

output "resource_id" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = module.loadbalancer.resource_id
}
