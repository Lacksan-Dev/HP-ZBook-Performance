Describe 'EXP-143 read-only integration' -Skip:($env:OS -ne 'Windows_NT') {
    BeforeAll {
        $script:sut = Join-Path $PSScriptRoot 'Invoke-StartupRegistrationInventory.ps1'
        function script:Get-StartupFolderFingerprint {
            $folders = @(
                [Environment]::GetFolderPath('Startup'),
                [Environment]::GetFolderPath('CommonStartup')
            ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique

            @($folders | ForEach-Object {
                Get-ChildItem -LiteralPath $_ -Force -File -ErrorAction SilentlyContinue | ForEach-Object {
                    $hash = Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256
                    [pscustomobject]@{
                        path = $_.FullName
                        sha256 = $hash.Hash
                        length = $_.Length
                        attributes = [string]$_.Attributes
                        creationTimeUtc = $_.CreationTimeUtc.ToString('o')
                        lastWriteTimeUtc = $_.LastWriteTimeUtc.ToString('o')
                    }
                }
            } | Sort-Object path)
        }
    }

    It 'executes twice without mutating Startup-folder registrations and preserves a deterministic snapshot' {
        $before = Get-StartupFolderFingerprint | ConvertTo-Json -Depth 5 -Compress
        $out1 = Join-Path $TestDrive 'run1'
        $out2 = Join-Path $TestDrive 'run2'

        $result1 = & $script:sut -OutputDirectory $out1
        $middle = Get-StartupFolderFingerprint | ConvertTo-Json -Depth 5 -Compress
        $result2 = & $script:sut -OutputDirectory $out2
        $after = Get-StartupFolderFingerprint | ConvertTo-Json -Depth 5 -Compress

        $middle | Should -BeExactly $before
        $after | Should -BeExactly $before
        $result2.Sha256 | Should -BeExactly $result1.Sha256

        $snapshot = Get-Content -LiteralPath $result2.Snapshot -Raw | ConvertFrom-Json
        $snapshot.evidence.schemaVersion | Should -Be 6
        $snapshot.evidence.mode | Should -Be 'read-only'

        $events = Get-Content -LiteralPath (Join-Path $out2 'startup-inventory.jsonl') | ForEach-Object { $_ | ConvertFrom-Json }
        @($events).Count | Should -BeGreaterThan 0
        @($events | Where-Object mutation -eq $true).Count | Should -Be 0
    }
}
