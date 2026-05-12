<#
.SYNOPSIS
    Idempotently provisions the cross-project intake demo in an Azure DevOps org.

.DESCRIPTION
    Creates 3 projects (central "P" + two contributing teams), customizes the
    inherited process, seeds area paths / iterations / saved queries, and
    creates sample work items linked across projects with "Remote Related" links
    that demonstrate the recommended pattern from the guide.

    Safe to re-run: every step checks for existence before creating.

    Counterpart: teardown.ps1

.PARAMETER Organization
    ADO org URL. Default: https://dev.azure.com/gappiahdemo-msft/

.PARAMETER CentralProject
    Central PMO-style intake project name. Default: P

.PARAMETER TeamProjects
    Names of contributing team projects. Default: Team-Apollo, Team-Borealis

.PARAMETER ProcessName
    Name of the inherited process to create from "Agile". Default: P-Intake

.EXAMPLE
    pwsh ./demo/provision.ps1
#>
[CmdletBinding()]
param(
    [string]$Organization = 'https://dev.azure.com/gappiahdemo-msft/',
    [string]$CentralProject = 'P',
    [string[]]$TeamProjects = @('Team-Apollo', 'Team-Borealis'),
    [string]$ProcessName = 'Agile'
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Write-Skip($msg) { Write-Host "    [skip] $msg" -ForegroundColor DarkGray }
function Write-Done($msg) { Write-Host "    [ok]   $msg" -ForegroundColor Green }

function Invoke-Az {
    param([Parameter(ValueFromRemainingArguments)] [string[]]$Args)
    $out = & az @Args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "az $($Args -join ' ') failed: $out"
    }
    return $out
}

function Get-ProjectId([string]$name) {
    $json = az devops project list --organization $Organization --query "value[?name=='$name'].id" -o tsv 2>$null
    if ($LASTEXITCODE -ne 0) { return $null }
    return ($json | Select-Object -First 1)
}

function Ensure-Project([string]$name) {
    $id = Get-ProjectId $name
    if ($id) { Write-Skip "project '$name' exists ($id)"; return $id }
    Write-Step "Creating project '$name' (process=$ProcessName)"
    Invoke-Az devops project create --name $name --process $ProcessName --source-control git --visibility private --organization $Organization | Out-Null
    Start-Sleep -Seconds 4
    $id = Get-ProjectId $name
    Write-Done "project '$name' = $id"
    return $id
}

function Ensure-Process {
    # Verify the requested process exists in the org (built-in or inherited).
    $orgHost = $Organization.TrimEnd('/')
    $resourceId = '499b84ac-1321-427f-aa17-267ca6975798'
    $listJson = az rest --method GET --uri "$orgHost/_apis/work/processes?api-version=7.1" --resource $resourceId -o json 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $listJson) {
        throw "Could not list processes in $Organization. Are you signed in (az login) with a tenant that has access?"
    }
    $found = ($listJson | ConvertFrom-Json).value | Where-Object { $_.name -eq $ProcessName } | Select-Object -First 1
    if (-not $found) {
        $available = ((($listJson | ConvertFrom-Json).value) | ForEach-Object { $_.name }) -join ', '
        throw "Process '$ProcessName' not found in org. Available: $available"
    }
    Write-Done "process '$ProcessName' = $($found.typeId)"
    return $found.typeId
}

function Ensure-AreaPath([string]$project, [string]$path) {
    # path like "Intake" or "Programs/Apollo"; uses REST classificationnodes API
    $orgHost = $Organization.TrimEnd('/')
    $resourceId = '499b84ac-1321-427f-aa17-267ca6975798'
    $segments = $path -split '/'
    $parent = ''
    foreach ($seg in $segments) {
        $fullPath = if ($parent) { "$parent\$seg" } else { $seg }
        $parentEsc = if ($parent) { ($parent -replace '\\','/') } else { '' }
        $uri = if ($parent) {
            "$orgHost/$project/_apis/wit/classificationnodes/areas/$([uri]::EscapeUriString($parentEsc))?api-version=7.1"
        } else {
            "$orgHost/$project/_apis/wit/classificationnodes/areas?api-version=7.1"
        }
        $body = @{ name = $seg } | ConvertTo-Json -Compress
        $tmp = New-TemporaryFile; Set-Content -Path $tmp -Value $body -Encoding utf8
        try {
            $res = & az rest --method POST --uri $uri --headers "Content-Type=application/json" --body "@$tmp" --resource $resourceId -o json 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Done "area '$project\$fullPath'"
            } elseif ($res -match 'already exists|VS402371|TF400898|TF26212') {
                Write-Skip "area '$project\$fullPath'"
            } else {
                throw "Failed to create area '$project\$fullPath': $res"
            }
        } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
        $parent = $fullPath
    }
}

