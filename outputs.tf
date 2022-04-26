output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "firewall_ip_address" {
  value = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "virtual_network_id" {
  value = azurerm_virtual_network.main.id
}

output "container_registry_private_dns_zone_id" {
  value = azurerm_private_dns_zone.container_registry.id
}