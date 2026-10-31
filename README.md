# atlas-01-iac-foundation

**Infrastructure as Code Foundation** — Production-grade AKS cluster with hub-spoke networking, Terraform remote state, feature flags, and FinOps tagging. Deployed and validated entirely via Azure DevOps pipelines.

Part of the [Atlas Platform](https://github.com/manoj-2606) portfolio — 11 production-grade Azure cloud projects.

---

## Problem

Provisioning Kubernetes infrastructure manually leads to configuration drift, undocumented dependencies, and untagged resources that can't be attributed for cost. Teams need a repeatable, auditable, pipeline-driven approach with cost visibility from Day 1.

## Solution

A Terraform-based IaC foundation that provisions a complete AKS environment using hub-spoke network topology. Every resource is tagged for cost attribution. Feature flags toggle components without code changes. Post-deploy validation scripts verify infrastructure health independently of Terraform.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  Resource Group: rg-atlas-01-dev                         │
│                                                           │
│  ┌──────────────────┐       ┌──────────────────────────┐ │
│  │  Hub VNet         │       │  Spoke VNet               │ │
│  │  10.0.0.0/16      │◄─────►│  10.1.0.0/16              │ │
│  │  snet-hub-shared  │       │  snet-aks-atlas-01-dev    │ │
│  │  + NSG            │       │  + NSG (deny SSH, allow   │ │
│  │                   │       │    hub traffic)            │ │
│  │  (future: FW,     │       │                           │ │
│  │   Bastion, VPN)   │       │  AKS nodes live here      │ │
│  └──────────────────┘       └──────────────────────────┘ │
│        Bidirectional VNet Peering (feature-flagged)        │
│                                                           │
│  ┌──────────────────┐       ┌──────────────────────────┐ │
│  │  AKS Cluster      │       │  ACR (Basic SKU)          │ │
│  │  1x Standard_B2s  │──────►│  (feature-flagged)         │ │
│  │  Azure CNI        │ Pull  │  Admin disabled            │ │
│  │  Calico policy    │       │  AcrPull via managed ID    │ │
│  │  SystemAssigned MI │       └──────────────────────────┘ │
│  └──────────────────┘                                     │
│                                                           │
│  Tags: project | environment | team | cost-center |       │
│        created-by | managed-by | destroy-by                │
└─────────────────────────────────────────────────────────┘
```

## Tech Stack

| Technology | Purpose |
|-----------|---------|
| **Terraform** (~> 3.100 azurerm) | Infrastructure provisioning |
| **Azure DevOps Pipelines** | CI/CD — plan, apply, validate, destroy |
| **PowerShell** (Az module) | Post-deploy and post-destroy validation |
| **Bash** | Terraform CLI operations, backend bootstrap |
| **Azure CNI** | Pod networking — real VNet IPs per pod |
| **Calico** | Network policy enforcement |
| **gitleaks** | Pre-commit secret detection |

## Features

- **Hub-spoke topology** — Network isolation with bidirectional VNet peering
- **Feature flags** — `enable_acr` and `enable_peering` toggle components via variables
- **Remote state** — Azure Blob backend with lease locking, bootstrapped by pipeline
- **OIDC authentication** — Pipeline authenticates via federated credential, zero stored secrets
- **FinOps tagging** — 7 tags on every resource for cost attribution
- **Post-deploy validation** — PowerShell script verifies AKS health, tags, ACR, peering
- **Post-destroy validation** — Confirms RG deleted, checks for orphaned resources
- **Right-sized SKUs** — B2s nodes, 30GB OS disk, Basic ACR — documented cost justification

## Pipeline Flow

### Deploy Pipeline (`azure-pipelines.yml`)
```
Bootstrap ──► Plan ──► Apply (approval gate) ──► Validate (PowerShell)
   │             │          │                          │
   │             │          │                          ├─ AKS health check
   │             │          │                          ├─ Tag compliance
   │             │          │                          ├─ ACR verification
   │             │          │                          └─ Peering status
   │             │          │
   │             │          └─ Applies exact plan artifact
   │             └─ Publishes plan as pipeline artifact
   └─ Creates backend storage (idempotent)
```

### Destroy Pipeline (`azure-pipelines-destroy.yml`)
```
Destroy (approval gate) ──► Validate Cleanup (PowerShell)
   │                               │
   │                               ├─ RG deletion confirmed
   │                               ├─ MC_* node RG gone
   │                               └─ Orphaned disk check
   │
   └─ terraform destroy -auto-approve
```

## Feature Flags

| Flag | Default | Effect |
|------|---------|--------|
| `enable_acr` | `true` | Provisions/skips Azure Container Registry |
| `enable_peering` | `true` | Creates/skips hub-spoke VNet peering |
| `aks_node_count` | `1` | Scales AKS default node pool (1-5) |

```hcl
# Disable ACR to save ~₹15/day
enable_acr = false

# Test isolated spoke (no hub connectivity)
enable_peering = false
```

## Cost

| Resource | Hourly (INR) |
|----------|-------------|
| AKS Control Plane | ₹0 (free) |
| 1x B2s Node | ~₹3.50 |
| ACR Basic | ~₹0.58 |
| VNet / NSG / Peering | ₹0 |
| **Total** | **~₹4.25/hr** |

Full cost analysis with SKU justification: [COST.md](COST.md)

## Prerequisites

1. Azure Pay-As-You-Go subscription
2. ADO project `Atlas-Platform` with service connection `MI-ADO-API`
3. Variable group `atlas-01-vars` with backend config values
4. ADO environments: `atlas-01-deploy`, `atlas-01-destroy`

## Deploy

1. Push code to ADO repo
2. Create pipeline from `azure-pipelines.yml`
3. Run pipeline → approve at Apply stage
4. Validate stage runs automatically

## Cleanup

Run the destroy pipeline (`azure-pipelines-destroy.yml`), or manual fallback:

```bash
az group delete --name rg-atlas-01-dev --yes --no-wait
```

Verify: Azure Portal → Resource Groups → search "atlas-01" → should return empty.

## Troubleshooting

Common issues and fixes: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

Covers: state lock recovery, subnet conflicts, peering disconnects, pipeline auth failures.

## Skills Demonstrated

- **Terraform** — modules, remote state, feature flags, validation blocks, conditional resources
- **Azure Networking** — hub-spoke topology, VNet peering, NSGs, subnet sizing for CNI
- **AKS** — managed identity, Azure CNI, Calico network policy, node pool configuration
- **Azure DevOps** — multi-stage pipelines, plan artifacts, approval gates, mixed task types
- **FinOps** — cost tagging, right-sizing, SKU justification, ephemeral infrastructure
- **DevSecOps** — gitleaks pre-commit, OIDC (no stored credentials), ACR admin disabled
- **PowerShell** — post-deploy/destroy validation with structured checks
- **Bash** — Terraform CLI operations, backend bootstrap

## What I Learned

- Hub-spoke is overkill for a single workload but demonstrates enterprise architecture thinking
- Azure CNI consumes more IPs than expected — subnet sizing matters from Day 1
- Terraform plan artifacts ensure what you review is exactly what gets applied
- PowerShell validation catches issues Terraform can't — like peering state or tag compliance
- Feature flags in Terraform reduce the need for separate environment directories

---

**Author:** Manoj Kumar R (Monarch)
**Part of:** Atlas Platform — 11-project Azure cloud portfolio
**Target Role:** Senior DevOps / Platform Engineer — Netherlands | Finland | Sweden | Ireland