function Ensure-Iteration([string]$project, [string]$name, [string]$start, [string]$finish) {
    $args = @('boards','iteration','project','create','--name',$name,'--project',$project,'--organization',$Organization,'--start-date',$start,'--finish-date',$finish)
    $res = & az @args 2>&1
    if ($LASTEXITCODE -ne 0 -and $res -notmatch 'already exists|TF401075|VS402371') {
        throw "Failed to create iteration '$name' in '$project': $res"
    }
    if ($LASTEXITCODE -eq 0) {
        # also add to team
        & az boards iteration team add --id (az boards iteration project list --project $project --organization $Organization --depth 1 -o json | ConvertFrom-Json | ForEach-Object { $_.children } | Where-Object name -eq $name | Select-Object -ExpandProperty identifier) --team "$project Team" --project $project --organization $Organization 2>&1 | Out-Null
        Write-Done "iteration '$project / $name'"
    } else { Write-Skip "iteration '$project / $name'" }
}

function New-WorkItem([string]$project, [string]$type, [string]$title, [hashtable]$fields = @{}) {
    $args = @('boards','work-item','create','--title',$title,'--type',$type,'--project',$project,'--organization',$Organization,'-o','json')
    foreach ($k in $fields.Keys) { $args += @('--fields', "$k=$($fields[$k])") }
    $res = & az @args 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Failed to create $type '$title' in $project : $res" }
    return ($res | ConvertFrom-Json)
}

function Add-RemoteRelatedLink([int]$fromId, [string]$fromProject, [int]$toId, [string]$toProject) {
    # Within a single org, cross-project Related links use System.LinkTypes.Related
    $orgHost = $Organization.TrimEnd('/')
    $resourceId = '499b84ac-1321-427f-aa17-267ca6975798'
    $uri = "$orgHost/$fromProject/_apis/wit/workItems/$fromId" + '?api-version=7.1'
    $targetUrl = "$orgHost/$toProject/_apis/wit/workItems/$toId"
    # JSON-Patch body must be an array
    $body = '[{"op":"add","path":"/relations/-","value":{"rel":"System.LinkTypes.Related","url":"' + $targetUrl + '","attributes":{"comment":"Cross-project intake link (demo)"}}}]'
    $tmp = New-TemporaryFile
    Set-Content -Path $tmp -Value $body -Encoding utf8 -NoNewline
    try {
        $res = & az rest --method PATCH --uri $uri --headers "Content-Type=application/json-patch+json" --body "@$tmp" --resource $resourceId -o json 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Done "linked $fromProject#$fromId -> $toProject#$toId"
        } else {
            Write-Host "    [warn] could not link $fromProject#$fromId -> $toProject#$toId : $res" -ForegroundColor Yellow
        }
    } finally { Remove-Item $tmp -ErrorAction SilentlyContinue }
}

function Ensure-Query([string]$project, [string]$folder, [string]$name, [string]$wiql) {
    $orgHost = $Organization.TrimEnd('/')
    # ensure folder under "Shared Queries"
    $folderPath = "Shared Queries/$folder"
    $body = @{ name = $folder; isFolder = $true } | ConvertTo-Json -Compress
    $tmp1 = New-TemporaryFile; Set-Content $tmp1 $body -Encoding utf8
    & az rest --method POST --uri "$orgHost/$project/_apis/wit/queries/Shared%20Queries?api-version=7.1" --headers "Content-Type=application/json" --body "@$tmp1" --resource '499b84ac-1321-427f-aa17-267ca6975798' -o none 2>&1 | Out-Null
    Remove-Item $tmp1 -ErrorAction SilentlyContinue

    $body2 = @{ name = $name; wiql = $wiql } | ConvertTo-Json -Compress
    $tmp2 = New-TemporaryFile; Set-Content $tmp2 $body2 -Encoding utf8
    $uri = "$orgHost/$project/_apis/wit/queries/$([uri]::EscapeDataString($folderPath))?api-version=7.1"
    $res = & az rest --method POST --uri $uri --headers "Content-Type=application/json" --body "@$tmp2" --resource '499b84ac-1321-427f-aa17-267ca6975798' -o json 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Done "query '$folderPath/$name'" }
    else { Write-Skip "query '$folderPath/$name' ($res)" }
    Remove-Item $tmp2 -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------------------
# Pre-flight
# ---------------------------------------------------------------------------
Write-Step "Pre-flight: az + azure-devops extension"
$ext = az extension list --query "[?name=='azure-devops'].version" -o tsv
if (-not $ext) { az extension add --name azure-devops | Out-Null }
az devops configure --defaults organization=$Organization | Out-Null
$null = Invoke-Az devops project list --organization $Organization --query "value[].name"
Write-Done "az reachable; org=$Organization"

# ---------------------------------------------------------------------------
# 1. Inherited process
# ---------------------------------------------------------------------------
Write-Step "Step 1/6: verifying process '$ProcessName' exists"
Ensure-Process | Out-Null

# ---------------------------------------------------------------------------
# 2. Projects
# ---------------------------------------------------------------------------
Write-Step "Step 2/6: projects"
$centralId = Ensure-Project $CentralProject
$teamIds = @{}
foreach ($t in $TeamProjects) { $teamIds[$t] = Ensure-Project $t }

