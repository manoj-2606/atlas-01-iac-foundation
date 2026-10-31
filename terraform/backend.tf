# =============================================================================
# Remote State Backend — Azure Blob Storage
# =============================================================================
# Values are NOT hardcoded here. They are injected via -backend-config flags
# in the ADO pipeline at runtime. This is the production pattern:
#   terraform init \
#     -backend-config="resource_group_name=rg-atlas-tfstate" \
#     -backend-config="storage_account_name=atlastfstate2606" \
#     -backend-config="container_name=tfstate" \
#     -backend-config="key=atlas-01.tfstate"
#
# Why not hardcode?
# - Storage account name might differ per environment
# - Key differs per project (atlas-01.tfstate, atlas-02.tfstate, etc.)
# - Backend config should come from pipeline variable groups, not Git
# =============================================================================

terraform {
  backend "azurerm" {}
}