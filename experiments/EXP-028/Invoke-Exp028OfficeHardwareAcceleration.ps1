[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [ValidateSet('Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback')]
  [string]$Action='Check',
  [string]$StatePath="$PSScriptRoot\state.json",
  [string]$LogPath="$PSScriptRoot\events.jsonl"
)

Set-StrictMode -Version 2.0
$ErrorActionPreference='Stop'
$UserPath='HKCU:\Software\Microsoft\Office\16.0\Common\Graphics'
$PolicyPaths=@(
  'HKCU:\Software\Policies\Microsoft\Office\16.0\Common\Graphics',
  'HKLM:\Software\Policies\Microsoft\Office\16.0\Common\Graphics'
)
$ValueName='DisableHardwareAcceleration'
$TargetValue=1

function Write-Event([string]$Event,[hashtable]$Data){
  $parent=Split-Path -Parent $LogPath
  if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $row=[ordered]@{utc=(Get-Date).ToUniversalTime().ToString('o');experiment='EXP-028';action=$Action;event=$Event;computer=$env:COMPUTERNAME;userSid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value;data=$Data}
  ($row|ConvertTo-Json -Compress -Depth 8)|Add-Content -LiteralPath $LogPath -Encoding UTF8
}

function Get-RegistryValueState([string]$Path,[string]$Name){
  if(-not(Test-Path -LiteralPath $Path)){return [ordered]@{keyExists=$false;valueExists=$false;kind=$null;data=$null}}
  $key=Get-Item -LiteralPath $Path
  try {
    $kind=$key.GetValueKind($Name).ToString()
    $data=$key.GetValue($Name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    [ordered]@{keyExists=$true;valueExists=$true;kind=$kind;data=$data}
  }
  catch [System.ArgumentException] {[ordered]@{keyExists=$true;valueExists=$false;kind=$null;data=$null}}
}

function Get-Support {
  $os=Get-CimInstance Win32_OperatingSystem
  $cs=Get-CimInstance Win32_ComputerSystem
  if($os.Caption -notmatch 'Windows 11' -or $cs.Manufacturer -notmatch 'HP|Hewlett-Packard'){throw 'Unsupported platform'}
  $outlook=Get-Command outlook.exe -ErrorAction SilentlyContinue
  if(-not $outlook){
    $paths=@("$env:ProgramFiles\Microsoft Office\root\Office16\OUTLOOK.EXE","${env:ProgramFiles(x86)}\Microsoft Office\root\Office16\OUTLOOK.EXE")
    $outlookPath=$paths|Where-Object {$_ -and (Test-Path -LiteralPath $_)}|Select-Object -First 1
  } else {$outlookPath=$outlook.Source}
  if(-not $outlookPath){throw 'Microsoft Outlook executable absent'}
  foreach($policyPath in $PolicyPaths){
    $policy=Get-RegistryValueState $policyPath $ValueName
    if($policy.valueExists){throw "Enterprise Office policy controls $ValueName at $policyPath"}
  }
  [ordered]@{outlookPath=$outlookPath;officeVersion='16.0';userPath=$UserPath;valueName=$ValueName;current=(Get-RegistryValueState $UserPath $ValueName)}
}

function Save-State($support){
  $parent=Split-Path -Parent $StatePath
  if($parent -and -not(Test-Path -LiteralPath $parent)){New-Item -ItemType Directory -Path $parent -Force|Out-Null}
  $state=[ordered]@{schema=1;experiment='EXP-028';computer=$env:COMPUTERNAME;userSid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value;outlookPath=$support.outlookPath;userPath=$UserPath;valueName=$ValueName;original=$support.current;capturedUtc=(Get-Date).ToUniversalTime().ToString('o')}
  $state|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $StatePath -Encoding UTF8
  Write-Event 'state-captured' @{path=$UserPath;name=$ValueName;original=$support.current;outlookPath=$support.outlookPath}
  $state
}

function Read-State {
  if(-not(Test-Path -LiteralPath $StatePath)){throw 'State file missing'}
  $s=Get-Content -LiteralPath $StatePath -Raw|ConvertFrom-Json
  $sid=[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value
  if($s.schema -ne 1 -or $s.experiment -ne 'EXP-028' -or $s.computer -ne $env:COMPUTERNAME -or $s.userSid -ne $sid -or $s.userPath -ne $UserPath -or $s.valueName -ne $ValueName){throw 'State identity refused'}
  if([string]::IsNullOrWhiteSpace([string]$s.outlookPath)){throw 'State content refused'}
  $s
}

function Set-ExperimentalValue {
  if(-not(Test-Path -LiteralPath $UserPath)){New-Item -Path $UserPath -Force|Out-Null}
  New-ItemProperty -Path $UserPath -Name $ValueName -PropertyType DWord -Value $TargetValue -Force|Out-Null
}

try {
  $support=Get-Support
  switch($Action){
    'Check' {Write-Event 'supported' @{outlookPath=$support.outlookPath;current=$support.current};[pscustomobject]$support}
    'Capture' {Save-State $support|Out-Null}
    'DryRun' {
      if(-not(Test-Path -LiteralPath $StatePath)){Save-State $support|Out-Null}
      $plan=[ordered]@{supported=$true;outlookPath=$support.outlookPath;path=$UserPath;name=$ValueName;current=$support.current;targetKind='DWord';targetValue=$TargetValue;wouldChange=(-not $support.current.valueExists -or $support.current.kind -ne 'DWord' -or [int]$support.current.data -ne $TargetValue);statePath=$StatePath}
      Write-Event 'dry-run' $plan;[pscustomobject]$plan
    }
    'Apply' {
      if(-not(Test-Path -LiteralPath $StatePath)){Save-State $support|Out-Null}
      if($support.current.valueExists -and $support.current.kind -eq 'DWord' -and [int]$support.current.data -eq $TargetValue){Write-Event 'already-applied' @{path=$UserPath;name=$ValueName;value=$TargetValue};break}
      if(-not $PSCmdlet.ShouldProcess("$UserPath\$ValueName","Set DWORD $TargetValue")){Write-Event 'apply-declined' @{path=$UserPath;name=$ValueName};break}
      Set-ExperimentalValue
      $after=(Get-Support).current
      if(-not $after.valueExists -or $after.kind -ne 'DWord' -or [int]$after.data -ne $TargetValue){throw 'Apply verification failed'}
      Write-Event 'applied' @{before=$support.current;after=$after}
    }
    'Verify' {
      $after=(Get-Support).current;$ok=($after.valueExists -and $after.kind -eq 'DWord' -and [int]$after.data -eq $TargetValue)
      Write-Event 'verified' @{ok=$ok;current=$after};if(-not $ok){throw 'Verification failed'}
    }
    'VerifyReboot' {
      $after=(Get-Support).current;$ok=($after.valueExists -and $after.kind -eq 'DWord' -and [int]$after.data -eq $TargetValue)
      Write-Event 'reboot-verified' @{ok=$ok;current=$after};if(-not $ok){throw 'Reboot persistence failed'}
    }
    'Rollback' {
      $s=Read-State
      if($support.outlookPath -ne $s.outlookPath){throw 'Rollback Outlook identity changed'}
      if(-not $PSCmdlet.ShouldProcess("$UserPath\$ValueName",'Restore exact captured registry state')){Write-Event 'rollback-declined' @{path=$UserPath;name=$ValueName};break}
      if($s.original.valueExists){
        if(-not(Test-Path -LiteralPath $UserPath)){New-Item -Path $UserPath -Force|Out-Null}
        New-ItemProperty -Path $UserPath -Name $ValueName -PropertyType $s.original.kind -Value $s.original.data -Force|Out-Null
      } else {
        if(Test-Path -LiteralPath $UserPath){Remove-ItemProperty -Path $UserPath -Name $ValueName -ErrorAction SilentlyContinue}
      }
      $after=(Get-Support).current
      $expected=$s.original
      $ok=($after.valueExists -eq $expected.valueExists -and $after.keyExists -eq $expected.keyExists)
      if($ok -and $expected.valueExists){$ok=($after.kind -eq $expected.kind -and [string]$after.data -eq [string]$expected.data)}
      if(-not $ok){throw 'Rollback verification failed'}
      Write-Event 'rolled-back' @{restored=$after}
    }
  }
}
catch {Write-Event 'failure' @{type=$_.Exception.GetType().FullName;message=$_.Exception.Message};throw}
