# =============================================================================
# Variables — Inputs for atlas-01-iac-foundation
# =============================================================================
# Design principle: every configurable value is a variable. Nothing hardcoded.
# Feature flags (enable_*) let you toggle components without touching code.
# =============================================================================

# --- Core ---

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "atlas-01"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "centralindia"
}

# --- Networking ---

variable "hub_vnet_address_space" {
  description = "Address space for hub VNet (central services)"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "hub_subnet_prefix" {
  description = "Subnet CIDR within hub VNet (placeholder for future firewall/bastion)"
  type        = string
  default     = "10.0.0.0/24"
}

variable "spoke_vnet_address_space" {
  description = "Address space for spoke VNet (workloads)"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "Subnet CIDR for AKS nodes within spoke VNet"
  type        = string
  default     = "10.1.1.0/24"
}

# --- AKS ---

variable "aks_node_count" {
  description = "Number of nodes in the default system pool"
  type        = number
  default     = 1

  validation {
    condition     = var.aks_node_count >= 1 && var.aks_node_count <= 5
    error_message = "Node count must be between 1 and 5."
  }
}

variable "aks_node_size" {
  description = "VM SKU for AKS nodes (B2s = cheapest burstable for non-prod)"
  type        = string
  default     = "Standard_B2s"
}

variable "aks_kubernetes_version" {
  description = "Kubernetes version for AKS"
  type        = string
  default     = "1.30"
}

# --- Feature Flags ---

variable "enable_acr" {
  description = "Toggle Azure Container Registry creation on/off"
  type        = bool
  default     = true
}

variable "enable_peering" {
  description = "Toggle hub-spoke VNet peering on/off"
  type        = bool
  default     = true
}

# --- FinOps ---

variable "cost_center" {
  description = "Cost center for FinOps attribution"
  type        = string
  default     = "atlas-platform"
}

variable "created_by" {
  description = "Creator tag for resource ownership"
  type        = string
  default     = "terraform"
}