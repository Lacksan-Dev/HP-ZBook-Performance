Describe 'EXP-095 validation harness contract' {
  BeforeAll {$path=Join-Path $PSScriptRoot '../validation/Invoke-EXP095Validation.ps1';$text=Get-Content $path -Raw}
  It 'binds only to EXP-095 CASL provider' {$text|Should -Match 'HPCaslDelayedStart\.ps1';$text|Should -Match "experiment='EXP-095'"}
  It 'requires repeated baseline and treatment runs' {$text|Should -Match "TargetRuns=5";$text|Should -Match "'Baseline','Treatment','Summarize','Rollback'"}
  It 'refuses duplicate collection from one boot' {$text|Should -Match 'This boot already has a run'}
  It 'retains structured raw evidence' {$text|Should -Match "schemaVersion=1";$text|Should -Match "evidence/EXP-095"}
  It 'samples disk activity across the declared window' {$text|Should -Match "Get-Counter '\\\\PhysicalDisk\(_Total\)\\\\Disk Bytes/sec' -SampleInterval 1 -MaxSamples \$SampleSeconds";$text|Should -Match 'diskBytesPerSecondAverage';$text|Should -Match 'diskSampleCount'}
  It 'calculates CPU and disk medians and dispersion' {$text|Should -Match 'function Median';$text|Should -Match 'function Mad';$text|Should -Match 'baselineMAD';$text|Should -Match 'treatmentMAD';$text|Should -Match 'diskBaselineMedian';$text|Should -Match 'diskBaselineMAD';$text|Should -Match 'diskTreatmentMedian';$text|Should -Match 'diskTreatmentMAD'}
  It 'classifies evidence without Stable promotion' {$text|Should -Match "'inconclusive'";$text|Should -Match "'favorable'";$text|Should -Match "'zero-benefit'";$text|Should -Match "'failed'";$text|Should -Not -Match "'Stable'"}
  It 'uses provider lifecycle and exact rollback surface' {$text|Should -Match '-Action Capture';$text|Should -Match '-Action DryRun';$text|Should -Match '-Action Apply';$text|Should -Match '-Action Verify';$text|Should -Match '-Action VerifyReboot';$text|Should -Match '-Action Rollback'}
  It 'makes reboot explicit' {$text|Should -Match '\[switch\]\$AllowReboot';$text|Should -Match 'ShouldProcess';$text|Should -Match 'Restart-Computer'}
}
