[CmdletBinding()]
param()

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$scriptPath=Join-Path $PSScriptRoot 'Invoke-Exp031HpSupportSolutions.ps1'
$probeRoot=Join-Path ([System.IO.Path]::GetTempPath()) ('EXP-031-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $probeRoot -Force|Out-Null

try {
  $statePath=Join-Path $probeRoot 'state.json'
  $logPath=Join-Path $probeRoot 'events.jsonl'
  try {
    & $scriptPath -Action Check -StatePath $statePath -LogPath $logPath | Out-Null
    & $scriptPath -Action DryRun -StatePath $statePath -LogPath $logPath | Out-Null
    if(-not(Test-Path -LiteralPath $statePath)){throw 'DryRun did not create current-state evidence'}
  }
  catch {
    if($_.Exception.Message -notmatch 'Unsupported platform|Candidate service absent|identity refused') { throw }
  }

  if(Test-Path -LiteralPath $logPath){
    foreach($line in Get-Content -LiteralPath $logPath){
      $event=$line|ConvertFrom-Json
      if($event.experiment -ne 'EXP-031'){throw 'Structured log experiment identity mismatch'}
      if(-not $event.utc -or -not $event.event){throw 'Structured log missing required fields'}
    }
  }

  'EXP-031 non-destructive integration checks passed.'
}
finally {
  if(Test-Path -LiteralPath $probeRoot){Remove-Item -LiteralPath $probeRoot -Recurse -Force}
}
