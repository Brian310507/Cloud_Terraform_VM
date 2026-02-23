output "resource_group_id" {
  description = "ID du Resource Group"
  value       = azurerm_resource_group.rg.id
}

output "vnet_name" {
  description = "Nom du VNET"
  value       = azurerm_virtual_network.vnet.name
}

output "subnet_id" {
  description = "ID du Subnet"
  value       = azurerm_subnet.subnet.id
}

output "load_balancer_public_ip" {
  description = "IP publique du Load Balancer"
  value       = azurerm_public_ip.lb_pip.ip_address
}