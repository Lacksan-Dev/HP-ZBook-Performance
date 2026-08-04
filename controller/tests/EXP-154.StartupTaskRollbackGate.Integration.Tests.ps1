Describe 'EXP-154 rollback-gate zero-mutation integration' -Tag 'WindowsIntegration' {
 BeforeAll {
  $script:decisionPath=Join-Path $PSScriptRoot '..\..\experiments\EXP-154\research-decision.md'
  function Snapshot-StartupSurface {
   $run=@()
   foreach($path in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run','HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')){
    if(Test-Path -LiteralPath $path){
     $key=Get-Item -LiteralPath $path
     foreach($name in $key.GetValueNames()|Sort-Object){$run += [pscustomobject]@{Path=$path;Name=$name;Kind=$key.GetValueKind($name).ToString();Data=[string]$key.GetValue($name,$null,[Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)}}
    }
   }
   $tasks=@(Get-ScheduledTask -ErrorAction SilentlyContinue|Sort-Object TaskPath,TaskName|ForEach-Object{[pscustomobject]@{TaskPath=$_.TaskPath;TaskName=$_.TaskName;Enabled=$_.Settings.Enabled;State=$_.State.ToString()}})
   $protected=@('WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale')|ForEach-Object{Get-CimInstance Win32_Service -Filter "Name='$_'" -ErrorAction SilentlyContinue}|Where-Object{$_}|Sort-Object Name|Select-Object Name,State,StartMode,PathName
   [pscustomobject]@{Run=@($run);Tasks=@($tasks);Protected=@($protected)}|ConvertTo-Json -Compress -Depth 8
  }
 }
 It 'reads the research gate without changing Windows startup or protected service state' {
  if($env:LACKSAN_RUN_WINDOWS_INTEGRATION-ne'1' -or $env:OS-ne'Windows_NT'){Set-ItResult -Skipped -Because 'Opt-in Windows integration only.';return}
  $before=Snapshot-StartupSurface
  $text=Get-Content -LiteralPath $script:decisionPath -Raw
  $text|Should -Match 'EXP-154'
  $after=Snapshot-StartupSurface
  $after|Should -BeExactly $before
 }
}
