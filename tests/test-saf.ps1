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
        if ($relative.StartsWith('.git/') -or $relative.StartsWith('.agents/saf_log/')) { continue }
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
    $path = Join-Path $Root '.agents/backup'
    if ([IO.Directory]::Exists($path)) { return @(Get-ChildItem -LiteralPath $path -Directory -Force) }
    return @()
}

function Assert-ConfigRecovery([string[]]$BeforePaths, [string]$Root, [byte[]]$ExpectedBytes, [string]$Message) {
    $newBackups = @(Get-Backups $Root | Where-Object { $_.FullName -notin $BeforePaths })
    Assert-True ($newBackups.Count -gt 0) "$Message (no new recovery point)"
    foreach ($backup in $newBackups) {
        $recoveryConfig = Join-Path $backup.FullName 'files/SAF.config.json'
        Assert-True ([IO.File]::Exists($recoveryConfig)) "$Message (configuration missing from $($backup.Name))"
        Assert-Equal ([Convert]::ToBase64String($ExpectedBytes)) ([Convert]::ToBase64String([IO.File]::ReadAllBytes($recoveryConfig))) "$Message (configuration bytes changed)"
    }
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
    $sourceFiles = @(@($manifest.files | ForEach-Object { $_.source }) + @('SAF.json', 'scripts/init.ps1', 'scripts/publish-saf.ps1') | Select-Object -Unique)
    foreach ($relative in $sourceFiles) {
        $destination = Join-Path $source $relative
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($destination))
        [IO.File]::Copy((Join-Path $repositoryRoot $relative), $destination, $false)
    }
    # The source repository's own preferences are deliberately different from the
    # neutral consumer seed. They must never leak through bootstrap or update.
    Write-Json (Join-Path $source 'SAF.config.json') ([ordered]@{
        schemaVersion = 2; project = [ordered]@{ ui = [ordered]@{ framework = 'Source-only UI preferences must not leak' }; protectedPaths = @('source-private/') }
    })
    $initialCommit = Commit-Repository $source 'Initial SAF fixture release'
    Assert-Exit (Invoke-Script (Join-Path $source 'scripts/publish-saf.ps1') @('-Check')) 0 'Source fixture validates without changing release files.'

    $init = Join-Path $source 'scripts/init.ps1'
    $initArguments = @('-ProjectRoot', $project, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')
    Assert-Exit (Invoke-Script $init @('-ProjectRoot', (Join-Path $fixtureRoot 'missing project'), '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')) 1 'Bootstrap failures propagate a nonzero process exit.'
    Assert-Exit (Invoke-Script $init $initArguments) 0 'Bootstrap deploys usable handlers without a network source.'
    Assert-True (-not [IO.File]::Exists((Join-Path $source 'init.ps1'))) 'Source packaging retained a root bootstrap script.'
    Assert-True (-not [IO.File]::Exists((Join-Path $project 'init.ps1'))) 'Bootstrap installed an unexpected root init script.'
    foreach ($relative in @($manifest.bootstrapFiles)) { Assert-True ([IO.File]::Exists((Join-Path $project $relative))) "Bootstrap omitted $relative" }
    Assert-True (-not [IO.File]::Exists((Join-Path $project 'AGENTS.md'))) 'Bootstrap unexpectedly installed the framework payload.'
    $configPath = Join-Path $project 'SAF.config.json'
    $seedConfig = Read-Json $configPath
    Assert-Equal 1 @($seedConfig.PSObject.Properties).Count 'Bootstrap copied source preferences instead of the neutral configuration seed.'
    Assert-Equal 2 $seedConfig.schemaVersion 'Bootstrap omitted the supported configuration schema.'
    . (Join-Path $project 'scripts/saf-core.ps1')
    foreach ($configurationPresent in @($true, $false)) {
        if (-not $configurationPresent) { [IO.File]::Delete($configPath) }
        $defaults = Resolve-SafConfig -Root $project
        Assert-Equal 'deny' $defaults.project.verification.computerUse 'Computer Use must be denied by default.'
        Assert-Equal 'Material Design 3' $defaults.project.ui.framework 'The default UI framework was not resolved.'
        Assert-Equal 'follow-history' $defaults.project.commit.style 'The default commit style must follow project history.'
        Assert-Equal 'english-imperative' $defaults.project.commit.initialStyle 'The initial commit style default was not resolved.'
        foreach ($removed in @('name', 'delivery', 'records')) { Assert-True (-not $defaults.project.PSObject.Properties[$removed]) "Removed project field is still exposed: $removed" }
        Assert-True (-not $defaults.project.verification.PSObject.Properties['automatedTests']) 'Removed automatedTests preference is still exposed.'
    }
    $consumerConfig = [ordered]@{
        schemaVersion = 2
        project = [ordered]@{
            protectedPaths = @('README.md')
            verification = [ordered]@{ computerUse = 'inherit' }
            ui = [ordered]@{ framework = 'Consumer UI Kit' }
            commit = [ordered]@{ style = 'ticket-prefixed short subjects'; initialStyle = 'spanish imperative' }
        }
    }
    Write-Json $configPath $consumerConfig
    $customPreferences = Resolve-SafConfig -Root $project
    Assert-Equal 'inherit' $customPreferences.project.verification.computerUse 'An explicit Computer Use inheritance preference was not resolved.'
    Assert-Equal 'Consumer UI Kit' $customPreferences.project.ui.framework 'A custom nonempty UI framework string was not preserved.'
    Assert-Equal 'ticket-prefixed short subjects' $customPreferences.project.commit.style 'A custom nonempty commit style string was not preserved.'
    Assert-Equal 'spanish imperative' $customPreferences.project.commit.initialStyle 'A custom initial commit style string was not preserved.'
    $consumerConfigBytes = [IO.File]::ReadAllBytes($configPath)
    $lockPath = Join-Path $project 'SAF.lock.json'
    $state = Read-Json $lockPath
    Assert-True ($null -eq $state.installation) 'Bootstrap falsely recorded a payload installation.'
    Assert-True ($null -eq $state.audit -or $null -eq $state.audit.lastCompletedAtUtc) 'Bootstrap copied a completed central audit.'

    Write-Json $configPath ([ordered]@{ schemaVersion = 1 })
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check')) 1 'Legacy configuration schema 1 is rejected by the schema-2 handler.'
    Assert-Snapshot $before $project 'Legacy configuration rejection changed consumer files.'
    Assert-Exit (Invoke-Script $init $initArguments) 1 'Bootstrap does not silently replace an existing schema-1 configuration.'
    Assert-Snapshot $before $project 'Bootstrap replaced a legacy project-owned configuration.'
    foreach ($invalidConfig in @(
        [ordered]@{ schemaVersion = 99 },
        [ordered]@{ schemaVersion = '2' },
        [ordered]@{ schemaVersion = $true },
        [ordered]@{ schemaVersion = 2; unknown = $true },
        [ordered]@{ schemaVersion = 2; verification = [ordered]@{ computerUse = 'deny' } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ unknown = 'not a supported preference' } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ verification = [ordered]@{ computerUse = 'allow' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ verification = [ordered]@{ computerUse = @('deny') } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ name = 'removed project name' } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ verification = [ordered]@{ automatedTests = 'explicit-authorization' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ delivery = [ordered]@{ commit = 'ask' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ records = [ordered]@{ timeZone = 'UTC' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ ui = [ordered]@{ framework = '' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ ui = [ordered]@{ framework = 3 } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ ui = [ordered]@{ unknown = 'unsupported UI setting' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ commit = [ordered]@{ style = '   ' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ commit = [ordered]@{ style = $false } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ commit = [ordered]@{ initialStyle = '' } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ commit = [ordered]@{ initialStyle = @('not a string') } } },
        [ordered]@{ schemaVersion = 2; project = [ordered]@{ commit = [ordered]@{ unknown = 'unsupported commit setting' } } }
    )) {
        Write-Json $configPath $invalidConfig
        $before = Get-Snapshot $project
        Assert-Exit (Invoke-Origin @('-Check')) 1 'Invalid or unknown configuration is rejected without payload writes.'
        Assert-Snapshot $before $project 'Invalid configuration Check changed consumer state.'
        Assert-Exit (Invoke-Script $init $initArguments) 1 'Initialization refuses to replace an invalid existing project configuration.'
        Assert-Snapshot $before $project 'Invalid configuration initialization changed consumer state.'
    }
    foreach ($invalidRootJson in @('[{"schemaVersion":2}]', '"configuration"', '1', 'true', 'null', '[]')) {
        Write-Text $configPath $invalidRootJson
        $before = Get-Snapshot $project
        Assert-Exit (Invoke-Origin @('-Check')) 1 'Configuration roots must be objects, including rejection of singleton arrays.'
        Assert-Snapshot $before $project 'Invalid configuration root changed consumer state.'
        Assert-Exit (Invoke-Script $init $initArguments) 1 'Initialization rejects non-object existing configuration roots.'
        Assert-Snapshot $before $project 'Initialization replaced a non-object configuration root.'
    }
    [IO.File]::WriteAllBytes($configPath, $consumerConfigBytes)

    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check')) 2 'Fresh Check reports an available installation.'
    Assert-Snapshot $before $project 'Check changed files outside its log-only exception.'
    Assert-Exit (Invoke-Origin @('-Check', '-Update')) 1 'Mutually exclusive action flags are rejected.'
    Assert-Snapshot $before $project 'Invalid arguments changed framework state.'
    Assert-Exit (Invoke-Origin @('-Force')) 1 'Force without Update is rejected.'

    $syncBackupsBefore = @(Get-Backups $project | ForEach-Object { $_.FullName })
    Assert-Exit (Invoke-Origin @('-Sync')) 0 'Sync installs the release after checking.'
    Assert-ConfigRecovery $syncBackupsBefore $project $consumerConfigBytes 'Initial synchronization recovery includes exact project configuration.'
    Assert-Equal (Get-ByteHash $consumerConfigBytes) (Get-ByteHash ([IO.File]::ReadAllBytes($configPath))) 'Installation replaced project configuration with the source seed.'
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
            [pscustomobject]@{ relative = 'invalid-payload.txt'; bytes = $null; delete = $false }
        )
    } catch { $failedAsExpected = $true }
    Assert-True $failedAsExpected 'Transaction preflight did not reject an invalid null write payload.'
    Assert-True ([IO.File]::Exists($emptySnapshot)) 'Invalid-payload preflight removed an existing empty file.'
    Assert-Equal 0 ([IO.File]::ReadAllBytes($emptySnapshot).Length) 'Invalid-payload preflight changed existing empty-file bytes.'
    Assert-True (-not [IO.File]::Exists((Join-Path $project 'invalid-payload.txt'))) 'Invalid-payload preflight created a target file.'
    [IO.File]::Delete($emptySnapshot)
    $transactionProbe = Join-Path $fixtureRoot 'transaction-journal-probe.ps1'
    Write-Text $transactionProbe @'
#requires -Version 5.1
[CmdletBinding()]
param([string]$Root, [string]$Core, [ValidateSet('Unwritten', 'OwnedChanged', 'ExpectedChanged', 'CommittedThenThrow', 'DeleteRollback', 'DeleteRecreated', 'PrecommitSameBytes')][string]$Scenario)
$ErrorActionPreference = 'Stop'
. $Core
$encoding = New-Object Text.UTF8Encoding($false, $true)
$script:ProbeRoot = $Root
$script:ProbeScenario = $Scenario
$script:Injected = $false
$script:OriginalAtomic = (Get-Command Write-SafAtomic -CommandType Function).ScriptBlock
$script:FirstPath = Join-Path $Root 'first.txt'
$script:SecondPath = Join-Path $Root 'second.txt'
$script:ConfigPath = Join-Path $Root 'SAF.config.json'
$script:ExternalConfig = '{"schemaVersion":2,"project":{"protectedPaths":["second.txt"]}}'
if ($Scenario -in @('DeleteRollback', 'DeleteRecreated')) { [IO.File]::WriteAllBytes($script:FirstPath, [byte[]]@()) }
else { [IO.File]::WriteAllText($script:FirstPath, 'original first', $encoding) }
if ($Scenario -ne 'ExpectedChanged') { [IO.File]::WriteAllText($script:SecondPath, 'original second', $encoding) }
function Write-SafAtomic([string]$Path, [byte[]]$Bytes, [ValidateSet('Auto', 'Create', 'Replace')][string]$Mode = 'Auto', [ref]$Committed) {
    if ($null -ne $Committed) { $Committed.Value = $false }
    if ($script:ProbeScenario -eq 'PrecommitSameBytes' -and $Path -eq $script:FirstPath -and -not $script:Injected) {
        $script:Injected = $true
        [IO.File]::WriteAllBytes($Path, $Bytes)
        throw 'External identical bytes appeared before the transaction writer committed.'
    }
    if ($script:ProbeScenario -in @('DeleteRollback', 'DeleteRecreated') -and $Path -eq $script:SecondPath) {
        if ([IO.File]::Exists($script:FirstPath)) { throw 'The expected first-file deletion did not occur.' }
        $script:Injected = $true
        if ($script:ProbeScenario -eq 'DeleteRecreated') { [IO.File]::WriteAllText($script:FirstPath, 'external first', $encoding) }
        throw 'Injected failure before the second write after a completed deletion.'
    }
    if ($script:ProbeScenario -eq 'OwnedChanged' -and $Path -eq $script:SecondPath) { throw 'Injected second-write failure.' }
    $delegateArguments = @{ Path = $Path; Bytes = $Bytes; Mode = $Mode }
    if ($null -ne $Committed) { $delegateArguments.Committed = $Committed }
    & $script:OriginalAtomic @delegateArguments
    if (-not $script:Injected -and $Path -eq $script:FirstPath) {
        $script:Injected = $true
        if ($script:ProbeScenario -eq 'CommittedThenThrow') { throw 'Injected failure after atomic replacement committed.' }
        if ($script:ProbeScenario -eq 'OwnedChanged') {
            [IO.File]::WriteAllText($script:FirstPath, 'external first', $encoding)
        } else {
            [IO.File]::WriteAllText($script:SecondPath, 'external second', $encoding)
            if ($script:ProbeScenario -eq 'Unwritten') { [IO.File]::WriteAllText($script:ConfigPath, $script:ExternalConfig, $encoding) }
        }
    }
}
$secondExpected = if ([IO.File]::Exists($script:SecondPath)) { Get-SafByteHash ([IO.File]::ReadAllBytes($script:SecondPath)) } else { $null }
$deleteFirst = $Scenario -in @('DeleteRollback', 'DeleteRecreated')
$firstBytes = if ($deleteFirst) { $null } else { $encoding.GetBytes('transaction first') }
$operations = @(
    [pscustomobject]@{ relative = 'first.txt'; bytes = $firstBytes; delete = $deleteFirst; expected = Get-SafByteHash ([IO.File]::ReadAllBytes($script:FirstPath)) },
    [pscustomobject]@{ relative = 'second.txt'; bytes = $encoding.GetBytes('transaction second'); delete = $false; expected = $secondExpected }
)
if ($Scenario -eq 'Unwritten') {
    $operations += [pscustomobject]@{ relative = 'SAF.config.json'; bytes = $encoding.GetBytes('{"schemaVersion":2}'); delete = $false; expected = $null }
}
$aborted = $false
try { Invoke-SafTransaction -Root $Root -Operations $operations } catch { $aborted = $true }
if (-not $script:Injected -or -not $aborted) { throw 'The transaction did not reach and abort at the injected condition.' }
if ($Scenario -eq 'PrecommitSameBytes') {
    if ([IO.File]::ReadAllText($script:FirstPath, $encoding) -cne 'transaction first') { throw 'Rollback claimed externally written identical bytes without its own commit receipt.' }
    if ([IO.File]::ReadAllText($script:SecondPath, $encoding) -cne 'original second') { throw 'Precommit failure changed an unwritten second target.' }
} elseif ($Scenario -eq 'DeleteRollback') {
    if (-not [IO.File]::Exists($script:FirstPath) -or [IO.File]::ReadAllBytes($script:FirstPath).Length -ne 0) { throw 'Rollback did not restore the deleted zero-byte file.' }
    if ([IO.File]::ReadAllText($script:SecondPath, $encoding) -cne 'original second') { throw 'Delete rollback changed a second target that was never written.' }
} elseif ($Scenario -eq 'DeleteRecreated') {
    if ([IO.File]::ReadAllText($script:FirstPath, $encoding) -cne 'external first') { throw 'Delete rollback replaced an externally recreated file.' }
    if ([IO.File]::ReadAllText($script:SecondPath, $encoding) -cne 'original second') { throw 'Delete rollback changed a second target that was never written.' }
} elseif ($Scenario -eq 'CommittedThenThrow') {
    if ([IO.File]::ReadAllText($script:FirstPath, $encoding) -cne 'original first') { throw 'A committed write followed by an exception was not rolled back.' }
    if ([IO.File]::ReadAllText($script:SecondPath, $encoding) -cne 'original second') { throw 'Rollback touched a target that was never attempted.' }
} elseif ($Scenario -eq 'OwnedChanged') {
    if ([IO.File]::ReadAllText($script:FirstPath, $encoding) -cne 'external first') { throw 'Rollback overwrote a later external edit to an already-written file.' }
    if ([IO.File]::ReadAllText($script:SecondPath, $encoding) -cne 'original second') { throw 'Rollback changed the unwritten failure target.' }
} else {
    if ([IO.File]::ReadAllText($script:FirstPath, $encoding) -cne 'original first') { throw 'Rollback failed to restore transaction-owned bytes.' }
    if ([IO.File]::ReadAllText($script:SecondPath, $encoding) -cne 'external second') { throw 'The transaction or rollback replaced an externally changed unwritten target.' }
    if ($Scenario -eq 'Unwritten' -and (-not [IO.File]::Exists($script:ConfigPath) -or
        [IO.File]::ReadAllText($script:ConfigPath, $encoding) -cne $script:ExternalConfig)) { throw 'Rollback removed or replaced an externally created configuration.' }
}
'@
    foreach ($scenario in @('Unwritten', 'OwnedChanged', 'ExpectedChanged', 'CommittedThenThrow', 'DeleteRollback', 'DeleteRecreated', 'PrecommitSameBytes')) {
        $transactionRoot = Join-Path $fixtureRoot ('transaction-' + $scenario.ToLowerInvariant())
        Initialize-Repository $transactionRoot
        Assert-Exit (Invoke-Script $transactionProbe @('-Root', $transactionRoot, '-Core', $core, '-Scenario', $scenario)) 0 "Transaction recovery preserves ownership and external changes ($scenario)."
    }
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
    Write-Text (Join-Path $project '.gitignore') ".agents/backup/`n.agents/saf_log/`n.agents/operation.lock`n"
    [void](Commit-Repository $project 'Consumer facts and local configuration')
    [void](Invoke-Git @('-C', $project, 'remote', 'add', 'origin', 'https://example.invalid/consumer.git'))
    Write-Text (Join-Path $project 'unrelated-staged.txt') 'An unrelated staged change must remain staged.'
    [void](Invoke-Git @('-C', $project, 'add', '--', 'unrelated-staged.txt'))
    $gitState = Get-GitState $project

    $rulesSource = Join-Path $source 'docs-ai/common/rules.md'
    Write-Text $rulesSource ([IO.File]::ReadAllText($rulesSource, $utf8) + "`n<!-- Fixture release change. -->`n")
    $baseVersion = [version]($manifest.frameworkVersion.Split('-')[0])
    $patchVersion = "$($baseVersion.Major).$($baseVersion.Minor).$($baseVersion.Build + 1)"
    $publisher = Join-Path $source 'scripts/publish-saf.ps1'
    $manifestPath = Join-Path $source 'SAF.json'
    $originalHash = Get-ByteHash ([IO.File]::ReadAllBytes($manifestPath))
    Assert-Exit (Invoke-Script $publisher @('-Version', $patchVersion)) 1 'Publisher rejects a bare patch version.'
    Assert-Exit (Invoke-Script $publisher @('-Version', "$($baseVersion.Major).$($baseVersion.Minor + 1).0-alpha.1")) 1 'Publisher requires approval for a minor increment.'
    Assert-Exit (Invoke-Script $publisher @('-Version', "$($baseVersion.Major + 1).0.0-beta.1")) 1 'Publisher requires approval for a major increment.'
    Assert-Exit (Invoke-Script $publisher @('-Version', "$patchVersion-release")) 1 'Publisher requires approval for the release channel.'
    Assert-Equal $originalHash (Get-ByteHash ([IO.File]::ReadAllBytes($manifestPath))) 'Refused publication changed the source manifest.'
    $nextVersion = "$patchVersion-alpha.2"
    Assert-Exit (Invoke-Script $publisher @('-Version', $nextVersion)) 0 'Publisher prepares the next patch alpha without exceptional approval.'
    $nextCommit = Commit-Repository $source 'Compatible fixture upgrade'
    Assert-Exit (Invoke-Origin @('-Check')) 2 'Check detects the new release.'
    foreach ($protectedPath in @('docs-ai/common/rules.md', 'docs-ai/common/')) {
        $protectedConfig = Read-Json $configPath
        $protectedConfig.project.protectedPaths = @($protectedPath)
        Write-Json $configPath $protectedConfig
        $before = Get-Snapshot $project
        Assert-Exit (Invoke-Origin @('-Update', '-Force')) 1 'Project protected paths cannot be bypassed by Force.'
        Assert-Snapshot $before $project 'Protected-path update changed consumer files.'
    }
    [IO.File]::WriteAllBytes($configPath, $consumerConfigBytes)
    $syncBackupsBefore = @(Get-Backups $project | ForEach-Object { $_.FullName })
    Assert-Exit (Invoke-Origin @('-Sync')) 0 'Sync applies the checked release.'
    Assert-ConfigRecovery $syncBackupsBefore $project $consumerConfigBytes 'Compatible synchronization recovery includes exact project configuration.'
    $state = Read-Json $lockPath
    Assert-Equal $nextCommit $state.installation.commit 'Upgrade lost the resolved source commit.'
    Assert-Equal $nextVersion $state.installation.frameworkVersion 'Upgrade lost the release channel or iteration.'
    $downgradeArgs = @('-ProjectRoot', $project, '-SourcePath', $source, '-Repository', $source, '-Ref', $initialCommit, '-Check')
    Assert-Exit (Invoke-Script (Join-Path $project 'scripts/origin.ps1') $downgradeArgs) 1 'Check rejects a downgrade from a suffixed version.'
    Assert-Equal $auditJson ($state.audit | ConvertTo-Json -Compress) 'Upgrade rewrote audit evidence.'
    Assert-Equal (Get-ByteHash $consumerConfigBytes) (Get-ByteHash ([IO.File]::ReadAllBytes($configPath))) 'Update overwrote consumer configuration.'
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
    $forceVersion = "$patchVersion-alpha.10"
    Assert-Exit (Invoke-Script $publisher @('-Version', $forceVersion)) 0 'Publisher compares alpha iterations numerically within the same patch.'
    [void](Commit-Repository $source 'Conflicting fixture upgrade')
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Check')) 3 'Check identifies committed managed customizations.'
    Assert-Snapshot $before $project 'Conflict Check modified consumer data.'
    Assert-Exit (Invoke-Origin @('-Update')) 3 'Update refuses a managed conflict without Force.'
    Assert-Snapshot $before $project 'Refused update modified consumer data.'
    $forceBackupsBefore = @(Get-Backups $project | ForEach-Object { $_.FullName })
    Assert-Exit (Invoke-Origin @('-Update', '-Force')) 0 'Forced update backs up and replaces the managed conflict.'
    Assert-ConfigRecovery $forceBackupsBefore $project $consumerConfigBytes 'Forced update recovery includes exact project configuration.'
    Assert-Equal (Get-ByteHash $consumerConfigBytes) (Get-ByteHash ([IO.File]::ReadAllBytes($configPath))) 'Force overwrote consumer configuration.'
    Assert-GitState $gitState $project
    $matchingBackups = @(Get-ChildItem -LiteralPath (Join-Path $project '.agents/backup') -File -Recurse -Force | Where-Object {
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
    $badManifest.handlerProtocolVersion = 3
    $badManifest.configSupportVersion = 99
    Write-Json (Join-Path $badSource 'SAF.json') $badManifest
    [void](Commit-Repository $badSource 'Incompatible configuration support fixture')
    Assert-Exit (Invoke-Origin @('-Check') $badSource) 4 'Unsupported configuration support requests compatible handlers.'
    Assert-Snapshot $before $project 'Incompatible configuration support changed consumer data.'

    $validLockBytes = [IO.File]::ReadAllBytes($lockPath)
    $validLockJson = $utf8.GetString($validLockBytes)
    foreach ($invalidLockRoot in @(('[' + $validLockJson + ']'), '1', 'null', '"lock"')) {
        Write-Text $lockPath $invalidLockRoot
        $before = Get-Snapshot $project
        Assert-Exit (Invoke-Origin @('-Check')) 1 'Installation state roots must be objects, including rejection of singleton arrays.'
        Assert-Snapshot $before $project 'Invalid state root changed consumer files.'
        Assert-Exit (Invoke-Script $init $initArguments) 1 'Initialization rejects non-object existing lock roots without replacing them.'
        Assert-Snapshot $before $project 'Initialization replaced a non-object lock root.'
        [IO.File]::WriteAllBytes($lockPath, $validLockBytes)
    }
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

    $shapeSource = Join-Path $fixtureRoot 'json root shape source'
    [void](Invoke-Git @('-c', ('core.hooksPath=' + $emptyHooks), '-c', ('init.templateDir=' + $emptyHooks), 'clone', '--quiet', $source, $shapeSource))
    $shapeProject = Join-Path $fixtureRoot 'json root shape consumer'
    Initialize-Repository $shapeProject
    Assert-Exit (Invoke-Script $init @('-ProjectRoot', $shapeProject, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')) 0 'Prepare a handler-only consumer for release JSON-root checks.'
    $shapeManifestPath = Join-Path $shapeSource 'SAF.json'
    $objectManifestJson = [IO.File]::ReadAllText((Join-Path $source 'SAF.json'), $utf8)
    foreach ($invalidManifestRoot in @(('[' + $objectManifestJson + ']'), '1', 'null', '"manifest"')) {
        Write-Text $shapeManifestPath $invalidManifestRoot
        [void](Commit-Repository $shapeSource 'Non-object release manifest root fixture')
        Assert-Exit (Invoke-Script (Join-Path $shapeSource 'scripts/publish-saf.ps1') @('-Check')) 1 'Publisher rejects non-object manifest roots even when a singleton contains a valid release.'
        $before = Get-Snapshot $shapeProject
        Assert-Exit (Invoke-Origin @('-Update') $shapeSource $shapeProject) 1 'Synchronization rejects non-object manifest roots before installing files.'
        Assert-Snapshot $before $shapeProject 'Invalid manifest root changed the consumer.'
        Assert-Exit (Invoke-Script $init @('-ProjectRoot', $shapeProject, '-SourcePath', $shapeSource, '-Repository', $shapeSource, '-Ref', 'main')) 1 'Bootstrap rejects non-object manifest roots.'
        Assert-Snapshot $before $shapeProject 'Bootstrap accepted an invalid manifest root.'
    }
    foreach ($invalidSeedRoot in @('[{"schemaVersion":2}]', '1', 'null', '"seed"')) {
        $seedManifest = Read-Json (Join-Path $source 'SAF.json')
        $seedEntry = @($seedManifest.files | Where-Object { $_.target -eq 'SAF.config.json' })[0]
        $seedEntry.sha256 = Get-ByteHash ($utf8.GetBytes($invalidSeedRoot))
        Write-Text (Join-Path $shapeSource 'templates/SAF.config.json') $invalidSeedRoot
        Write-Json $shapeManifestPath $seedManifest
        [void](Commit-Repository $shapeSource 'Hash-valid non-object configuration seed fixture')
        Assert-Exit (Invoke-Script (Join-Path $shapeSource 'scripts/publish-saf.ps1') @('-Check')) 1 'Publisher rejects hash-valid non-object configuration seed roots.'
        $before = Get-Snapshot $shapeProject
        Assert-Exit (Invoke-Origin @('-Update') $shapeSource $shapeProject) 1 'Synchronization rejects hash-valid non-object configuration seeds.'
        Assert-Snapshot $before $shapeProject 'Invalid configuration seed root changed the consumer.'
        Assert-Exit (Invoke-Script $init @('-ProjectRoot', $shapeProject, '-SourcePath', $shapeSource, '-Repository', $shapeSource, '-Ref', 'main')) 1 'Bootstrap rejects hash-valid non-object configuration seeds.'
        Assert-Snapshot $before $shapeProject 'Bootstrap accepted an invalid configuration seed root.'
    }

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

    $missingConfigSource = Join-Path $fixtureRoot 'missing configuration seed source'
    [void](Invoke-Git @('-c', ('core.hooksPath=' + $emptyHooks), '-c', ('init.templateDir=' + $emptyHooks), 'clone', '--quiet', $source, $missingConfigSource))
    $missingConfigManifest = Read-Json (Join-Path $missingConfigSource 'SAF.json')
    $missingConfigManifest.files = @($missingConfigManifest.files | Where-Object { $_.target -ne 'SAF.config.json' })
    Write-Json (Join-Path $missingConfigSource 'SAF.json') $missingConfigManifest
    [void](Commit-Repository $missingConfigSource 'Missing configuration seed fixture')
    Assert-Exit (Invoke-Script (Join-Path $missingConfigSource 'scripts/publish-saf.ps1') @('-Check')) 1 'Publisher rejects a release without the project configuration seed.'
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Origin @('-Update') $missingConfigSource) 1 'A release without the configuration seed cannot update the project.'
    Assert-Snapshot $before $project 'Missing configuration seed update changed project state.'

    $badTemplateManifest = Read-Json (Join-Path $source 'SAF.json')
    $badTemplateEntry = @($badTemplateManifest.files | Where-Object { $_.target -eq 'SAF.config.json' })[0]
    $badTemplateEntry.source = 'SAF.config.json'
    $sourcePreferenceText = [IO.File]::ReadAllText((Join-Path $missingConfigSource 'SAF.config.json'), $utf8).TrimStart([char]0xFEFF).Replace("`r`n", "`n")
    $badTemplateEntry.sha256 = Get-ByteHash ($utf8.GetBytes($sourcePreferenceText))
    Write-Json (Join-Path $missingConfigSource 'SAF.json') $badTemplateManifest
    [void](Commit-Repository $missingConfigSource 'Invalid source-preference configuration seed fixture')
    Assert-Exit (Invoke-Script (Join-Path $missingConfigSource 'scripts/publish-saf.ps1') @('-Check')) 1 'Publisher rejects source project preferences masquerading as a consumer seed.'
    $neutralProject = Join-Path $fixtureRoot 'neutral seed consumer'
    Initialize-Repository $neutralProject
    Assert-Exit (Invoke-Script $init @('-ProjectRoot', $neutralProject, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')) 0 'Prepare a consumer for source-preference seed rejection.'
    [IO.File]::Delete((Join-Path $neutralProject 'SAF.config.json'))
    $before = Get-Snapshot $neutralProject
    Assert-Exit (Invoke-Origin @('-Update') $missingConfigSource $neutralProject) 1 'Synchronization refuses to inject source preferences when consumer configuration is absent.'
    Assert-Snapshot $before $neutralProject 'An invalid configuration seed changed the consumer.'

    $configProject = Join-Path $fixtureRoot 'configuration precedence consumer'
    Initialize-Repository $configProject
    Assert-Exit (Invoke-Script $init @('-ProjectRoot', $configProject, '-SourcePath', $source, '-Repository', $source, '-Ref', $initialCommit)) 0 'Bootstrap can retain an explicit source pin before project configuration is chosen.'
    $configOrigin = Join-Path $configProject 'scripts/origin.ps1'
    $configOriginArguments = @('-ProjectRoot', $configProject, '-SourcePath', $source)
    Assert-Exit (Invoke-Script $configOrigin ($configOriginArguments + @('-Sync'))) 0 'Unconfigured source selection retains the lock pin.'
    Assert-Equal $initialCommit (Read-Json (Join-Path $configProject 'SAF.lock.json')).installation.ref 'An absent config preference reset the requested source pin.'
    $configuredSource = [ordered]@{ schemaVersion = 2; origin = [ordered]@{ repository = $source; ref = 'main' } }
    Write-Json (Join-Path $configProject 'SAF.config.json') $configuredSource
    Assert-Exit (Invoke-Script $configOrigin ($configOriginArguments + @('-Check'))) 2 'An explicit configuration ref takes precedence over the previous lock pin.'
    Assert-Exit (Invoke-Script $configOrigin ($configOriginArguments + @('-Sync'))) 0 'Sync applies the explicitly configured branch.'
    Assert-Equal 'main' (Read-Json (Join-Path $configProject 'SAF.lock.json')).installation.ref 'Configured source ref was reset to the previous pin.'
    Assert-Exit (Invoke-Script $configOrigin ($configOriginArguments + @('-Check'))) 0 'Repeated calls keep the configured source selection.'
    $before = Get-Snapshot $configProject
    Assert-Exit (Invoke-Script $configOrigin ($configOriginArguments + @('-Check', '-Ref', $initialCommit))) 1 'An explicit command-line ref overrides the configured branch and preserves downgrade protection.'
    Assert-Snapshot $before $configProject 'Command-line source selection changed state during Check.'

    $installationJson = (Read-Json $lockPath).installation | ConvertTo-Json -Depth 40 -Compress
    Write-Text (Join-Path $project 'origin.bat') '@echo broken handler'
    Write-Text (Join-Path $project 'scripts/local.ps1') '# broken handler'
    Assert-Exit (Invoke-Script $init $initArguments) 0 'Reinitialization repairs the complete handler set.'
    $state = Read-Json $lockPath
    Assert-Equal $installationJson ($state.installation | ConvertTo-Json -Depth 40 -Compress) 'Handler repair changed payload installation state.'
    Assert-Equal $auditJson ($state.audit | ConvertTo-Json -Compress) 'Handler repair changed audit evidence.'
    Assert-Equal (Get-ByteHash $consumerConfigBytes) (Get-ByteHash ([IO.File]::ReadAllBytes($configPath))) 'Handler repair overwrote consumer configuration.'

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
    Assert-True ([IO.File]::Exists((Join-Path $newBackups[0].FullName 'files/SAF.config.json'))) 'Backup omitted the project configuration.'
    Assert-True ([IO.File]::Exists((Join-Path $newBackups[0].FullName 'files/.agents/skills/consumer-skill/SKILL.md'))) 'Unified runtime storage caused backup to omit project skills.'
    Assert-True (-not [IO.Directory]::Exists((Join-Path $newBackups[0].FullName 'files/.agents/backup'))) 'Backup recursively included previous recovery points.'
    Assert-True (-not [IO.Directory]::Exists((Join-Path $newBackups[0].FullName 'files/.agents/saf_log'))) 'Backup recursively included command logs.'
    Assert-True (-not [IO.File]::Exists((Join-Path $newBackups[0].FullName 'files/.agents/operation.lock'))) 'Backup included the live operation lock.'
    Assert-True (-not [IO.File]::Exists((Join-Path $newBackups[0].FullName 'files/unrelated-staged.txt'))) 'SAF recovery backup unexpectedly included unrelated source.'

    $archive = Join-Path $project 'docs-ai/current/1_archived'
    Write-Text (Join-Path $archive 'old-report.md') '# Superseded fixture report'
    Write-Text (Join-Path $archive '.hidden-report.md') '# Hidden archived evidence'
    $ancestorConfig = Read-Json $configPath
    $ancestorConfig.project.protectedPaths = @('exports')
    Write-Json $configPath $ancestorConfig
    $protectedExports = Join-Path $project 'exports'
    $before = Get-Snapshot $project
    Assert-Exit (Invoke-Script $local ($localArguments + @('-CleanArquived', '-Destination', $protectedExports))) 1 'Archive export cannot create a protected exact path as an intermediate directory.'
    Assert-True (-not [IO.Directory]::Exists($protectedExports)) 'Archive export created the protected ancestor directory.'
    Assert-Snapshot $before $project 'Protected ancestor export changed source reports or other files.'
    [IO.File]::WriteAllBytes($configPath, $consumerConfigBytes)

    $stateAncestorProject = Join-Path $fixtureRoot 'state ancestor consumer'
    Initialize-Repository $stateAncestorProject
    Write-Json (Join-Path $stateAncestorProject 'SAF.config.json') ([ordered]@{
        schemaVersion = 2; project = [ordered]@{ protectedPaths = @('.agents') }
    })
    $stateAncestorProbe = Join-Path $fixtureRoot 'state-ancestor-probe.ps1'
    Write-Text $stateAncestorProbe @'
#requires -Version 5.1
[CmdletBinding()]
param([string]$Root, [string]$Core)
$ErrorActionPreference = 'Stop'
. $Core
$refused = $false
try {
    Set-SafState -Root $Root -Section audit -Value ([pscustomobject]@{
        auditedFrameworkVersion = $null; lastMissingMaterialAskedAtUtc = $null; lastCompletedAtUtc = $null
    })
} catch { $refused = $true }
if (-not $refused) { throw 'State writing ignored a protected missing operation-lock ancestor.' }
if ([IO.Directory]::Exists((Join-Path $Root '.agents'))) { throw 'State writing created the protected operation-lock ancestor.' }
if ([IO.File]::Exists((Join-Path $Root 'SAF.lock.json'))) { throw 'Refused state writing created a lock state file.' }
'@
    Assert-Exit (Invoke-Script $stateAncestorProbe @('-Root', $stateAncestorProject, '-Core', $core)) 0 'State writing refuses a protected missing coordination directory before creating files.'
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

    $storageProject = Join-Path $fixtureRoot 'runtime migration consumer'
    Initialize-Repository $storageProject
    $storageInitArguments = @('-ProjectRoot', $storageProject, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')
    Assert-Exit (Invoke-Script $init $storageInitArguments) 0 'Prepare a consumer for legacy runtime storage migration.'
    $oldBackupFile = Join-Path $storageProject '.agent/backup/old-snapshot/files/evidence.md'
    $newBackupFile = Join-Path $storageProject '.agents/backup/old-snapshot/files/evidence.md'
    Write-Text $oldBackupFile 'Original backup evidence must survive migration.'
    Write-Json (Join-Path $storageProject '.agent/backup/old-snapshot/inventory.json') ([ordered]@{ schemaVersion = 1; files = @() })
    $legacyLog = Join-Path $storageProject '.agent/saf_log/2000-01-01.jsonl'
    $currentLog = Join-Path $storageProject '.agents/saf_log/2000-01-01.jsonl'
    Write-Text $legacyLog "{`"fixture`":`"legacy log`"}`n"
    Write-Text $currentLog "{`"fixture`":`"current log`"}`n"
    $legacyLogHash = Get-ByteHash ([IO.File]::ReadAllBytes($legacyLog))
    $currentLogHash = Get-ByteHash ([IO.File]::ReadAllBytes($currentLog))
    $legacyOperationLock = Join-Path $storageProject '.agent/operation.lock'
    [IO.File]::WriteAllBytes($legacyOperationLock, [byte[]]@())
    Write-Text (Join-Path $storageProject '.agent/user-owned.txt') 'Unknown legacy storage content is not disposable.'
    $before = Get-Snapshot $storageProject
    Assert-Exit (Invoke-Origin @('-Check') $source $storageProject) 2 'Check reports availability without migrating old runtime storage.'
    Assert-Snapshot $before $storageProject 'Check moved legacy runtime storage.'
    Assert-Exit (Invoke-Script $init $storageInitArguments) 0 'Initialization migrates old backups, logs, and idle operation locks.'
    Assert-True ([IO.File]::Exists($newBackupFile)) 'Legacy backup did not reach unified storage.'
    Assert-Equal 'Original backup evidence must survive migration.' ([IO.File]::ReadAllText($newBackupFile, $utf8)) 'Legacy backup bytes were lost.'
    Assert-True (-not [IO.File]::Exists($oldBackupFile)) 'Completed migration left the same old backup file active.'
    Assert-Equal $currentLogHash (Get-ByteHash ([IO.File]::ReadAllBytes($currentLog))) 'Legacy log collision replaced the existing destination log.'
    $preservedLegacyLogs = @(Get-ChildItem -LiteralPath (Join-Path $storageProject '.agents/saf_log') -File -Recurse -Force | Where-Object {
        (Get-ByteHash ([IO.File]::ReadAllBytes($_.FullName))) -eq $legacyLogHash
    })
    Assert-True ($preservedLegacyLogs.Count -ge 1) 'Date-colliding legacy log was not preserved under a separate name.'
    Assert-True (-not [IO.File]::Exists($legacyOperationLock)) 'Migrated idle operation lock was left active in the old directory.'
    Assert-True ([IO.File]::Exists((Join-Path $storageProject '.agent/user-owned.txt'))) 'Migration removed unknown user-owned legacy content.'

    $protectedLockProject = Join-Path $fixtureRoot 'protected legacy lock consumer'
    Initialize-Repository $protectedLockProject
    $protectedLockInitArguments = @('-ProjectRoot', $protectedLockProject, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')
    Assert-Exit (Invoke-Script $init $protectedLockInitArguments) 0 'Prepare a consumer with a project-protected legacy operation lock.'
    Write-Json (Join-Path $protectedLockProject 'SAF.config.json') ([ordered]@{
        schemaVersion = 2; project = [ordered]@{ protectedPaths = @('.agent/operation.lock') }
    })
    $protectedLegacyLock = Join-Path $protectedLockProject '.agent/operation.lock'
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($protectedLegacyLock))
    [IO.File]::WriteAllBytes($protectedLegacyLock, [byte[]]@())
    Assert-Exit (Invoke-Script $init $protectedLockInitArguments) 0 'A protected idle legacy lock permits the operation lease without authorizing its deletion.'
    Assert-True ([IO.File]::Exists($protectedLegacyLock)) 'Lease disposal deleted a project-protected legacy operation lock.'
    Assert-Equal 0 ([IO.File]::ReadAllBytes($protectedLegacyLock).Length) 'Lease disposal changed protected legacy lock bytes.'

    $oldCollision = Join-Path $storageProject '.agent/backup/collision/files/evidence.md'
    $newCollision = Join-Path $storageProject '.agents/backup/collision/files/evidence.md'
    Write-Text $oldCollision 'Legacy conflicting evidence.'
    Write-Text $newCollision 'Current conflicting evidence.'
    $oldCollisionHash = Get-ByteHash ([IO.File]::ReadAllBytes($oldCollision))
    $newCollisionHash = Get-ByteHash ([IO.File]::ReadAllBytes($newCollision))
    $storageLock = Join-Path $storageProject 'SAF.lock.json'
    $storageLockHash = Get-ByteHash ([IO.File]::ReadAllBytes($storageLock))
    Assert-Exit (Invoke-Script $init $storageInitArguments) 1 'Conflicting backup destinations stop migration without choosing a winner.'
    Assert-Equal $oldCollisionHash (Get-ByteHash ([IO.File]::ReadAllBytes($oldCollision))) 'Backup conflict lost the legacy bytes.'
    Assert-Equal $newCollisionHash (Get-ByteHash ([IO.File]::ReadAllBytes($newCollision))) 'Backup conflict lost the destination bytes.'
    Assert-Equal $storageLockHash (Get-ByteHash ([IO.File]::ReadAllBytes($storageLock))) 'Failed storage migration changed installation state.'

    $linkedProject = Join-Path $fixtureRoot 'linked runtime consumer'
    $externalStore = Join-Path $fixtureRoot 'external runtime evidence'
    Initialize-Repository $linkedProject
    $linkedInitArguments = @('-ProjectRoot', $linkedProject, '-SourcePath', $source, '-Repository', $source, '-Ref', 'main')
    Assert-Exit (Invoke-Script $init $linkedInitArguments) 0 'Prepare a consumer for linked legacy storage rejection.'
    [void][IO.Directory]::CreateDirectory($externalStore)
    Write-Text (Join-Path $externalStore 'external.md') 'Migration must not write through this link.'
    [void][IO.Directory]::CreateDirectory((Join-Path $linkedProject '.agent'))
    $legacyLink = Join-Path $linkedProject '.agent/backup'
    $createdLink = $false
    try {
        try {
            if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
                [void](New-Item -ItemType Junction -Path $legacyLink -Target $externalStore -ErrorAction Stop)
            } else { [void](New-Item -ItemType SymbolicLink -Path $legacyLink -Target $externalStore -ErrorAction Stop) }
            $createdLink = $true
        } catch { Write-Host ('SKIP: Link creation unavailable: ' + $_.Exception.Message) }
        if ($createdLink) {
            $externalHash = Get-ByteHash ([IO.File]::ReadAllBytes((Join-Path $externalStore 'external.md')))
            $linkedLockPath = Join-Path $linkedProject 'SAF.lock.json'
            $linkedLockHash = Get-ByteHash ([IO.File]::ReadAllBytes($linkedLockPath))
            Assert-Exit (Invoke-Script $init $linkedInitArguments) 1 'Linked legacy runtime storage is refused before migration.'
            Assert-Equal $externalHash (Get-ByteHash ([IO.File]::ReadAllBytes((Join-Path $externalStore 'external.md')))) 'Migration changed external linked storage.'
            Assert-Equal $linkedLockHash (Get-ByteHash ([IO.File]::ReadAllBytes($linkedLockPath))) 'Linked storage refusal changed installation state.'
        }
    } finally { if ($createdLink) { [IO.Directory]::Delete($legacyLink) } }

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
