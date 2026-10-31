# =============================================================================
# Provider Configuration — Azure Resource Manager
# =============================================================================
# Why skip_provider_registration = true?
# The service principal used by ADO pipeline may not have permission to register
# resource providers at subscription level. This flag prevents Terraform from
# attempting auto-registration. Providers must be pre-registered in the subscription.
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false  # Allow clean destroy
    }
  }

  skip_provider_registration = true
  use_oidc                   = true  # Pipeline authenticates via OIDC — no stored secrets
}