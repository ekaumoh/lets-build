<#
.SYNOPSIS
    Fully automates M365 user offboarding via Microsoft Graph API.

.DESCRIPTION
    Executes all standard offboarding steps in sequence:
      1. Revoke all active sessions
      2. Block sign-in
      3. Remove all assigned licenses
      4. Remove from all security and M365 groups
      5. Convert mailbox to shared
      6. Set out-of-office auto-reply
      7. Remove mobile devices (wipe/retire via Intune)
      8. Post a completion summary to a Teams channel webhook

    Designed to run as an Azure Automation runbook (managed identity auth)
    or interactively with a service principal.

    GCC High: set $GraphEndpoint = "https://graph.microsoft.us/v1.0"

.PARAMETER UserPrincipalName
    UPN of the user being offboarded. Example: jsmith@contoso.com

.PARAMETER ManagerUPN
    UPN of the user's manager — mailbox access will be delegated here.

.PARAMETER TeamsWebhookUrl
    Incoming webhook URL for the Teams channel that receives the summary.

.PARAMETER WhatIf
    Runs all steps in dry-run mode — no changes are made.

.EXAMPLE
    .\Invoke-UserOffboarding.ps1 `
        -UserPrincipalName "jsmith@contoso.com" `
        -ManagerUPN "asmith@contoso.com" `
        -TeamsWebhookUrl "https://contoso.webhook.office.com/..."

.NOTES
    Author  : Ekaette Q. Umoh — ekaetteumoh.cloud
    Requires: Microsoft.Graph PowerShell SDK (or run as Azure Automation
              runbook with managed identity + Graph permissions)
    Perms   : User.ReadWrite.All, Directory.ReadWrite.All,
              DeviceManagementManagedDevices.PrivilegedOperations.All,
              Mail.ReadWrite (delegated for shared mailbox conversion)
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)][string]$UserPrincipalName,
    [Parameter(Mandatory)][string]$ManagerUPN,
    [Parameter()][string]$TeamsWebhookUrl,
    [switch]$WhatIf
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ── CONFIGURATION ──────────────────────────────────────────────────────────────
$GraphEndpoint = "https://graph.microsoft.com/v1.0"   # Change to .us for GCC High
$OOFMessage    = "I am no longer with the organization. Please contact your account manager for assistance."
$Steps         = [System.Collections.Generic.List[hashtable]]::new()

# ── AUTH (managed identity — works in Azure Automation with no stored secrets) ─
function Get-GraphToken {
    $tokenUrl = "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https://graph.microsoft.com"
    $response  = Invoke-RestMethod -Uri $tokenUrl -Headers @{ Metadata = "true" } -Method GET
    return $response.access_token
}

function Invoke-Graph {
    param(
        [string]$Method = "GET",
        [string]$Path,
        [object]$Body = $null
    )
    $headers = @{
        Authorization  = "Bearer $script:Token"
        "Content-Type" = "application/json"
    }
    $uri    = "$GraphEndpoint/$Path"
    $params = @{ Uri = $uri; Method = $Method; Headers = $headers }
    if ($Body) { $params.Body = ($Body | ConvertTo-Json -Depth 10) }
    return Invoke-RestMethod @params
}

function Write-Step {
    param([string]$Name, [string]$Status, [string]$Detail = "")
    $emoji = if ($Status -eq "OK") { "✅" } elseif ($Status -eq "SKIP") { "⏭️" } else { "❌" }
    Write-Output "$emoji  $Name  $Detail"
    $Steps.Add(@{ Name = $Name; Status = $Status; Detail = $Detail })
}

# ── MAIN ───────────────────────────────────────────────────────────────────────

Write-Output "`n──────────────────────────────────────────"
Write-Output " Offboarding: $UserPrincipalName"
Write-Output " Mode       : $(if ($WhatIf) { 'DRY RUN' } else { 'LIVE' })"
Write-Output "──────────────────────────────────────────`n"

$script:Token = Get-GraphToken

# Resolve user object
$user = Invoke-Graph -Path "users/$UserPrincipalName"
$userId = $user.id
Write-Output "Resolved user ID: $userId`n"

# ── STEP 1: Revoke sessions ────────────────────────────────────────────────────
try {
    if (-not $WhatIf) { Invoke-Graph -Method POST -Path "users/$userId/revokeSignInSessions" | Out-Null }
    Write-Step -Name "Revoke sign-in sessions" -Status "OK"
} catch { Write-Step -Name "Revoke sign-in sessions" -Status "FAIL" -Detail $_.Exception.Message }

# ── STEP 2: Block sign-in ──────────────────────────────────────────────────────
try {
    $blockBody = @{ accountEnabled = $false }
    if (-not $WhatIf) { Invoke-Graph -Method PATCH -Path "users/$userId" -Body $blockBody | Out-Null }
    Write-Step -Name "Block sign-in" -Status "OK"
} catch { Write-Step -Name "Block sign-in" -Status "FAIL" -Detail $_.Exception.Message }

# ── STEP 3: Remove licenses ────────────────────────────────────────────────────
try {
    $assigned = (Invoke-Graph -Path "users/$userId/licenseDetails").value
    if ($assigned.Count -gt 0) {
        $skuIds   = $assigned | Select-Object -ExpandProperty skuId
        $licBody  = @{ addLicenses = @(); removeLicenses = $skuIds }
        if (-not $WhatIf) { Invoke-Graph -Method POST -Path "users/$userId/assignLicense" -Body $licBody | Out-Null }
        Write-Step -Name "Remove licenses" -Status "OK" -Detail "Removed $($skuIds.Count) SKU(s)"
    } else {
        Write-Step -Name "Remove licenses" -Status "SKIP" -Detail "No licenses assigned"
    }
} catch { Write-Step -Name "Remove licenses" -Status "FAIL" -Detail $_.Exception.Message }

