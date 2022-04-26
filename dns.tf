data "azurerm_dns_zone" "main" {
  name                = local.dns_zone_name
  resource_group_name = local.dns_zone_resource_group_name
}

resource "azurerm_dns_a_record" "main" {
  for_each            = toset(var.tenants)
  name                = each.value
  zone_name           = data.azurerm_dns_zone.main.name
  resource_group_name = data.azurerm_dns_zone.main.resource_group_name
  ttl                 = 60
  target_resource_id  = azurerm_public_ip.application_gateway.id
}
