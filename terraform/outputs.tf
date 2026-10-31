# =============================================================================
# Outputs — Values consumed by pipeline validation scripts + future projects
# =============================================================================
# These outputs serve two purposes:
# 1. PowerShell validation scripts read them to verify deployment health
# 2. If another project ever needs to reference this infra, outputs are the API
#
# Sensitive outputs (kube_config_raw) are marked sensitive = true
#   → Terraform won't display them in CLI output
#   → Pipeline can still access them via `terraform output -raw`
# =============================================================================

# --- Resource Group ---
output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

# --- AKS ---
output "aks_cluster_name" {
  description = "AKS cluster name"
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "AKS cluster resource ID"
  value       = azurerm_kubernetes_cluster.main.id
}

output "kube_config_raw" {
  description = "Raw kubeconfig for kubectl access (sensitive)"
  value       = azurerm_kubernetes_cluster.main.kube_config_raw
  sensitive   = true
}

output "aks_identity_principal_id" {
  description = "AKS managed identity principal ID"
  value       = azurerm_kubernetes_cluster.main.identity[0].principal_id
}

# --- ACR (conditional) ---
output "acr_login_server" {
  description = "ACR login server URL (empty if ACR disabled)"
  value       = var.enable_acr ? azurerm_container_registry.main[0].login_server : ""
}

output "acr_name" {
  description = "ACR name (empty if ACR disabled)"
  value       = var.enable_acr ? azurerm_container_registry.main[0].name : ""
}

# --- Networking ---
output "hub_vnet_id" {
  description = "Hub VNet resource ID"
  value       = azurerm_virtual_network.hub.id
}

output "spoke_vnet_id" {
  description = "Spoke VNet resource ID"
  value       = azurerm_virtual_network.spoke.id
}

output "aks_subnet_id" {
  description = "AKS subnet resource ID"
  value       = azurerm_subnet.aks.id
}

# --- Feature flag status (for validation scripts) ---
output "peering_enabled" {
  description = "Whether hub-spoke peering is active"
  value       = var.enable_peering
}

output "acr_enabled" {
  description = "Whether ACR is provisioned"
  value       = var.enable_acr
}