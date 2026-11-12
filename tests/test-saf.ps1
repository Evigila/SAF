#requires -Version 5.1
[CmdletBinding()]
param([switch]$KeepFixtures)

# Run explicitly after reviewing the release: powershell.exe or pwsh -File tests/test-saf.ps1.
# This suite executes the handlers only against temporary Git repositories. It does
# not use a network source, Pester, global Git configuration, or the current index.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$utf8 = New-Object Text.UTF8Encoding($false, $true)
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$shellName = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' }
    elseif ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { 'pwsh.exe' } else { 'pwsh' }
$shellExecutable = Join-Path $PSHOME $shellName
$fixtureRoot = Join-Path ([IO.Path]::GetTempPath()) ('saf-tests-' + [Guid]::NewGuid().ToString('N'))
$emptyHooks = Join-Path $fixtureRoot 'empty-hooks'
$successful = $false
$checks = 0

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}

function Assert-Equal($Expected, $Actual, [string]$Message) {
    if ($Expected -cne $Actual) { throw "$Message`nExpected: $Expected`nActual: $Actual" }
}

function Get-ByteHash([byte[]]$Bytes) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}

function Quote-Argument([string]$Value) {
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"')
    $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq [char]92) { $slashes++; continue }
        if ($character -eq [char]34) {
            [void]$builder.Append(('\' * (2 * $slashes + 1)))
            [void]$builder.Append('"')
        } else {
            [void]$builder.Append(('\' * $slashes))
            [void]$builder.Append($character)
        }
        $slashes = 0
    }
    [void]$builder.Append(('\' * (2 * $slashes)))
    [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-Process([string]$Executable, [string[]]$Arguments, [string]$RawArguments = '', [hashtable]$Environment = @{}) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = $Executable
    $start.Arguments = if ($RawArguments) { $RawArguments } else { (($Arguments | ForEach-Object { Quote-Argument $_ }) -join ' ') }
    $start.UseShellExecute = $false
    $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true
    $start.RedirectStandardError = $true
    $start.RedirectStandardInput = $true
    $start.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    foreach ($key in $Environment.Keys) { $start.EnvironmentVariables[$key] = [string]$Environment[$key] }
    $process = New-Object Diagnostics.Process
    $process.StartInfo = $start
    try {
        [void]$process.Start()
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(120000)) {
            $process.Kill()
            throw "Child process timed out: $Executable"
        }
        return [pscustomobject]@{ ExitCode = $process.ExitCode; Output = $stdout.Result + $stderr.Result }
    } finally { $process.Dispose() }
}

function Invoke-Git([string[]]$Arguments) {
    $result = Invoke-Process 'git' $Arguments
    if ($result.ExitCode -ne 0) { throw "Fixture Git failed: $($result.Output)" }
    return $result.Output.Trim()
}

function Invoke-Script([string]$Path, [string[]]$Arguments) {
    return Invoke-Process $shellExecutable (@('-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', $Path) + $Arguments)
}

function Assert-Exit($Result, [int]$Expected, [string]$Message) {
    Assert-Equal $Expected $Result.ExitCode "$Message`n$($Result.Output)"
    $script:checks++
    Write-Host "PASS: $Message"
}

function Write-Text([string]$Path, [string]$Text) {
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($Path))
    [IO.File]::WriteAllText($Path, $Text, $utf8)
}

function Read-Json([string]$Path) {
    $json = [IO.File]::ReadAllText($Path, $utf8)
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { return $json | ConvertFrom-Json -DateKind String }
    return $json | ConvertFrom-Json
}

function Write-Json([string]$Path, $Value) { Write-Text $Path (($Value | ConvertTo-Json -Depth 40) + "`n") }

function Initialize-Repository([string]$Root) {
    [void][IO.Directory]::CreateDirectory($Root)
    [void](Invoke-Git @('-c', ('init.templateDir=' + $emptyHooks), 'init', '--quiet', $Root))
    [void](Invoke-Git @('-C', $Root, 'symbolic-ref', 'HEAD', 'refs/heads/main'))
}

function Commit-Repository([string]$Root, [string]$Message) {
    [void](Invoke-Git @('-C', $Root, 'add', '--all'))
    [void](Invoke-Git @('-C', $Root, '-c', 'user.name=SAF fixture', '-c', 'user.email=saf-fixture@example.invalid', '-c',
        'commit.gpgsign=false', '-c', ('core.hooksPath=' + $emptyHooks), 'commit', '--quiet', '-m', $Message))
    return Invoke-Git @('-C', $Root, 'rev-parse', 'HEAD')
}

function Get-Snapshot([string]$Root) {
    $result = @{}
    foreach ($file in [IO.Directory]::GetFiles($Root, '*', [IO.SearchOption]::AllDirectories)) {
        $relative = $file.Substring($Root.Length + 1).Replace([char]92, [char]47)
        if ($relative.StartsWith('.git/') -or $relative.StartsWith('.agent/saf_log/')) { continue }
        $result[$relative] = Get-ByteHash ([IO.File]::ReadAllBytes($file))
    }
    return $result
}

function Assert-Snapshot($Before, [string]$Root, [string]$Message) {
    $after = Get-Snapshot $Root
    Assert-Equal $Before.Count $after.Count "$Message (file count)"
    foreach ($relative in $Before.Keys) {
        Assert-True ($after.ContainsKey($relative)) "$Message (missing $relative)"
        Assert-Equal $Before[$relative] $after[$relative] "$Message (changed $relative)"
    }
}

function Invoke-Origin([string[]]$Arguments, [string]$Source = $script:source, [string]$Project = $script:project) {
    return Invoke-Script (Join-Path $Project 'scripts/origin.ps1') (@('-ProjectRoot', $Project, '-SourcePath', $Source, '-Repository', $Source, '-Ref', 'main') + $Arguments)
}

function Get-Backups([string]$Root) {
    $path = Join-Path $Root '.agent/backup'
    if ([IO.Directory]::Exists($path)) { return @(Get-ChildItem -LiteralPath $path -Directory -Force) }
    return @()
}

function Get-GitState([string]$Root) {
    return [pscustomobject]@{
        head = Invoke-Git @('-C', $Root, 'rev-parse', 'HEAD')
        origin = Invoke-Git @('-C', $Root, 'config', '--get', 'remote.origin.url')
        index = Get-ByteHash ([IO.File]::ReadAllBytes((Join-Path $Root '.git/index')))
    }
}

function Assert-GitState($Before, [string]$Root) {
    $after = Get-GitState $Root
    Assert-Equal $Before.head $after.head 'Synchronization changed the consumer commit.'
    Assert-Equal $Before.origin $after.origin 'Synchronization changed the consumer origin.'
    Assert-Equal $Before.index $after.index 'Synchronization changed the consumer index.'
}

try {
    [void][IO.Directory]::CreateDirectory($fixtureRoot)
    [void][IO.Directory]::CreateDirectory($emptyHooks)
    $source = Join-Path $fixtureRoot 'framework source'
    $project = Join-Path $fixtureRoot 'consumer project'
    Initialize-Repository $source
    Initialize-Repository $project
    $manifest = Read-Json (Join-Path $repositoryRoot 'SAF.json')
    $sourceFiles = @(@($manifest.files | ForEach-Object { $_.source }) + @('SAF.json', 'init.ps1', 'scripts/publish-saf.ps1') | Select-Object -Unique)
    foreach ($relative in $sourceFiles) {
        $destination = Join-Path $source $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::Copy((Join-Path $repositoryRoot $relative), $destination, $false)
    }
    $initialCommit = Commit-Repository $source 'Initial SAF fixture release'
    Assert-Exit (Invoke-Script (Join-Path $source 'scripts/publish-saf.ps1') @('-Check')) 0 'Source fixture validates without changing release files.'

    $init = Join-Path $source 'init.ps1'
    $initArguments = @('-ProjectRoot', $project, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')
    Assert-Exit (Invoke-Script $init @('-ProjectRoot', (Join-Path $fixtureRoot 'missing project'), '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')) 1 'Bootstrap failures propagate a nonzero process exit.'
    Assert-Exit (Invoke-Script $init $initArguments) 0 'Bootstrap deploys usable handlers without a network source.'
    foreach ($relative in @($manifest.bootstrapFiles)) { Assert-True ([IO.File]::Exists((Join-Path $project $relative))) "Bootstrap omitted $relative" }
    Assert-True (-not [IO.File]::Exists((Join-Path $project 'AGENTS.md'))) 'Bootstrap unexpectedly installed the framework payload.'
    $lockPath = Join-Path $project 'SAF.lock.json'
    $state = Read-Json $lockPath
    Assert-True ($null -eq $state.installation) 'Bootstrap falsely recorded a payload installation.'
    Assert-True ($null -eq $state.audit -or $null -eq $state.audit.lastCompletedAtUtc) 'Bootstrap copied a completed central audit.'

    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check')) 2 'Fresh Check reports an available installation.'
    Assert-Snapshot $before $project 'Check changed files outside its log-only exception.'
    Assert-Exit (Invoke-Origin @('-Check', '-Update')) 1 'Mutually exclusive action flags are rejected.'
    Assert-Snapshot $before $project 'Invalid arguments changed framework state.'
    Assert-Exit (Invoke-Origin @('-Force')) 1 'Force without Update is rejected.'

    Assert-Exit (Invoke-Origin @('-Sync')) 0 'Sync installs the release after checking.'
    $state = Read-Json $lockPath
    Assert-Equal $initialCommit $state.installation.commit 'Installation did not record the exact resolved commit.'
    Assert-Equal $manifest.frameworkVersion $state.installation.frameworkVersion 'Installation version differs from the release.'
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check')) 0 'Check reports the installed release as current.'
    Assert-Snapshot $before $project 'Current Check rewrote payload or lock.'

    $core = Join-Path $project 'scripts/saf-core.ps1'
    . $core
    $emptySnapshot = Join-Path $project 'empty-snapshot.txt'
    [IO.File]::WriteAllBytes($emptySnapshot, [byte[]]@())
    $failedAsExpected = $false
    try {
        Invoke-SafTransaction -Root $project -Operations @(
            [pscustomobject]@{ relative = 'empty-snapshot.txt'; bytes = $utf8.GetBytes('temporary replacement'); delete = $false },
            [pscustomobject]@{ relative = 'injected-write-failure.txt'; bytes = $null; delete = $false }
        )
    } catch { $failedAsExpected = $true }
    Assert-True $failedAsExpected 'The fixture did not inject a mid-write failure.'
    Assert-True ([IO.File]::Exists($emptySnapshot)) 'Rollback removed an originally empty file.'
    Assert-Equal 0 ([IO.File]::ReadAllBytes($emptySnapshot).Length) 'Rollback did not restore empty-file bytes.'
    Assert-True (-not [IO.File]::Exists((Join-Path $project 'injected-write-failure.txt'))) 'Rollback retained a new partial file.'
    [IO.File]::Delete($emptySnapshot)
    $audit = [pscustomobject]@{ auditedFrameworkVersion = $manifest.frameworkVersion; lastCompletedAtUtc = '2026-11-12T12:00:00Z'; lastMissingMaterialAskedAtUtc = $null }
    Set-SafState -Root $project -Section audit -Value $audit
    $state = Read-Json $lockPath
    Assert-Equal $initialCommit $state.installation.commit 'Audit writing lost the installation section.'
    $auditJson = $state.audit | ConvertTo-Json -Compress

    $facts = Join-Path $project 'docs-ai/current/consumer-memory.md'
    $human = Join-Path $project 'docs/manual.md'
    $customSkill = Join-Path $project '.agents/skills/consumer-skill/SKILL.md'
    $debug = Join-Path $project 'debug.bat'
    Write-Text $facts "# Consumer facts`nKeep this local knowledge.`n"
    Write-Text $human "# Human documentation`nKeep this content.`n"
    Write-Text $customSkill "---`nname: consumer-skill`ndescription: Consumer-only fixture skill.`n---`nKeep this package.`n"
    Write-Text $debug "@echo off`r`necho consumer debug customization`r`n"
    $protected = @{}
    foreach ($file in @($facts, $human, $customSkill, $debug)) { $protected[$file] = Get-ByteHash ([IO.File]::ReadAllBytes($file)) }
    Write-Text (Join-Path $project '.gitignore') ".agent/`n"
    [void](Commit-Repository $project 'Consumer facts and local configuration')
    [void](Invoke-Git @('-C', $project, 'remote', 'add', 'origin', 'https://example.invalid/consumer.git'))
    Write-Text (Join-Path $project 'unrelated-staged.txt') 'An unrelated staged change must remain staged.'
    [void](Invoke-Git @('-C', $project, 'add', '--', 'unrelated-staged.txt'))
    $gitState = Get-GitState $project

    $rulesSource = Join-Path $source 'docs-ai/common/rules.md'
    Write-Text $rulesSource ([IO.File]::ReadAllText($rulesSource, $utf8) + "`n<!-- Fixture release change. -->`n")
    $baseVersion = [version]$manifest.frameworkVersion
    $nextVersion = $baseVersion.Major.ToString() + '.' + ($baseVersion.Minor + 1).ToString() + '.0'
    Assert-Exit (Invoke-Script (Join-Path $source 'scripts/publish-saf.ps1') @('-Version', $nextVersion)) 0 'Publisher requires and prepares a higher release version.'
    $nextCommit = Commit-Repository $source 'Compatible fixture upgrade'
    Assert-Exit (Invoke-Origin @('-Check')) 2 'Check detects the new release.'
    Assert-Exit (Invoke-Origin @('-Sync')) 0 'Sync applies the checked release.'
    $state = Read-Json $lockPath
    Assert-Equal $nextCommit $state.installation.commit 'Upgrade lost the resolved source commit.'
    Assert-Equal $auditJson ($state.audit | ConvertTo-Json -Compress) 'Upgrade rewrote audit evidence.'
    Assert-GitState $gitState $project
    foreach ($file in $protected.Keys) { Assert-Equal $protected[$file] (Get-ByteHash ([IO.File]::ReadAllBytes($file))) "Upgrade replaced protected content: $file" }
    $before = Get-Snapshot $project
    Write-Text (Join-Path $source 'source-only-note.md') 'This file is outside the payload.'
    [void](Commit-Repository $source 'Source-only documentation change')
    Assert-Exit (Invoke-Origin @('-Check')) 0 'A source-only commit is not a framework update.'
    Assert-Snapshot $before $project 'Source-only Check rewrote consumer state.'

    $rulesTarget = Join-Path $project 'docs-ai/common/rules.md'
    Write-Text $rulesTarget ([IO.File]::ReadAllText($rulesTarget, $utf8) + "`nCommitted consumer customization.`n")
    $customBytes = [IO.File]::ReadAllBytes($rulesTarget)
    [void](Commit-Repository $project 'Committed managed customization')
    $gitState = Get-GitState $project
    Write-Text $rulesSource ([IO.File]::ReadAllText($rulesSource, $utf8) + "`n<!-- Second fixture release change. -->`n")
    $forceVersion = $baseVersion.Major.ToString() + '.' + ($baseVersion.Minor + 2).ToString() + '.0'
    Assert-Exit (Invoke-Script (Join-Path $source 'scripts/publish-saf.ps1') @('-Version', $forceVersion)) 0 'Publisher prepares a second compatible fixture upgrade.'
    [void](Commit-Repository $source 'Conflicting fixture upgrade')
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check')) 3 'Check identifies committed managed customizations.'
    Assert-Snapshot $before $project 'Conflict Check modified consumer data.'
    Assert-Exit (Invoke-Origin @('-Update')) 3 'Update refuses a managed conflict without Force.'
    Assert-Snapshot $before $project 'Refused update modified consumer data.'
    Assert-Exit (Invoke-Origin @('-Update', '-Force')) 0 'Forced update backs up and replaces the managed conflict.'
    Assert-GitState $gitState $project
    $matchingBackups = @(Get-ChildItem -LiteralPath (Join-Path $project '.agent/backup') -File -Recurse -Force | Where-Object {
        $_.Name -eq 'rules.md' -and (Get-ByteHash ([IO.File]::ReadAllBytes($_.FullName))) -eq (Get-ByteHash $customBytes)
    })
    Assert-True ($matchingBackups.Count -gt 0) 'Force did not preserve exact original conflict bytes.'
    foreach ($file in $protected.Keys) { Assert-Equal $protected[$file] (Get-ByteHash ([IO.File]::ReadAllBytes($file))) "Force replaced project-owned content: $file" }

    $badSource = Join-Path $fixtureRoot 'invalid source'
    [void](Invoke-Git @('-c', ('core.hooksPath=' + $emptyHooks), '-c', ('init.templateDir=' + $emptyHooks), 'clone', '--quiet', $source, $badSource))
    Write-Text (Join-Path $badSource 'docs-ai/common/rules.md') 'Tampered bytes without a matching digest.'
    [void](Commit-Repository $badSource 'Invalid payload fixture')
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check') $badSource) 1 'Payload hash mismatch is rejected before target writes.'
    Assert-Snapshot $before $project 'Invalid payload check changed consumer data.'
    $badManifest = Read-Json (Join-Path $badSource 'SAF.json')
    $badManifest.handlerProtocolVersion = 99
    Write-Json (Join-Path $badSource 'SAF.json') $badManifest
    [void](Commit-Repository $badSource 'Incompatible handler fixture')
    Assert-Exit (Invoke-Origin @('-Check') $badSource) 4 'Unsupported handler protocol requests reinitialization.'
    Assert-Snapshot $before $project 'Incompatible handler check changed consumer data.'

    $validLockBytes = [IO.File]::ReadAllBytes($lockPath)
    $businessFile = Join-Path $project 'business-owned.txt'
    Write-Text $businessFile 'This file is not owned by the framework.'
    $forgedState = Read-Json $lockPath
    $forgedHashes = [ordered]@{ 'business-owned.txt' = Get-ByteHash ([IO.File]::ReadAllBytes($businessFile)) }
    $forgedState | Add-Member -NotePropertyName migration -NotePropertyValue ([pscustomobject]@{ legacyHashes = [pscustomobject]$forgedHashes }) -Force
    Write-Json $lockPath $forgedState
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check')) 1 'Forged migration ownership cannot authorize arbitrary project deletion.'
    Assert-Snapshot $before $project 'Forged migration Check changed consumer data.'
    Assert-Exit (Invoke-Origin @('-Update')) 1 'Update rejects forged migration ownership before planning deletes.'
    Assert-Snapshot $before $project 'Forged migration update changed consumer data.'
    [IO.File]::WriteAllBytes($lockPath, $validLockBytes)

    $missingSeedSource = Join-Path $fixtureRoot 'missing seed source'
    [void](Invoke-Git @('-c', ('core.hooksPath=' + $emptyHooks), '-c', ('init.templateDir=' + $emptyHooks), 'clone', '--quiet', $source, $missingSeedSource))
    $missingSeedManifest = Read-Json (Join-Path $missingSeedSource 'SAF.json')
    $missingSeedManifest.files = @($missingSeedManifest.files | Where-Object { $_.target -ne 'debug.bat' })
    Write-Json (Join-Path $missingSeedSource 'SAF.json') $missingSeedManifest
    [void](Commit-Repository $missingSeedSource 'Invalid missing debug seed fixture')
    Assert-Exit (Invoke-Script (Join-Path $missingSeedSource 'scripts/publish-saf.ps1') @('-Check')) 1 'Publisher rejects a manifest missing the required debug seed.'
    $legacyDebugProject = Join-Path $fixtureRoot 'legacy debug consumer'
    Initialize-Repository $legacyDebugProject
    Assert-Exit (Invoke-Script $init @('-ProjectRoot', $legacyDebugProject, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')) 0 'Prepare a handler-only consumer with a legacy debug menu.'
    Write-Text (Join-Path $legacyDebugProject 'debug-handler.bat') "@echo off`r`necho preserve legacy project operations`r`n"
    $before = Get-Snapshot $legacyDebugProject
    Assert-Exit (Invoke-Origin @('-Update') $missingSeedSource $legacyDebugProject) 1 'Missing debug seed cannot retire an existing project-owned debug menu.'
    Assert-Snapshot $before $legacyDebugProject 'Invalid missing seed update changed the legacy debug consumer.'

    $installationJson = (Read-Json $lockPath).installation | ConvertTo-Json -Depth 40 -Compress
    Write-Text (Join-Path $project 'origin.bat') '@echo broken handler'
    Write-Text (Join-Path $project 'scripts/local.ps1') '# broken handler'
    Assert-Exit (Invoke-Script $init $initArguments) 0 'Reinitialization repairs the complete handler set.'
    $state = Read-Json $lockPath
    Assert-Equal $installationJson ($state.installation | ConvertTo-Json -Depth 40 -Compress) 'Handler repair changed payload installation state.'
    Assert-Equal $auditJson ($state.audit | ConvertTo-Json -Compress) 'Handler repair changed audit evidence.'

    $local = Join-Path $project 'scripts/local.ps1'
    $localArguments = @('-ProjectRoot', $project)
    Assert-Exit (Invoke-Script $local ($localArguments + @('-NoArquived'))) 0 'Archive ignore is configured without remote operations.'
    $ignoreHash = Get-ByteHash ([IO.File]::ReadAllBytes((Join-Path $project '.gitignore')))
    Assert-Exit (Invoke-Script $local ($localArguments + @('-NoArquived'))) 0 'Repeated archive ignore is idempotent.'
    Assert-Equal $ignoreHash (Get-ByteHash ([IO.File]::ReadAllBytes((Join-Path $project '.gitignore')))) 'Repeated ignore configuration duplicated or changed rules.'
    $backupsBefore = @(Get-Backups $project | ForEach-Object { $_.FullName })
    Assert-Exit (Invoke-Script $local ($localArguments + @('-Backup'))) 0 'Manual backup creates a local SAF recovery snapshot.'
    $newBackups = @(Get-Backups $project | Where-Object { $_.FullName -notin $backupsBefore })
    Assert-Equal 1 $newBackups.Count 'Manual backup should produce one recovery point.'
    Assert-True ([IO.File]::Exists((Join-Path $newBackups[0].FullName 'inventory.json'))) 'Backup omitted its content inventory.'
    Assert-True ([IO.File]::Exists((Join-Path $newBackups[0].FullName 'files/docs-ai/current/consumer-memory.md'))) 'Backup omitted scoped consumer facts.'
    Assert-True (-not [IO.Directory]::Exists((Join-Path $newBackups[0].FullName 'files/.agent/backup'))) 'Backup recursively included previous recovery points.'
    Assert-True (-not [IO.File]::Exists((Join-Path $newBackups[0].FullName 'files/unrelated-staged.txt'))) 'SAF recovery backup unexpectedly included unrelated source.'

    $archive = Join-Path $project 'docs-ai/current/1_archived'
    Write-Text (Join-Path $archive 'old-report.md') '# Superseded fixture report'
    Write-Text (Join-Path $archive '.hidden-report.md') '# Hidden archived evidence'
    $downloads = Join-Path $fixtureRoot 'redirected downloads'
    [void][IO.Directory]::CreateDirectory($downloads)
    Assert-Exit (Invoke-Script $local ($localArguments + @('-CleanArquived', '-Destination', $downloads))) 0 'Archive export verifies content before cleaning the source.'
    Assert-True (-not [IO.File]::Exists((Join-Path $archive 'old-report.md'))) 'Verified exported report was not cleaned.'
    Assert-True (-not [IO.File]::Exists((Join-Path $archive '.hidden-report.md'))) 'Hidden report was not included in the cleanup.'
    Assert-True ([IO.Directory]::Exists($archive)) 'Archive directory was removed.'
    $zips = @(Get-ChildItem -LiteralPath $downloads -Filter '*.zip' -File)
    Assert-Equal 1 $zips.Count 'Archive export should produce a unique ZIP.'
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($zips[0].FullName)
    try {
        Assert-True (@($zip.Entries | Where-Object { $_.FullName.EndsWith('.hidden-report.md') }).Count -eq 1) 'Export omitted hidden archived evidence.'
    } finally { $zip.Dispose() }

    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $batch = Join-Path $project 'origin.bat'
        $raw = '/d /s /c ""' + $batch + '" -check -SourcePath "' + $source + '" -Repository "' + $source + '" -Ref main"'
        Assert-Exit (Invoke-Process $env:ComSpec @() $raw) 0 'Installed BAT forwards explicit Check arguments and returns without waiting.'
        if ($PSVersionTable.PSEdition -eq 'Desktop') {
            # Native wrappers prefer pwsh when present. Remove it from this child PATH
            # to verify the Windows PowerShell fallback without changing user settings.
            $fallbackPath = @($env:PATH.Split([IO.Path]::PathSeparator) | Where-Object {
                $candidate = $_.Trim('"')
                $candidate -and -not (Test-Path -LiteralPath (Join-Path $candidate 'pwsh.exe'))
            }) -join [IO.Path]::PathSeparator
            $fallbackEnvironment = @{ PATH = $fallbackPath }
            Assert-Exit (Invoke-Process $env:ComSpec @() '/d /c where pwsh.exe' -Environment $fallbackEnvironment) 1 'The fallback child environment cannot resolve PowerShell 7.'
            Assert-Exit (Invoke-Process $env:ComSpec @() $raw -Environment $fallbackEnvironment) 0 'Origin BAT works with only Windows PowerShell 5.1 available.'
            $localRaw = '/d /s /c ""' + (Join-Path $project 'local.bat') + '" -backup"'
            Assert-Exit (Invoke-Process $env:ComSpec @() $localRaw -Environment $fallbackEnvironment) 0 'Local BAT backup works with only Windows PowerShell 5.1 available.'
            $debugRaw = '/d /s /c ""' + (Join-Path $source 'debug.bat') + '" -NonInteractive 0"'
            Assert-Exit (Invoke-Process $env:ComSpec @() $debugRaw -Environment $fallbackEnvironment) 0 'Debug BAT cancellation works with only Windows PowerShell 5.1 available.'
        }
    } else { Write-Host 'SKIP: Native BAT interaction requires Windows.' }

    $legacyProject = Join-Path $fixtureRoot 'legacy consumer'
    Initialize-Repository $legacyProject
    $legacyAudit = [ordered]@{ schemaVersion = 2; auditedFrameworkVersion = '1.2.1'; lastCompletedAtUtc = '2026-10-10T23:31:11Z'; lastMissingMaterialAskedAtUtc = $null }
    $legacyLock = [ordered]@{ schemaVersion = 1; frameworkVersion = '1.2.1'; repository = $source; ref = 'main'; commit = $initialCommit; manifestSha256 = ('a' * 64); managedFiles = @{}; synchronizedAtUtc = '2026-10-10T23:00:00Z' }
    Write-Json (Join-Path $legacyProject 'AGENTS.ensure.json') $legacyAudit
    Write-Json (Join-Path $legacyProject 'AGENTS.lock.json') $legacyLock
    Assert-Exit (Invoke-Script $init @('-ProjectRoot', $legacyProject, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')) 0 'Bootstrap imports legacy installation and audit evidence.'
    $legacyState = Read-Json (Join-Path $legacyProject 'SAF.lock.json')
    Assert-Equal '1.2.1' $legacyState.installation.frameworkVersion 'Legacy installation baseline was lost.'
    Assert-Equal '2026-10-10T23:31:11Z' $legacyState.audit.lastCompletedAtUtc 'Legacy audit evidence was falsely refreshed or lost.'

    $successful = $true
    Write-Host "All $checks explicitly requested integration checks passed."
} catch {
    Write-Host ('FAIL: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host "Fixtures retained: $fixtureRoot"
    throw
} finally {
    if ($successful -and -not $KeepFixtures -and [IO.Directory]::Exists($fixtureRoot)) {
        $resolved = [IO.Path]::GetFullPath($fixtureRoot)
        $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
        if (-not [IO.Path]::GetDirectoryName($resolved).Equals($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
            [IO.Path]::GetFileName($resolved) -notmatch '^saf-tests-[0-9a-f]{32}$') { throw 'Refusing fixture cleanup outside the expected temporary root.' }
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
