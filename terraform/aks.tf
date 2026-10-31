# =============================================================================
# AKS Cluster — Kubernetes on Azure
# =============================================================================
# Design decisions:
#
# 1. SystemAssigned managed identity (not service principal)
#    → No credential rotation. Azure manages the identity lifecycle.
#    → Interview: "I use managed identity for AKS. Zero credentials to manage."
#
# 2. Kubelet identity gets AcrPull role (not ACR admin)
#    → Nodes pull images using RBAC, not a shared password.
#    → ACR admin_enabled = false. No username/password anywhere.
#
# 3. azure-cni network plugin (not kubenet)
#    → Every pod gets a real VNet IP. No NAT, no overlay.
#    → Required for VNet peering, NetworkPolicy, and production workloads.
#    → Trade-off: consumes more subnet IPs. That's why subnet sizing matters.
#
# 4. os_disk_size_gb = 30
#    → Default is 128GB. Non-prod doesn't need it. Saves ~₹5/day.
#
# 5. private_cluster_enabled = false
#    → Pipeline agent (Microsoft-hosted) needs public API access to deploy.
#    → Production would use private cluster + self-hosted agent inside VNet.
#    → Interview: "I know private clusters exist. For this, I chose public
#       because the pipeline agent is Microsoft-hosted and needs API access."
# =============================================================================

resource "azurerm_kubernetes_cluster" "main" {
  name                = local.aks_cluster_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = var.project_name
  kubernetes_version  = var.aks_kubernetes_version
  tags                = local.default_tags

  # --- Identity ---
  identity {
    type = "SystemAssigned"
  }

  # --- Default Node Pool ---
  default_node_pool {
    name            = "system"
    node_count      = var.aks_node_count
    vm_size         = var.aks_node_size
    os_disk_size_gb = 30
    vnet_subnet_id  = azurerm_subnet.aks.id
    type            = "VirtualMachineScaleSets" # Required for autoscaling
    tags            = local.default_tags

    # Ephemeral OS disk — uses the VM's local SSD instead of managed disk
    # Faster boot, no disk cost, but data lost on reimage/restart
    # Perfect for non-prod where node state doesn't matter
    os_disk_type = "Managed" # Use Managed for B2s (no local SSD large enough for Ephemeral)
  }

  # --- Networking ---
  network_profile {
    network_plugin    = "azure"  # Azure CNI — pods get real VNet IPs
    network_policy    = "calico" # Calico NetworkPolicy enforcement
    service_cidr      = "172.16.0.0/16"
    dns_service_ip    = "172.16.0.10"
    load_balancer_sku = "standard"
  }

  # --- Auto-upgrade channel ---
  # patch = auto-apply minor K8s patches. No breaking changes.
  automatic_channel_upgrade = "patch"
}

# =============================================================================
# AcrPull Role Assignment — AKS kubelet identity → ACR
# =============================================================================
# This lets AKS nodes pull images from ACR without any credentials.
# The kubelet_identity is a managed identity that Azure creates automatically
# when AKS uses SystemAssigned identity.
#
# count = var.enable_acr ? 1 : 0
#   → Only create this role assignment if ACR exists.
# =============================================================================

resource "azurerm_role_assignment" "aks_acr_pull" {
  count = var.enable_acr ? 1 : 0

  principal_id                     = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.main[0].id
  skip_service_principal_aad_check = true # Speed up — we know it's a managed identity
}