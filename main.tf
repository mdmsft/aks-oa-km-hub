terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy               = true
      purge_soft_deleted_certificates_on_destroy = true
      purge_soft_deleted_keys_on_destroy         = true
      purge_soft_deleted_secrets_on_destroy      = true
    }
  }
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "main" {}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.resource_suffix}"
  location = var.location
  tags = {
    project     = var.project
    environment = var.environment
    location    = var.location
  }
}

resource "azurerm_user_assigned_identity" "policy_tag" {
  name                = "id-${local.resource_suffix}-policy-tag"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
}

resource "azurerm_role_assignment" "policy_tag_contributor" {
  role_definition_name = "Contributor"
  scope                = azurerm_resource_group.main.id
  principal_id         = azurerm_user_assigned_identity.policy_tag.principal_id
}

resource "azurerm_resource_group_policy_assignment" "inherit_tag" {
  for_each = azurerm_resource_group.main.tags

  depends_on = [
    azurerm_role_assignment.policy_tag_contributor
  ]

  name                 = "Inherit tag ${each.key} from resource group"
  location             = azurerm_resource_group.main.location
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/ea3f2387-9b95-492a-a190-fcdc54f7b070"
  resource_group_id    = azurerm_resource_group.main.id
  parameters           = <<EOF
  {
    "tagName": {
      "value": "${each.key}"
    }
  }
  EOF

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.policy_tag.id]
  }
}
