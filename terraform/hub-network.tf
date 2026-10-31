# =============================================================================
# Hub Network — Central Services VNet
# =============================================================================
# Hub-spoke is the Azure recommended network topology for enterprise workloads.
#
# Hub VNet = shared services (firewall, bastion, VPN gateway, DNS)
# Spoke VNet = isolated workloads (AKS, app services, databases)
#
# In this project: hub exists as topology. No firewall/bastion deployed (cost).
# The architecture is production-grade. The spend is portfolio-grade.
#
# Interview point: "I used hub-spoke topology. Hub hosts shared services,
# spokes host workloads. Traffic between spokes routes through hub for
# centralized inspection and policy enforcement."
# =============================================================================

# --- Resource Group (shared by all resources in this project) ---
resource "azurerm_resource_group" "main" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.default_tags
}

# --- Hub VNet ---
resource "azurerm_virtual_network" "hub" {
  name                = local.hub_vnet_name
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.hub_vnet_address_space
  tags                = local.default_tags
}

# --- Hub Subnet (placeholder for shared services) ---
# In production: AzureFirewallSubnet, AzureBastionSubnet, GatewaySubnet
# Here: one general subnet to demonstrate the structure
resource "azurerm_subnet" "hub_default" {
  name                 = "snet-hub-shared"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.hub_subnet_prefix]
}

# --- Hub NSG ---
# Baseline security: deny all inbound by default, allow VNet-to-VNet
resource "azurerm_network_security_group" "hub_nsg" {
  name                = "nsg-hub-${var.project_name}-${var.environment}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.default_tags

  security_rule {
    name                       = "AllowVNetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

resource "azurerm_subnet_network_security_group_association" "hub_nsg_assoc" {
  subnet_id                 = azurerm_subnet.hub_default.id
  network_security_group_id = azurerm_network_security_group.hub_nsg.id
}