# ---------------------------------------------------------------------------
# 3. Area paths
# ---------------------------------------------------------------------------
Write-Step "Step 3/6: area paths in '$CentralProject'"
foreach ($p in @('Intake','Triage','Programs/Apollo','Programs/Borealis')) {
    Ensure-AreaPath -project $CentralProject -path $p
}

# ---------------------------------------------------------------------------
# 4. Iterations (current sprint + 2)
# ---------------------------------------------------------------------------
Write-Step "Step 4/6: iterations in '$CentralProject'"
$today = Get-Date
$monday = $today.AddDays( - (([int]$today.DayOfWeek + 6) % 7) )
for ($i = 0; $i -lt 3; $i++) {
    $start = $monday.AddDays($i * 14)
    $end = $start.AddDays(13)
    $name = "Sprint-{0:yyyyMMdd}" -f $start
    Ensure-Iteration -project $CentralProject -name $name -start $start.ToString('yyyy-MM-dd') -finish $end.ToString('yyyy-MM-dd')
}

# ---------------------------------------------------------------------------
# 5. Seed work items
# ---------------------------------------------------------------------------
Write-Step "Step 5/6: seed work items"

# Intake stories in P
$intakeStories = @(
    @{ title='[INTAKE] Mobile app crash on cold start (iOS 17)'; team='Team-Apollo'; area="$CentralProject\Intake"; tag='intake-to-P; bug-mirror' },
    @{ title='[INTAKE] Add SSO to partner portal'; team='Team-Apollo'; area="$CentralProject\Intake"; tag='intake-to-P; security' },
    @{ title='[INTAKE] Quarterly compliance report automation'; team='Team-Borealis'; area="$CentralProject\Intake"; tag='intake-to-P; compliance' },
    @{ title='[INTAKE] Power BI workspace consolidation'; team='Team-Borealis'; area="$CentralProject\Triage"; tag='intake-to-P; data' }
)

$createdIntake = @()
foreach ($s in $intakeStories) {
    $wi = New-WorkItem -project $CentralProject -type 'User Story' -title $s.title -fields @{
        'System.AreaPath'    = $s.area
        'System.Tags'        = $s.tag
        'System.Description' = "Submitted via Front-Door form by <b>$($s.team)</b>.<br/>Source channel: Power Automate.<br/>Awaiting triage by P PMO."
    }
    Write-Done "P#$($wi.id) $($s.title)"
    $createdIntake += [pscustomobject]@{ Id = $wi.id; Team = $s.team; Title = $s.title }
}

# Source stories in contributing team projects + cross-project Related links
foreach ($intake in $createdIntake) {
    $srcTitle = $intake.Title -replace '^\[INTAKE\]\s*', ''
    $src = New-WorkItem -project $intake.Team -type 'User Story' -title $srcTitle -fields @{
        'System.Tags'        = 'submitted-to-P'
        'System.Description' = "Originating story in <b>$($intake.Team)</b>. Mirrored into <b>$CentralProject\Intake</b> as P#$($intake.Id) via Power Automate front door."
    }
    Write-Done "$($intake.Team)#$($src.id) $srcTitle"
    Add-RemoteRelatedLink -fromId $intake.Id -fromProject $CentralProject -toId $src.id -toProject $intake.Team
}

# ---------------------------------------------------------------------------
# 6. Saved queries
# ---------------------------------------------------------------------------
Write-Step "Step 6/6: saved queries in '$CentralProject'"

$wiqlNew = @"
SELECT [System.Id],[System.Title],[System.State],[System.AreaPath],[System.Tags],[System.CreatedDate]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] = 'User Story'
  AND [System.AreaPath] UNDER '$CentralProject\Intake'
  AND [System.CreatedDate] >= @today - 7
ORDER BY [System.CreatedDate] DESC
"@

$wiqlAwaiting = @"
SELECT [System.Id],[System.Title],[System.State],[System.AreaPath],[System.Tags]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] = 'User Story'
  AND [System.State] = 'New'
  AND [System.AreaPath] UNDER '$CentralProject\Intake'
"@

$wiqlAccepted = @"
SELECT [System.Id],[System.Title],[System.AreaPath],[System.Tags]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] = 'User Story'
  AND [System.AreaPath] UNDER '$CentralProject\Programs'
"@

Ensure-Query -project $CentralProject -folder 'P-Intake' -name 'Intake - New (last 7 days)' -wiql $wiqlNew
Ensure-Query -project $CentralProject -folder 'P-Intake' -name 'Intake - Awaiting Triage' -wiql $wiqlAwaiting
Ensure-Query -project $CentralProject -folder 'P-Intake' -name 'Cross-Project Accepted Stories' -wiql $wiqlAccepted

Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Demo provisioned." -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host " Org    : $Organization"
Write-Host " Central: $CentralProject"
Write-Host " Teams  : $($TeamProjects -join ', ')"
Write-Host " Browse : ${Organization}$CentralProject"
Write-Host ""
Write-Host " Next  : import the Power Automate flow -> demo/flows/README.md"
Write-Host " Reset : pwsh ./demo/teardown.ps1 -Confirm"
