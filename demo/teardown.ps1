<#
.SYNOPSIS
    Removes the cross-project intake demo from an Azure DevOps org.

.DESCRIPTION
    Deletes the central project, the contributing team projects, and the
    inherited process created by provision.ps1. Requires -Confirm.

.EXAMPLE
    pwsh ./demo/teardown.ps1 -Confirm
#>
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [string]$Organization = 'https://dev.azure.com/gappiahdemo-msft/',
    [string]$CentralProject = 'P',
    [string[]]$TeamProjects = @('Team-Apollo', 'Team-Borealis'),
    [string]$ProcessName = 'Agile'
)

$ErrorActionPreference = 'Stop'

function Remove-Project([string]$name) {
    $id = az devops project list --organization $Organization --query "value[?name=='$name'].id" -o tsv
    if (-not $id) { Write-Host "  [skip] '$name' not found"; return }
    if ($PSCmdlet.ShouldProcess($name, 'Delete ADO project')) {
        Write-Host "  Deleting project '$name' ($id) ..."
        az devops project delete --id $id --yes --organization $Organization | Out-Null
        Write-Host "  [ok]   deleted '$name'"
    }
}

Write-Host "Tearing down demo in $Organization" -ForegroundColor Yellow
Remove-Project $CentralProject
foreach ($t in $TeamProjects) { Remove-Project $t }

# Built-in 'Agile' process is not deleted; only delete inherited processes.
if ($ProcessName -ne 'Agile' -and $ProcessName -ne 'Scrum' -and $ProcessName -ne 'CMMI' -and $ProcessName -ne 'Basic') {
    $orgHost = $Organization.TrimEnd('/')
    $procId = (az rest --method GET --uri "$orgHost/_apis/work/processes?api-version=7.1" --resource '499b84ac-1321-427f-aa17-267ca6975798' -o json 2>$null | ConvertFrom-Json).value | Where-Object name -eq $ProcessName | Select-Object -ExpandProperty typeId
    if ($procId -and $PSCmdlet.ShouldProcess($ProcessName, 'Delete inherited process')) {
        Write-Host "  Deleting inherited process '$ProcessName' ($procId) ..."
        az rest --method DELETE --uri "$orgHost/_apis/work/processes/$procId?api-version=7.1" --resource '499b84ac-1321-427f-aa17-267ca6975798' -o none 2>&1 | Out-Null
        Write-Host "  [ok]   deleted process '$ProcessName'"
    }
}

Write-Host "Done." -ForegroundColor Green
