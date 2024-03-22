output "azurerm_lb" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = azurerm_lb.this
}

output "azurerm_lb_backend_address_pool" {
  description = "Outputs each backend address pool in its entirety"
  value       = azurerm_lb_backend_address_pool.this
}

output "azurerm_lb_nat_rule" {
  description = "Outputs each NAT rule in its entirety"
  value       = azurerm_lb_nat_rule.this
}

output "azurerm_public_ip" {
  description = "Outputs each Public IP Address resource in its entirety"
  value       = azurerm_public_ip.this
}

output "name" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = azurerm_lb.this.name
}

output "resource" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = azurerm_lb.this
}

output "resource_id" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = azurerm_lb.this.id
}
