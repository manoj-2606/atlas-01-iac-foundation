# Troubleshooting — atlas-01-iac-foundation

## Terraform State Issues

### "Error acquiring the state lock"
**Cause:** A previous `terraform apply` or `destroy` crashed mid-operation. The lease on the state blob was not released.

**Fix:**
```bash
# Check who holds the lock
az storage blob show \
  --account-name atlastfstate2606 \
  --container-name tfstate \
  --name atlas-01.tfstate \
  --query "properties.lease.status"

# If status is "locked" — break the lease
az storage blob lease break \
  --account-name atlastfstate2606 \
  --container-name tfstate \
  --blob-name atlas-01.tfstate
```

**Prevention:** Never cancel a Terraform run mid-operation. Let it fail or complete.

---

### "Backend configuration changed"
**Cause:** You ran `terraform init` with different backend-config values than last time.

**Fix:**
```bash
terraform init \
  -backend-config="resource_group_name=rg-atlas-tfstate" \
  -backend-config="storage_account_name=atlastfstate2606" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=atlas-01.tfstate" \
  -reconfigure
```

The `-reconfigure` flag tells Terraform: "I know the backend changed. Use the new config."

---

### "State file not found" / Empty state
**Cause:** Backend storage exists but the state file key doesn't match, or was deleted.

**Fix:**
```bash
# List all state files
az storage blob list \
  --account-name atlastfstate2606 \
  --container-name tfstate \
  --output table

# Check if atlas-01.tfstate exists
# If missing: state was never written (first run) or was deleted
# Re-run terraform plan + apply to recreate
```

---

## AKS Issues

### "The subnet is already in use by another resource"
**Cause:** A previous AKS cluster wasn't fully deleted and still holds the subnet.

**Fix:**
```bash
# Check what's using the subnet
az network vnet subnet show \
  --resource-group rg-atlas-01-dev \
  --vnet-name vnet-spoke-atlas-01-dev \
  --name snet-aks-atlas-01-dev \
  --query "ipConfigurations[].id"

# Force delete the resource group (nuclear option)
az group delete --name rg-atlas-01-dev --yes --no-wait
# Wait 5-10 minutes, then re-run pipeline
```

---

### "InsufficientSubnetSize"
**Cause:** Subnet CIDR is too small for the requested node count × pods per node.

**Math:**
- Azure CNI reserves 5 IPs per subnet (Azure internal)
- Each node needs: 1 (node IP) + max_pods (default 30) = 31 IPs
- /24 = 256 - 5 = 251 usable → supports ~8 nodes
- /27 = 32 - 5 = 27 usable → supports 0 nodes (27 < 31)

**Fix:** Use at minimum /24 for AKS subnets. Our config uses /24 = safe for up to 8 nodes.

---

## Pipeline Issues

### "Error: No subscription found"
**Cause:** OIDC token exchange failed. Service connection misconfigured.

**Fix:**
1. ADO → Project Settings → Service Connections → MI-ADO-API
2. Verify: Subscription ID, Tenant ID, App Registration Client ID
3. Check: Federated credential audience matches ADO organization

---

### Plan artifact not found in Apply stage
**Cause:** Plan stage failed or artifact wasn't published.

**Fix:**
1. Check Plan stage logs — did it complete?
2. Check artifact: Pipelines → Runs → (your run) → Artifacts tab
3. If missing: re-run from Plan stage

---

## Peering Issues

### Peering state = "Disconnected"
**Cause:** One side of the peering was deleted but not the other. Peering must be bidirectional.

**Fix:**
```bash
# Delete both peerings
az network vnet peering delete \
  --resource-group rg-atlas-01-dev \
  --vnet-name vnet-hub-atlas-01-dev \
  --name peer-hub-to-spoke

az network vnet peering delete \
  --resource-group rg-atlas-01-dev \
  --vnet-name vnet-spoke-atlas-01-dev \
  --name peer-spoke-to-hub

# Re-run terraform apply — it will recreate both
```

---

## Interview Story

> "When our Terraform state got locked after a pipeline timeout, I broke the blob
> lease and documented the recovery process. I now include state recovery steps
> in every project's troubleshooting guide."