
resource "azurerm_public_ip" "application_gateway" {
  name                = "pip-${local.resource_suffix}-agw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  public_ip_prefix_id = azurerm_public_ip_prefix.main.id
  domain_name_label   = "${var.project}-${var.environment}"
}

resource "azurerm_user_assigned_identity" "agw" {
  name                = "id-${local.resource_suffix}-agw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "agw_key_vault_secrets_user" {
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.agw.principal_id
  scope                = "/subscriptions/${data.azurerm_client_config.main.subscription_id}/resourceGroups/${azurerm_resource_group.main.name}/providers/Microsoft.KeyVault/vaults/${azurerm_key_vault.main.name}/secrets/${local.key_vault_secret_name}"
}

resource "azurerm_web_application_firewall_policy" "main" {
  name                = "waf-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  policy_settings {
    enabled                     = true
    mode                        = "Prevention"
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
    request_body_check          = true
  }
}

resource "azurerm_application_gateway" "main" {
  depends_on = [
    azurerm_role_assignment.agw_key_vault_secrets_user
  ]
  name                = "agw-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.main.id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.agw.id]
  }

  autoscale_configuration {
    min_capacity = var.application_gateway_min_capacity
    max_capacity = var.application_gateway_max_capacity
  }

  backend_address_pool {
    name         = local.backend_address_pool_name
    ip_addresses = var.backend_address_pool_ip_addresses
  }

  dynamic "backend_http_settings" {
    for_each = var.tenants

    content {
      name                  = backend_http_settings.value
      cookie_based_affinity = "Disabled"
      port                  = 443
      protocol              = "Https"
    }
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.application_gateway.id
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = azurerm_subnet.application_gateway.id
  }

  dynamic "http_listener" {
    for_each = var.tenants

    content {
      name                           = "${http_listener.value}-http"
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.http_frontend_port_name
      protocol                       = "Http"
      host_name                      = "${http_listener.value}.${local.dns_zone_name}"
    }
  }

  dynamic "http_listener" {
    for_each = var.tenants

    content {
      name                           = "${http_listener.value}-https"
      frontend_ip_configuration_name = local.frontend_ip_configuration_name
      frontend_port_name             = local.https_frontend_port_name
      protocol                       = "Https"
      host_name                      = "${http_listener.value}.${local.dns_zone_name}"
      require_sni                    = true
      ssl_certificate_name           = local.ssl_certificate_name
    }
  }

  frontend_port {
    name = local.http_frontend_port_name
    port = 80
  }

  frontend_port {
    name = local.https_frontend_port_name
    port = 443
  }

  dynamic "request_routing_rule" {
    for_each = var.tenants

    content {
      name                        = "${request_routing_rule.value}-http"
      rule_type                   = "Basic"
      http_listener_name          = "${request_routing_rule.value}-http"
      redirect_configuration_name = request_routing_rule.value
    }
  }

  dynamic "request_routing_rule" {
    for_each = var.tenants

    content {
      name                       = "${request_routing_rule.value}-https"
      rule_type                  = "Basic"
      http_listener_name         = "${request_routing_rule.value}-https"
      backend_address_pool_name  = local.backend_address_pool_name
      backend_http_settings_name = request_routing_rule.value
    }
  }

  dynamic "redirect_configuration" {
    for_each = var.tenants

    content {
      name                 = redirect_configuration.value
      include_path         = true
      include_query_string = true
      redirect_type        = "Permanent"
      target_listener_name = "${redirect_configuration.value}-https"
    }
  }

  ssl_certificate {
    key_vault_secret_id = azurerm_key_vault_certificate.main.versionless_secret_id
    name                = local.ssl_certificate_name
  }
}
