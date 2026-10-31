# Cost Analysis — atlas-01-iac-foundation

## Resource Cost Breakdown

| Resource | SKU | Hourly Cost (USD) | Hourly Cost (INR) | Notes |
|----------|-----|-------------------|-------------------|-------|
| AKS Control Plane | Free tier | $0.00 | ₹0.00 | Free for standard AKS |
| AKS Node (1x Standard_B2s) | B2s (2 vCPU, 4GB) | ~$0.042 | ~₹3.50 | Burstable, cheapest viable |
| OS Disk (30GB Standard HDD) | Standard_LRS | ~$0.002 | ~₹0.17 | Reduced from default 128GB |
| ACR (Basic SKU) | Basic | ~$0.007 | ~₹0.58 | 10GB storage included |
| VNet (Hub + Spoke) | — | $0.00 | ₹0.00 | Free resource |
| NSG (Hub + Spoke) | — | $0.00 | ₹0.00 | Free resource |
| VNet Peering | — | $0.00* | ₹0.00* | Free for intra-region, data transfer charged |
| **Total** | | **~$0.051/hr** | **~₹4.25/hr** | |

## Projected Cost Per Session

| Duration | USD | INR |
|----------|-----|-----|
| 1 hour | ~$0.05 | ~₹4.25 |
| 2 hours | ~$0.10 | ~₹8.50 |
| 4 hours | ~$0.20 | ~₹17.00 |
| 8 hours (full day) | ~$0.41 | ~₹34.00 |

**Target: Complete deploy → verify → destroy in under 2 hours = ~₹9**

## Why These SKU Choices?

### B2s Over D2s
- B2s: 2 vCPU, 4GB RAM — $0.042/hr
- D2s_v3: 2 vCPU, 8GB RAM — $0.096/hr
- D2s is 2.3x the cost for RAM we don't need in non-prod.
- Interview: "I right-size nodes based on workload. Dev gets B2s, prod gets D4s."

### ACR Basic Over Standard
- Basic: $5/month, 10GB, 2 webhooks
- Standard: $20/month, 100GB, 10 webhooks
- We push 1 image. 10GB is 100x more than needed.

### 30GB OS Disk Over Default 128GB
- Default AKS OS disk = 128GB = ~$6/month
- 30GB OS disk = ~$1.40/month
- Node OS doesn't need 128GB. Pods use emptyDir or PVCs, not the OS disk.

## Tagging Strategy for Cost Attribution

Every resource carries these tags:

```
project      = "atlas-01"
environment  = "dev"
team         = "atlas-platform"
cost-center  = "atlas-platform"
created-by   = "terraform"
managed-by   = "terraform"
destroy-by   = "end-of-day"
```

### How to Query Cost by Tag
```
Azure Portal → Cost Management → Cost Analysis
→ Group by: Tag → project
→ Filter: project = atlas-01
```

This shows exact spend per project. Works across all 11 atlas projects.

## Cleanup

```bash
# Via pipeline: run azure-pipelines-destroy.yml
# Manual fallback:
az group delete --name rg-atlas-01-dev --yes --no-wait
```

**Never leave resources running overnight. The `destroy-by: end-of-day` tag is your reminder.**