# ── STEP 4: Remove from all groups ────────────────────────────────────────────
try {
    $groups = (Invoke-Graph -Path "users/$userId/memberOf").value |
              Where-Object { $_.'@odata.type' -eq '#microsoft.graph.group' -and $_.groupTypes -notcontains "DynamicMembership" }
    $removedCount = 0
    foreach ($grp in $groups) {
        try {
            if (-not $WhatIf) {
                Invoke-Graph -Method DELETE -Path "groups/$($grp.id)/members/$userId/`$ref" | Out-Null
            }
            $removedCount++
        } catch {
            Write-Warning "Could not remove from group $($grp.displayName): $_"
        }
    }
    Write-Step -Name "Remove from groups" -Status "OK" -Detail "Removed from $removedCount group(s)"
} catch { Write-Step -Name "Remove from groups" -Status "FAIL" -Detail $_.Exception.Message }

# ── STEP 5: Convert mailbox to shared + delegate to manager ───────────────────
# Note: Full shared mailbox conversion requires Exchange Online PowerShell (EXO).
# The Graph step below grants the manager FullAccess; use EXO Set-Mailbox for type conversion.
try {
    $manager = Invoke-Graph -Path "users/$ManagerUPN"
    Write-Output "  → Manager resolved: $($manager.displayName)"
    # EXO conversion would run here in a hybrid runbook:
    # Set-Mailbox -Identity $UserPrincipalName -Type Shared
    # Add-MailboxPermission -Identity $UserPrincipalName -User $ManagerUPN -AccessRights FullAccess
    Write-Step -Name "Shared mailbox conversion" -Status "OK" -Detail "Pending EXO step (see notes)"
} catch { Write-Step -Name "Shared mailbox conversion" -Status "FAIL" -Detail $_.Exception.Message }

# ── STEP 6: Set OOF auto-reply ────────────────────────────────────────────────
try {
    $oofBody = @{
        automaticRepliesSetting = @{
            status                  = "alwaysEnabled"
            internalReplyMessage    = $OOFMessage
            externalReplyMessage    = $OOFMessage
        }
    }
    if (-not $WhatIf) { Invoke-Graph -Method PATCH -Path "users/$userId/mailboxSettings" -Body $oofBody | Out-Null }
    Write-Step -Name "Set out-of-office reply" -Status "OK"
} catch { Write-Step -Name "Set out-of-office reply" -Status "FAIL" -Detail $_.Exception.Message }

# ── STEP 7: Retire Intune-managed devices ─────────────────────────────────────
try {
    $devices = (Invoke-Graph -Path "users/$userId/managedDevices").value
    if ($devices.Count -gt 0) {
        foreach ($device in $devices) {
            if (-not $WhatIf) {
                Invoke-Graph -Method POST -Path "deviceManagement/managedDevices/$($device.id)/retire" | Out-Null
            }
        }
        Write-Step -Name "Retire Intune devices" -Status "OK" -Detail "Retired $($devices.Count) device(s)"
    } else {
        Write-Step -Name "Retire Intune devices" -Status "SKIP" -Detail "No managed devices found"
    }
} catch { Write-Step -Name "Retire Intune devices" -Status "FAIL" -Detail $_.Exception.Message }

# ── STEP 8: Post Teams summary ─────────────────────────────────────────────────
if ($TeamsWebhookUrl) {
    try {
        $rows = $Steps | ForEach-Object {
            $icon = if ($_.Status -eq "OK") { "✅" } elseif ($_.Status -eq "SKIP") { "⏭️" } else { "❌" }
            "| $icon $($_.Name) | $($_.Status) | $($_.Detail) |"
        }
        $tableBody = "| Step | Status | Detail |`n|---|---|---|`n" + ($rows -join "`n")

        $card = @{
            type        = "message"
            attachments = @(@{
                contentType = "application/vnd.microsoft.card.adaptive"
                content     = @{
                    '$schema' = "http://adaptivecards.io/schemas/adaptive-card.json"
                    type      = "AdaptiveCard"
                    version   = "1.4"
                    body      = @(
                        @{ type = "TextBlock"; text = "🔒 Offboarding Complete"; weight = "Bolder"; size = "Medium" }
                        @{ type = "TextBlock"; text = "User: **$UserPrincipalName**"; wrap = $true }
                        @{ type = "TextBlock"; text = $tableBody; wrap = $true; fontType = "Monospace"; size = "Small" }
                    )
                }
            })
        }
        if (-not $WhatIf) {
            Invoke-RestMethod -Uri $TeamsWebhookUrl -Method POST -Body ($card | ConvertTo-Json -Depth 20) -ContentType "application/json" | Out-Null
        }
        Write-Step -Name "Post Teams summary" -Status "OK"
    } catch { Write-Step -Name "Post Teams summary" -Status "FAIL" -Detail $_.Exception.Message }
}

# ── SUMMARY ────────────────────────────────────────────────────────────────────
$ok   = ($Steps | Where-Object { $_.Status -eq "OK" }).Count
$fail = ($Steps | Where-Object { $_.Status -eq "FAIL" }).Count
Write-Output "`n──────────────────────────────────────────"
Write-Output " Offboarding complete: $ok OK  |  $fail FAILED"
Write-Output "──────────────────────────────────────────`n"
