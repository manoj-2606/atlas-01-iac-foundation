# =============================================================================
# Validate-Cleanup.ps1 — Post-Destroy Verification
# =============================================================================
# Runs after terraform destroy via AzurePowerShell@5 task.
# Confirms all resources are actually gone — not just "destroy completed".
#
# Why verify after destroy?
# - terraform destroy can succeed but leave orphaned resources
#   (disks, public IPs, managed identity remnants)
# - Resource group might still be "Deleting" (async operation)
# - FinOps: an unverified destroy = potential overnight charges
#
# Interview: "I verify cleanup with a post-destroy script. Terraform
# says 'destroyed' but Azure might still be processing. I confirm
# the resource group is truly gone before closing the ticket."
# =============================================================================

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory = $false)]
    [int]$MaxWaitSeconds = 120
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=" * 60
Write-Host "  ATLAS-01 POST-DESTROY VALIDATION"
Write-Host "=" * 60
Write-Host ""

# =============================================================================
# CHECK 1: Resource Group Deletion
# =============================================================================
Write-Host "[1/3] Waiting for Resource Group deletion..." -ForegroundColor Cyan

$elapsed = 0
$interval = 15

while ($elapsed -lt $MaxWaitSeconds) {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue

    if ($null -eq $rg) {
        Write-Host "  [PASS] Resource group '$ResourceGroupName' is deleted." -ForegroundColor Green
        break
    }

    $state = $rg.ProvisioningState
    Write-Host "  [WAIT] RG state: $state — checking again in ${interval}s ($elapsed/${MaxWaitSeconds}s)" -ForegroundColor Yellow
    Start-Sleep -Seconds $interval
    $elapsed += $interval
}

if ($elapsed -ge $MaxWaitSeconds) {
    $rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if ($null -ne $rg) {
        Write-Host "  [FAIL] Resource group still exists after ${MaxWaitSeconds}s." -ForegroundColor Red
        Write-Host "  [INFO] State: $($rg.ProvisioningState)" -ForegroundColor Yellow
        Write-Host "  [INFO] Manual cleanup may be needed." -ForegroundColor Yellow
    }
}

# =============================================================================
# CHECK 2: Orphaned Resources
# =============================================================================
Write-Host ""
Write-Host "[2/3] Checking for orphaned resources..." -ForegroundColor Cyan

# AKS creates a secondary resource group (MC_*) for node resources.
# terraform destroy deletes AKS, which triggers deletion of MC_* group.
# But it's async — might still exist briefly.
$mcRgName = "MC_${ResourceGroupName}_aks-atlas-01-dev_centralindia"
$mcRg = Get-AzResourceGroup -Name $mcRgName -ErrorAction SilentlyContinue

if ($null -eq $mcRg) {
    Write-Host "  [PASS] AKS node resource group (MC_*) is deleted." -ForegroundColor Green
} else {
    Write-Host "  [WARN] MC_* group still exists: $mcRgName" -ForegroundColor Yellow
    Write-Host "  [INFO] This usually auto-deletes within 5-10 minutes." -ForegroundColor Yellow
}

# Check for orphaned disks (common leftover)
$orphanedDisks = Get-AzDisk | Where-Object {
    $_.Tags.project -eq "atlas-01" -and $_.ManagedBy -eq $null
}

if ($orphanedDisks.Count -eq 0) {
    Write-Host "  [PASS] No orphaned disks found with project=atlas-01 tag." -ForegroundColor Green
} else {
    Write-Host "  [WARN] Found $($orphanedDisks.Count) orphaned disk(s):" -ForegroundColor Yellow
    $orphanedDisks | ForEach-Object { Write-Host "    - $($_.Name) ($($_.DiskSizeGB)GB)" }
}

# =============================================================================
# CHECK 3: Cost Summary
# =============================================================================
Write-Host ""
Write-Host "[3/3] Cleanup Summary" -ForegroundColor Cyan
Write-Host "  [INFO] Resources destroyed. Verify in Azure Portal:" -ForegroundColor Yellow
Write-Host "    Portal → Resource Groups → search 'atlas-01'"
Write-Host "    Expected: No results."
Write-Host ""
Write-Host "  [INFO] Backend state storage (rg-atlas-tfstate) is NOT deleted here." -ForegroundColor Yellow
Write-Host "    It's shared across projects. Delete manually only when all projects are done."

Write-Host ""
Write-Host "=" * 60
Write-Host "  CLEANUP VALIDATION COMPLETE"
Write-Host "=" * 60
Write-Host ""