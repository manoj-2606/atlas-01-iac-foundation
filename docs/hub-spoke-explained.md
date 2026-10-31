# Hub-Spoke Network Topology — Why and When

## What Is Hub-Spoke?

Hub-spoke is Azure's recommended enterprise network architecture.

```
                    ┌─────────────┐
                    │   Hub VNet   │
                    │  10.0.0.0/16 │
                    │              │
                    │  • Firewall  │
                    │  • Bastion   │
                    │  • VPN GW    │
                    │  • DNS       │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
      ┌───────▼──────┐  ┌─▼──────────┐ ┌▼─────────────┐
      │ Spoke A      │  │ Spoke B    │ │ Spoke C      │
      │ (Team Alpha) │  │ (Team Beta)│ │ (Team Gamma) │
      │ AKS + Apps   │  │ VMs + DBs  │ │ ML Workloads │
      └──────────────┘  └────────────┘ └──────────────┘
```

- **Hub** = shared services. Firewall inspects all traffic. Bastion provides secure SSH/RDP. VPN gateway connects on-prem.
- **Spokes** = isolated workloads. Each team gets their own spoke. Blast radius contained.
- **Peering** = connects spoke to hub. Traffic between spokes routes through hub (if NVA/firewall configured).

## Why Not Just One Big VNet?

| Aspect | Single VNet | Hub-Spoke |
|--------|------------|-----------|
| Blast radius | Everything in one network | Isolated per spoke |
| Team autonomy | Shared space, conflicts | Each team owns their spoke |
| Security | Flat network, lateral movement risk | Traffic inspected at hub |
| Scaling | Address space conflicts | Each spoke has own CIDR |
| Cost visibility | Hard to attribute | Tag by spoke = cost per team |

## When to Use Hub-Spoke

**Use it when:**
- Multiple teams or workloads need network isolation
- You need centralized security inspection (firewall)
- Compliance requires network segmentation
- You're building an Azure Landing Zone

**Don't use it when:**
- Single team, single workload (overkill)
- Tight budget — firewall alone costs ~$900/month
- Simple app with no compliance requirements

## What We Built in This Project

- Hub VNet (10.0.0.0/16) — structure only, no firewall/bastion (cost)
- Spoke VNet (10.1.0.0/16) — AKS nodes live here
- Bidirectional peering — hub ↔ spoke connected
- NSGs on both subnets — baseline network security

**The topology is production-grade. The spend is portfolio-grade.**

## Key Facts for Interviews

1. **Peering is not transitive.** Spoke-A cannot reach Spoke-B through Hub unless an NVA (firewall) forwards traffic.
2. **Peering is non-overlapping.** Hub (10.0.x.x) and Spoke (10.1.x.x) must have different CIDR ranges.
3. **Peering is bidirectional but configured in two resources.** Hub→Spoke AND Spoke→Hub. Delete one = both break.
4. **Gateway transit** lets spokes use Hub's VPN/ExpressRoute gateway. Configured via `allow_gateway_transit` and `use_remote_gateways`.
5. **Azure Firewall** is the common NVA in hub. Inspects east-west (spoke→spoke) and north-south (spoke→internet) traffic.

## Reference Architecture

Microsoft's Cloud Adoption Framework (CAF) recommends hub-spoke as the default network topology for Azure Landing Zones. This project implements a simplified version of that reference architecture.