locals {
  resource_suffix = "${var.project}-${var.environment}-${var.location}"
}

locals {
  backend_address_pool_name = "default"

  http_frontend_port_name  = "http"
  https_frontend_port_name = "https"

  frontend_ip_configuration_name = "default"

  gateway_ip_configuration_name = "default"

  ssl_certificate_name = var.project
}

locals {
  dns_zone_name                = split("/", var.dns_zone_id)[8]
  dns_zone_resource_group_name = split("/", var.dns_zone_id)[4]
}

locals {
  key_vault_secret_name = reverse(split("/", azurerm_key_vault_certificate.main.versionless_secret_id))[0]
}
