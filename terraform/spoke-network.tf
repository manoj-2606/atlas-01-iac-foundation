# =============================================================================
# Spoke Network — Workload VNet (AKS nodes live here)
# =============================================================================
# Spoke is isolated from hub by default. Peering (in peering.tf) connects them.
# Each workload team gets their own spoke — blast radius is contained.
#
# AKS subnet sizing:
#   /24 = 254 usable IPs. With Azure CNI, each pod gets a real IP.
#   Max pods per node (default 30) × node count must fit in subnet.
#   1 node × 30 pods = 30 IPs. /24 is more than enough for non-prod.
#   Production would use /22 or /21 for growth.
# =============================================================================

# --- Spoke VNet ---
resource "azurerm_virtual_network" "spoke" {
  name                = local.spoke_vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.spoke_vnet_address_space
  tags                = local.default_tags
}

# --- AKS Subnet ---
resource "azurerm_subnet" "aks" {
  name                 = "snet-aks-${var.project_name}-${var.environment}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# --- Spoke NSG ---
# AKS-specific rules: allow kubelet (10250), deny SSH from internet
resource "azurerm_network_security_group" "spoke_nsg" {
  name                = "nsg-spoke-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.default_tags

  # Allow traffic from hub VNet (shared services → workloads)
  security_rule {
    name                       = "AllowHubInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.hub_vnet_address_space[0]
    destination_address_prefix = "VirtualNetwork"
  }

  # Block direct SSH from internet to AKS nodes
  security_rule {
    name                       = "DenySSHFromInternet"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "spoke_nsg_assoc" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.spoke_nsg.id
}