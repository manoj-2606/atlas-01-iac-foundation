# =============================================================================
# Locals — Naming Conventions + Cost Tags
# =============================================================================
# Every resource name follows: {resource-type}-{project}-{environment}
# Every resource gets default_tags for FinOps cost attribution.
# Change it here → changes everywhere. Single source of truth.
# =============================================================================

locals {
  # --- Naming ---
  resource_group_name = "rg-${var.project_name}-${var.environment}"
  hub_vnet_name       = "vnet-hub-${var.project_name}-${var.environment}"
  spoke_vnet_name     = "vnet-spoke-${var.project_name}-${var.environment}"
  aks_cluster_name    = "aks-${var.project_name}-${var.environment}"
  acr_name            = replace("acr${var.project_name}${var.environment}", "-", "")  # ACR names: alphanumeric only

  # --- FinOps Tags ---
  # Applied to EVERY resource. Non-negotiable.
  # Azure Cost Management can filter/group by any of these tags.
  default_tags = {
    project      = var.project_name
    environment  = var.environment
    team         = "atlas-platform"
    cost-center  = var.cost_center
    created-by   = var.created_by
    managed-by   = "terraform"
    destroy-by   = "end-of-day"   # Signal: this is ephemeral infrastructure
  }
}