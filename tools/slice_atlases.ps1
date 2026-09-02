$ErrorActionPreference = "Continue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$SlicerPath = Join-Path $PSScriptRoot "slice_atlases.py"
$Candidates = [System.Collections.Generic.List[object]]::new()

function Add-CommandCandidate {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$PrefixArguments = @()
    )
    $Command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -ne $Command) {
        $Candidates.Add([pscustomobject]@{
            Label = $Name
            Executable = $Command.Source
            PrefixArguments = $PrefixArguments
        })
    }
}

Add-CommandCandidate -Name "py" -PrefixArguments @("-3")
Add-CommandCandidate -Name "python"

$LocalRuntime = Join-Path $env:USERPROFILE ".cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
if (Test-Path -LiteralPath $LocalRuntime -PathType Leaf) {
    $Candidates.Add([pscustomobject]@{
        Label = "local Codex Python runtime"
        Executable = $LocalRuntime
        PrefixArguments = @()
    })
}

$Selected = $null
$Failures = [System.Collections.Generic.List[string]]::new()
foreach ($Candidate in $Candidates) {
    $ProbeArguments = @($Candidate.PrefixArguments) + @("-c", "import PIL")
    $ProbeOutput = & $Candidate.Executable @ProbeArguments 2>&1
    if ($LASTEXITCODE -eq 0) {
        $Selected = $Candidate
        break
    }
    $Failures.Add("$($Candidate.Label): Python unavailable or Pillow missing ($($ProbeOutput -join ' '))")
}

if ($null -eq $Selected) {
    Write-Error @"
Unable to run the RUNE TRIO atlas slicer.
No working Python runtime with Pillow was found.

Checked, in order: py, python, and the existing local Codex Python runtime.
Install Python and Pillow manually, then run this script again. Nothing was installed automatically.
$($Failures -join [Environment]::NewLine)
"@
    exit 1
}

if (-not (Test-Path -LiteralPath $SlicerPath -PathType Leaf)) {
    Write-Error "Atlas slicer not found: $SlicerPath"
    exit 1
}

Write-Host "Using $($Selected.Label): $($Selected.Executable)"
$RunArguments = @($Selected.PrefixArguments) + @($SlicerPath) + @($args)
Push-Location $ProjectRoot
try {
    & $Selected.Executable @RunArguments
    exit $LASTEXITCODE
}
finally {
    Pop-Location
}
