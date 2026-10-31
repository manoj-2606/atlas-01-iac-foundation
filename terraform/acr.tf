# =============================================================================
# Azure Container Registry — Docker image storage
# =============================================================================
# Feature-flagged: count = var.enable_acr ? 1 : 0
#   → Set enable_acr = false to skip ACR entirely (saves ~₹15/day).
#   → Some projects (P1 focus is networking) may not need ACR at all.
#
# admin_enabled = false
#   → No username/password. AKS authenticates via AcrPull role assignment.
#   → Interview: "ACR admin is disabled. Authentication is via managed identity
#     role assignment — AcrPull on the kubelet identity. Zero shared credentials."
#
# Basic SKU
#   → 10GB storage, 2 webhooks. No geo-replication. Sufficient for portfolio.
#   → Standard = 100GB + more throughput. Premium = geo-replication.
#   → FinOps: Basic ~₹15/day vs Standard ~₹60/day. 4x cost for features we don't need.
# =============================================================================

resource "azurerm_container_registry" "main" {
  count = var.enable_acr ? 1 : 0

  name                = local.acr_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Basic"
  admin_enabled       = false
  tags                = local.default_tags
}