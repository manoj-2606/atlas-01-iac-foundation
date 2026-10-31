# =============================================================================
# VNet Peering — Hub ↔ Spoke (bidirectional, feature-flagged)
# =============================================================================
# Peering is NOT transitive in Azure. If you have Hub + Spoke-A + Spoke-B:
#   Hub ↔ Spoke-A: ✅ can communicate
#   Hub ↔ Spoke-B: ✅ can communicate
#   Spoke-A ↔ Spoke-B: ❌ cannot communicate (unless peered directly or via NVA)
#
# count = var.enable_peering ? 1 : 0
#   → Feature flag. Set enable_peering = false in tfvars to skip peering entirely.
#   → Interview point: "I use feature flags in Terraform. Components are toggled
#     via variables, not by deleting code."
#
# allow_forwarded_traffic = true
#   → Required if hub runs an NVA/firewall that forwards traffic between spokes.
#   → We set it now so the topology is ready for a firewall later.
#
# allow_gateway_transit / use_remote_gateways
#   → For VPN/ExpressRoute gateway sharing. Not used here. Know the concept.
# =============================================================================

# --- Hub → Spoke peering ---
resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  count = var.enable_peering ? 1 : 0

  name                         = "peer-hub-to-spoke"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false  # No gateway in hub for this project
}

# --- Spoke → Hub peering ---
resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  count = var.enable_peering ? 1 : 0

  name                         = "peer-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  use_remote_gateways          = false  # No gateway to consume
}
