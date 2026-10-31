# =============================================================================
# Dev Environment Values — Auto-loaded by Terraform
# =============================================================================
# Terraform automatically loads any file named "terraform.tfvars" or
# "*.auto.tfvars" without needing -var-file flag.
#
# Override hierarchy (lowest → highest priority):
#   1. default in variables.tf
#   2. terraform.tfvars (this file)
#   3. *.auto.tfvars (alphabetical order)
#   4. -var-file="custom.tfvars" flag
#   5. -var="key=value" CLI flag
#   6. TF_VAR_* environment variables
#
# For prod: create prod.tfvars and pass -var-file="prod.tfvars" in pipeline.
# =============================================================================

# --- Core ---
project_name = "atlas-01"
environment  = "dev"
location     = "centralindia"

# --- Networking ---
hub_vnet_address_space   = ["10.0.0.0/16"]
hub_subnet_prefix        = "10.0.0.0/24"
spoke_vnet_address_space = ["10.1.0.0/16"]
aks_subnet_prefix        = "10.1.1.0/24"

# --- AKS ---
aks_node_count         = 1
aks_node_size          = "Standard_B2s"
aks_kubernetes_version = "1.35.9"

# --- Feature Flags ---
enable_acr     = true
enable_peering = true

# --- FinOps ---
cost_center = "atlas-platform"
created_by  = "terraform"