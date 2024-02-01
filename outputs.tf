output "azurerm_lb" {
  description = "Outputs the entire Azure Load Balancer resource"
  value       = azurerm_lb.this
}

output "azurerm_public_ip" {
  description = "Outputs each Public IP Address resource in it's entirety"
  value       = azurerm_public_ip.this
}
