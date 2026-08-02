$provider=Join-Path $PSScriptRoot '..\providers\EdgePreserveDiskCacheOnClose.ps1'
Describe 'EXP-096 Edge cache-retention provider contract' {
 BeforeAll {$text=Get-Content -LiteralPath $provider -Raw}
 It 'parses as PowerShell' {$tokens=$null;$errors=$null;[System.Management.Automation.Language.Parser]::ParseFile($provider,[ref]$tokens,[ref]$errors)|Out-Null;@($errors).Count|Should -Be 0}
 It 'implements the full reversible lifecycle' {foreach($a in 'Check','Capture','DryRun','Apply','Verify','VerifyReboot','Rollback'){$text|Should -Match "'$a'"}}
 It 'targets one recommended cache-on-close DWORD zero' {foreach($t in 'ClearCachedImagesAndFilesOnExit','Recommended','DWord','Treatment=0','MutationCount=1'){$text|Should -Match $t};$text|Should -Not -Match 'DiskCacheSize.*New-ItemProperty|Remove-Item .*Cache|Clear-BrowsingData'}
 It 'requires HP Windows 11 elevation Microsoft-signed Edge 83 and controlled profile identity' {foreach($t in 'Windows 11 required','HP platform required','elevation required','Microsoft-signed Edge 83+ required','Get-AuthenticodeSignature','.lacksan-edge-cache-retention.json','ProfileId'){$text|Should -Match ([regex]::Escape($t))}}
 It 'holds overriding browsing data and cache sizing controls fixed' {foreach($t in 'ClearBrowsingDataOnExit','BrowsingDataLifetime','DiskCacheSize','--disk-cache-size','disk cache sizing confounder detected'){$text|Should -Match ([regex]::Escape($t))}}
 It 'captures cache metadata without deleting profile cache content' {foreach($t in 'CacheFileCount','CacheBytes','CachePath','DeleteCacheFiles=$false','cacheFilesDeleted=$false'){$text|Should -Match ([regex]::Escape($t))}}
 It 'refuses enterprise management and startup drift while preserving protected scope' {foreach($t in 'enterprise management ownership detected','CcmExec','Enrollments','OMADM','Edge Startup-folder','WinDefend','mpssvc','wuauserv','UsoSvc','BITS','TermService','Tailscale','edgeupdate'){$text|Should -Match ([regex]::Escape($t))}}
 It 'supports dry run WhatIf logging idempotence failure evidence and reboot verification' {foreach($t in 'SupportsShouldProcess','WhatIfPreference','ConvertTo-Json -Compress','idempotent','failureDetail','A later boot is required','Treatment failed reboot persistence'){$text|Should -Match ([regex]::Escape($t))}}
 It 'implements collision-safe exact rollback' {foreach($t in 'Rollback collision or policy drift detected','RegistryValueKind','Exact rollback verification failed','restoredExactOriginal'){$text|Should -Match ([regex]::Escape($t))}}
 It 'preserves Experimental evidence state' {$text|Should -Match 'needs-evidence';$text|Should -Not -Match 'status:stable|Stable='}
}
