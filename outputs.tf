# TODO: insert outputs here.

output "azurerm_lb" {
  value = azurerm_lb.this
  description = "Outputs the entire Azure Load Balancer resource"
}

output "azurerm_public_ip" {
  value = azurerm_public_ip.azlb
  description = "Outputs each Public IP Address resource in it's entirety"
}