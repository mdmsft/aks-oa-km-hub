resource "azurerm_public_ip" "firewall" {
  name                = "pip-${local.resource_suffix}-afw"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 = "Standard"
  public_ip_prefix_id = azurerm_public_ip_prefix.main.id
}

resource "azurerm_firewall" "main" {
  name                = "afw-${local.resource_suffix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  firewall_policy_id  = azurerm_firewall_policy.main.id
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "default"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

resource "azurerm_firewall_policy" "main" {
  name                = "afwp-${local.resource_suffix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  dns {
    proxy_enabled = true
  }

  insights {
    enabled                            = true
    default_log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
    retention_in_days                  = 7
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "DefaultApplicationRuleCollectionGroup"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100

  application_rule_collection {
    name     = "app"
    priority = 110
    action   = "Allow"

    rule {
      name              = "ubuntu"
      source_addresses  = ["*"]
      destination_fqdns = ["security.ubuntu.com", "azure.archive.ubuntu.com", "changelogs.ubuntu.com"]

      protocols {
        type = "Http"
        port = 80
      }
    }

    rule {
      name             = "azure"
      source_addresses = ["*"]
      destination_fqdns = [
        "*.hcp.${var.location}.azmk8s.io",
        "mcr.microsoft.com",
        "*.data.mcr.microsoft.com",
        "management.azure.com",
        "login.microsoftonline.com",
        "packages.microsoft.com",
        "acs-mirror.azureedge.net",
        "*.ods.opinsights.azure.com",
        "*.oms.opinsights.azure.com",
        "${var.location}.dp.kubernetesconfiguration.azure.com",
      ]

      protocols {
        type = "Https"
        port = 443
      }
    }

    rule {
      name             = "registry"
      source_addresses = ["*"]
      destination_fqdns = [
        "k8s.gcr.io",
        "storage.googleapis.com",
        "auth.docker.io",
        "registry-1.docker.io",
        "production.cloudflare.docker.com",
      ]

      protocols {
        type = "Https"
        port = 443
      }
    }

    rule {
      name             = "chart"
      source_addresses = ["*"]
      destination_fqdns = [
        "kubernetes.github.io",
        "github.com",
        "objects.githubusercontent.com",
      ]

      protocols {
        type = "Https"
        port = 443
      }
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "main" {
  name                       = "default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  target_resource_id         = azurerm_firewall.main.id

  log {
    category = "AzureFirewallApplicationRule"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "AzureFirewallNetworkRule"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }

  log {
    category = "AzureFirewallDnsProxy"
    enabled  = true

    retention_policy {
      enabled = true
      days    = 7
    }
  }
}
