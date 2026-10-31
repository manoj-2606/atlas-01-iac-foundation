# =============================================================================
# Validate-Deployment.ps1 — Post-Apply Verification
# =============================================================================
# Runs after terraform apply via AzurePowerShell@5 task in the pipeline.
# Verifies that infrastructure is actually healthy — not just "applied".
#
# Why PowerShell and not Bash?
# - Real companies use both. Mixed tooling = real-world experience.
# - Az PowerShell module returns structured objects (not JSON strings).
# - Easier to assert on object properties than parsing JSON with jq.
# - Interview: "I validate deployments with PowerShell scripts that check
#   resource health, tag compliance, and connectivity — not just terraform output."
#
# Usage: Called by pipeline with parameters from Terraform outputs.
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $true)]
    [string]$AksClusterName,

    [Parameter(Mandatory = $false)]
    [string]$AcrName = "",

    [Parameter(Mandatory = $false)]
    [string]$PeeringEnabled = $true,

    [Parameter(Mandatory = $false)]
    [int]$ExpectedNodeCount = 1
)

# --- Configuration ---
$ErrorActionPreference = "Stop"
$passCount = 0
$failCount = 0
$totalChecks = 0
$PeeringEnabledBool = $PeeringEnabled -eq "true"

function Test-Check {
    param([string]$Name, [scriptblock]$Check)
    $script:totalChecks++
    try {
        $result = & $Check
        if ($result) {
            Write-Host "  [PASS] $Name" -ForegroundColor Green
            $script:passCount++
        } else {
            Write-Host "  [FAIL] $Name" -ForegroundColor Red
            $script:failCount++
        }
    } catch {
        Write-Host "  [FAIL] $Name — $_" -ForegroundColor Red
        $script:failCount++
    }
}

Write-Host ""
Write-Host ("=" * 60)
Write-Host "  ATLAS-01 POST-DEPLOYMENT VALIDATION"
Write-Host ("=" * 60)
Write-Host ""

# =============================================================================
# CHECK 1: Resource Group Exists
# =============================================================================
Write-Host "[1/7] Resource Group" -ForegroundColor Cyan
Test-Check "Resource group '$ResourceGroupName' exists" {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    return $null -ne $rg
}

# =============================================================================
# CHECK 2: Cost Tags Present on Resource Group
# =============================================================================
Write-Host "[2/7] FinOps Tags" -ForegroundColor Cyan
$rg = Get-AzResourceGroup -Name $ResourceGroupName
$requiredTags = @("project", "environment", "team", "cost-center", "created-by", "managed-by")

foreach ($tag in $requiredTags) {
    Test-Check "Tag '$tag' exists on RG" {
        return $rg.Tags.ContainsKey($tag)
    }
}

# =============================================================================
# CHECK 3: AKS Cluster Running
# =============================================================================
Write-Host "[3/7] AKS Cluster Health" -ForegroundColor Cyan
$aks = Get-AzAksCluster -ResourceGroupName $ResourceGroupName -Name $AksClusterName

Test-Check "AKS cluster provisioning state = 'Succeeded'" {
    return $aks.ProvisioningState -eq "Succeeded"
}

Test-Check "AKS power state = 'Running'" {
    return $aks.PowerState.Code -eq "Running"
}

Test-Check "AKS uses SystemAssigned identity" {
    return $aks.Identity.Type -eq "SystemAssigned"
}

Test-Check "AKS network plugin = 'azure' (CNI)" {
    return $aks.NetworkProfile.NetworkPlugin -eq "azure"
}

Test-Check "AKS network policy = 'calico'" {
    return $aks.NetworkProfile.NetworkPolicy -eq "calico"
}

# =============================================================================
# CHECK 4: Node Pool Health
# =============================================================================
Write-Host "[4/7] Node Pool" -ForegroundColor Cyan
$nodePool = $aks.AgentPoolProfiles | Where-Object { $_.Name -eq "system" }

Test-Check "System node pool exists" {
    return $null -ne $nodePool
}

Test-Check "Node count = $ExpectedNodeCount" {
    return $nodePool.Count -eq $ExpectedNodeCount
}

Test-Check "Node VM size = 'Standard_B2s'" {
    return $nodePool.VmSize -eq "Standard_B2s"
}

# =============================================================================
# CHECK 5: ACR (if enabled)
# =============================================================================
Write-Host "[5/7] Container Registry" -ForegroundColor Cyan
if ($AcrName -ne "") {
    $acr = Get-AzContainerRegistry -ResourceGroupName $ResourceGroupName -Name $AcrName -ErrorAction SilentlyContinue

    Test-Check "ACR '$AcrName' exists" {
        return $null -ne $acr
    }

    Test-Check "ACR admin disabled (RBAC-only auth)" {
        return $acr.AdminUserEnabled -eq $false
    }

    Test-Check "ACR SKU = 'Basic'" {
        return $acr.SkuName -eq "Basic"
    }
} else {
    Write-Host "  [SKIP] ACR disabled via feature flag" -ForegroundColor Yellow
}

# =============================================================================
# CHECK 6: VNet Peering (if enabled)
# =============================================================================
Write-Host "[6/7] Hub-Spoke Peering" -ForegroundColor Cyan
if ($PeeringEnabled) {
    $vnets = Get-AzVirtualNetwork -ResourceGroupName $ResourceGroupName
    $hubVnet = $vnets | Where-Object { $_.Name -like "*hub*" }

    Test-Check "Hub VNet exists" {
        return $null -ne $hubVnet
    }

    if ($hubVnet) {
        $peerings = Get-AzVirtualNetworkPeering -ResourceGroupName $ResourceGroupName `
                        -VirtualNetworkName $hubVnet.Name -ErrorAction SilentlyContinue

        Test-Check "Hub→Spoke peering state = 'Connected'" {
            $peer = $peerings | Where-Object { $_.Name -eq "peer-hub-to-spoke" }
            return $peer.PeeringState -eq "Connected"
        }
    }
} else {
    Write-Host "  [SKIP] Peering disabled via feature flag" -ForegroundColor Yellow
}

# =============================================================================
# CHECK 7: Cost Estimate
# =============================================================================
Write-Host "[7/7] Cost Estimate" -ForegroundColor Cyan
Write-Host "  [INFO] Estimated hourly cost:" -ForegroundColor Yellow
Write-Host "    AKS control plane:  FREE"
Write-Host "    1x B2s node:        ~`$0.04/hr (~₹3.3/hr)"
Write-Host "    ACR Basic:          ~`$0.007/hr (~₹0.6/hr)"
Write-Host "    VNet/NSG/Peering:   FREE"
Write-Host "    Total:              ~`$0.05/hr (~₹4/hr)"
Write-Host ""
Write-Host "    DESTROY AFTER USE to avoid unnecessary cost." -ForegroundColor Yellow

# =============================================================================
# SUMMARY
# =============================================================================
Write-Host ""
Write-Host ("=" * 60)
if ($failCount -eq 0) {
    Write-Host "  RESULT: ALL $totalChecks CHECKS PASSED" -ForegroundColor Green
} else {
    Write-Host "  RESULT: $failCount/$totalChecks CHECKS FAILED" -ForegroundColor Red
}
Write-Host "  Passed: $passCount | Failed: $failCount | Total: $totalChecks"
Write-Host ("=" * 60)
Write-Host ""

# Exit with failure if any check failed — pipeline stage will fail
if ($failCount -gt 0) {
    Write-Error "Deployment validation failed. $failCount check(s) did not pass."
    exit 1
}