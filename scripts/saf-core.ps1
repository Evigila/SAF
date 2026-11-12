#requires -Version 5.1
# Shared repository-local primitives; dot-source, do not execute a remote controller.
Set-StrictMode -Version Latest
$script:SafUtf8 = New-Object Text.UTF8Encoding($false, $true)
$script:SafOperationLocks = @{}
$script:SafStartedAtUtc = [DateTime]::UtcNow.ToString('o')
$script:SafOperationId = [Guid]::NewGuid().ToString('N')
$script:SafHandlers = @('origin.bat', 'local.bat', 'scripts/origin.ps1', 'scripts/local.ps1', 'scripts/saf-core.ps1')

function Get-SafByteHash([byte[]]$Bytes) {
    $algorithm = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($algorithm.ComputeHash($Bytes))).Replace('-', '').ToLowerInvariant() }
    finally { $algorithm.Dispose() }
}

function Get-SafHash([byte[]]$Bytes) {
    return Get-SafByteHash ($script:SafUtf8.GetBytes($script:SafUtf8.GetString($Bytes).TrimStart([char]0xFEFF).Replace("`r`n", "`n")))
}

function Read-SafJson([byte[]]$Bytes) {
    $value = $script:SafUtf8.GetString($Bytes).TrimStart([char]0xFEFF)
    if ((Get-Command ConvertFrom-Json).Parameters.ContainsKey('DateKind')) { return ConvertFrom-Json -InputObject $value -DateKind String }
    return ConvertFrom-Json -InputObject $value
}

function ConvertTo-SafBytes($Value) { return ,$script:SafUtf8.GetBytes(($Value | ConvertTo-Json -Depth 30) + "`n") }

function ConvertTo-SafArgument([string]$Value) {
    $builder = New-Object Text.StringBuilder
    [void]$builder.Append('"'); $slashes = 0
    foreach ($character in $Value.ToCharArray()) {
        if ($character -eq '\') { $slashes++; continue }
        if ($character -eq '"') { [void]$builder.Append(('\' * (2 * $slashes + 1))) }
        else { [void]$builder.Append(('\' * $slashes)) }
        [void]$builder.Append($character); $slashes = 0
    }
    [void]$builder.Append(('\' * (2 * $slashes))); [void]$builder.Append('"')
    return $builder.ToString()
}

function Invoke-SafGit([string[]]$Arguments, [switch]$Text) {
    $start = New-Object Diagnostics.ProcessStartInfo
    $start.FileName = 'git'
    $start.Arguments = (($Arguments | ForEach-Object { ConvertTo-SafArgument $_ }) -join ' ')
    $start.UseShellExecute = $false; $start.CreateNoWindow = $true
    $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true
    $start.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
    $process = New-Object Diagnostics.Process; $process.StartInfo = $start
    $buffer = New-Object IO.MemoryStream
    try {
        [void]$process.Start(); $errorTask = $process.StandardError.ReadToEndAsync()
        $process.StandardOutput.BaseStream.CopyTo($buffer); $process.WaitForExit()
        # Do not echo a native error that may contain credentials in a source URL.
        if ($process.ExitCode -ne 0) { throw "Git operation failed (exit $($process.ExitCode)). Check source access and ref." }
        [void]$errorTask.Result
        if ($Text) { return $script:SafUtf8.GetString($buffer.ToArray()).Trim() }
        return ,$buffer.ToArray()
    } finally { $buffer.Dispose(); $process.Dispose() }
}

function Assert-SafRelative([string]$Relative) {
    if ([string]::IsNullOrWhiteSpace($Relative) -or $Relative -match '[\\:<>"|?*\x00-\x1f]' -or $Relative.StartsWith('/') -or
        $Relative.EndsWith('/') -or @($Relative.Split('/') | Where-Object {
            $_ -in @('', '.', '..', '.git') -or $_ -match '[. ]$' -or $_ -match '^(?i:CON|PRN|AUX|NUL|COM[0-9]|LPT[0-9])(?:\.|$)'
        }).Count -gt 0) { throw "Invalid SAF relative path: $Relative" }
}

function Get-SafTarget([string]$Root, [string]$Relative) {
    Assert-SafRelative $Relative
    $base = [IO.Path]::GetFullPath($Root).TrimEnd([char]92, [char]47)
    $target = [IO.Path]::GetFullPath((Join-Path $base $Relative))
    if (-not $target.StartsWith($base + [IO.Path]::DirectorySeparatorChar, [StringComparison]::OrdinalIgnoreCase)) { throw 'SAF path escapes project root.' }
    $cursor = $target
    while ($cursor) {
        if (Test-Path -LiteralPath $cursor) {
            $item = Get-Item -LiteralPath $cursor -Force
            if (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw "Refusing linked path: $cursor" }
        }
        $cursor = [IO.Path]::GetDirectoryName($cursor)
    }
    return $target
}

function Get-SafRoot([string]$ProjectRoot) {
    $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd([char]92, [char]47)
    if (-not [IO.Directory]::Exists($root)) { throw 'ProjectRoot must be an existing directory.' }
    $gitRoot = Invoke-SafGit -Arguments @('-C', $root, 'rev-parse', '--show-toplevel') -Text
    if (-not $root.Equals([IO.Path]::GetFullPath($gitRoot).TrimEnd([char]92, [char]47), [StringComparison]::OrdinalIgnoreCase)) { throw 'Use the target Git repository root.' }
    [void](Get-SafTarget -Root $root -Relative 'SAF.lock.json')
    return $root
}

function Assert-SafRepository([string]$Repository) {
    if ([string]::IsNullOrWhiteSpace($Repository) -or $Repository.StartsWith('-')) { throw 'Invalid source repository.' }
    $uri = $null
    if ([Uri]::TryCreate($Repository, [UriKind]::Absolute, [ref]$uri) -and $uri.Scheme -in @('http', 'https') -and
        ($uri.UserInfo -or $uri.Query -or $uri.Fragment)) { throw 'Use a credential-free repository URL; authentication belongs in the existing Git credential helper.' }
}

function Get-SafFiles([string]$Root, [string]$Relative) {
    $path = Get-SafTarget -Root $Root -Relative $Relative
    if (-not (Test-Path -LiteralPath $path)) { return }
    if ([IO.File]::Exists($path)) { return $Relative }
    foreach ($child in Get-ChildItem -LiteralPath $path -Force) {
        $childRelative = $Relative + '/' + $child.Name
        [void](Get-SafTarget -Root $Root -Relative $childRelative)
        if ($child.PSIsContainer) { Get-SafFiles -Root $Root -Relative $childRelative }
        else { $childRelative }
    }
}

function Assert-SafManaged([string]$Relative, [switch]$Legacy) {
    Assert-SafRelative $Relative
    if ($Relative -in (@('AGENTS.md', 'SAF.json') + $script:SafHandlers) -or
        $Relative.StartsWith('docs-ai/common/', [StringComparison]::Ordinal) -or
        $Relative.StartsWith('.agents/skills/', [StringComparison]::Ordinal)) { return }
    if ($Legacy -and $Relative -in @('AGENTS.framework.json', 'fetch-agents.bat', 'scripts/fetch-agents.ps1')) { return }
    throw "Path is outside SAF ownership: $Relative"
}

function Get-SafExistingHash([string]$Path, [switch]$Raw) {
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    if (-not [IO.File]::Exists($Path)) { throw "Expected a regular file: $Path" }
    $bytes = [IO.File]::ReadAllBytes($Path)
    if ($Raw) { return Get-SafByteHash $bytes }
    try { return Get-SafHash $bytes } catch [Text.DecoderFallbackException] { return '(invalid UTF-8)' }
}

function Enter-SafOperation([string]$Root) {
    $path = Get-SafTarget -Root $Root -Relative '.agent/operation.lock'
    [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
    try { $stream = [IO.File]::Open($path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None) }
    catch { throw 'Another SAF operation is running, or the operation lock is inaccessible. Retry after it finishes.' }
    $script:SafOperationLocks[$Root] = $stream
    return $stream
}

function Read-SafState([string]$Root) {
    $statePath = Get-SafTarget -Root $Root -Relative 'SAF.lock.json'
    $legacyPaths = @('AGENTS.lock.json', 'AGENTS.ensure.json')
    if ([IO.File]::Exists($statePath)) {
        $state = Read-SafJson ([IO.File]::ReadAllBytes($statePath))
        if ($state.schemaVersion -ne 1 -or -not $state.PSObject.Properties['bootstrap'] -or
            -not $state.PSObject.Properties['installation'] -or -not $state.PSObject.Properties['audit']) { throw 'Invalid SAF.lock.json schema.' }
        if ($state.PSObject.Properties['migration'] -and $state.migration) {
            if (-not $state.migration.PSObject.Properties['legacyHashes']) { throw 'Invalid migration state.' }
            foreach ($property in $state.migration.legacyHashes.PSObject.Properties) {
                if ($property.Name -notin $legacyPaths -or $property.Value -notmatch '^[0-9a-f]{64}$') { throw 'Invalid legacy metadata ownership.' }
            }
        }
        foreach ($relative in $legacyPaths) {
            $path = Get-SafTarget -Root $Root -Relative $relative
            if ([IO.File]::Exists($path)) {
                if (-not $state.PSObject.Properties['migration'] -or -not $state.migration -or
                    -not $state.migration.legacyHashes.PSObject.Properties[$relative] -or
                    (Get-SafExistingHash $path -Raw) -ne $state.migration.legacyHashes.$relative) { throw "Conflicting legacy and SAF state: $relative" }
            }
        }
        return $state
    }
    $state = [pscustomobject][ordered]@{ schemaVersion = 1; bootstrap = $null; installation = $null; audit = [pscustomobject]@{
        auditedFrameworkVersion = $null; lastMissingMaterialAskedAtUtc = $null; lastCompletedAtUtc = $null
    } }
    $legacyHashes = [ordered]@{}
    foreach ($relative in $legacyPaths) {
        $path = Get-SafTarget -Root $Root -Relative $relative
        if (-not [IO.File]::Exists($path)) { continue }
        $legacy = Read-SafJson ([IO.File]::ReadAllBytes($path))
        $legacyHashes[$relative] = Get-SafExistingHash $path -Raw
        if ($relative -eq 'AGENTS.lock.json') {
            if ($legacy.schemaVersion -ne 1 -or $legacy.frameworkVersion -notmatch '^\d+\.\d+\.\d+$' -or
                $legacy.commit -notmatch '^[0-9a-f]{40}$' -or $legacy.manifestSha256 -notmatch '^[0-9a-f]{64}$') { throw 'Invalid legacy installation state.' }
            $state.installation = $legacy
        } else {
            if ($legacy.schemaVersion -ne 2) { throw 'Unsupported legacy audit schema; resolve it before migrating.' }
            $state.audit = [pscustomobject]@{ auditedFrameworkVersion = $legacy.auditedFrameworkVersion
                lastMissingMaterialAskedAtUtc = $legacy.lastMissingMaterialAskedAtUtc; lastCompletedAtUtc = $legacy.lastCompletedAtUtc }
        }
    }
    if ($legacyHashes.Count -gt 0) { $state | Add-Member -NotePropertyName migration -NotePropertyValue ([pscustomobject]@{ legacyHashes = [pscustomobject]$legacyHashes }) }
    return $state
}

function Write-SafAtomic([string]$Path, [byte[]]$Bytes) {
    $temporary = $Path + '.' + [Guid]::NewGuid().ToString('N') + '.tmp'
    try {
        [IO.File]::WriteAllBytes($temporary, $Bytes)
        if ([IO.File]::Exists($Path)) { [IO.File]::Replace($temporary, $Path, [NullString]::Value) }
        else { [IO.File]::Move($temporary, $Path) }
    } finally { if ([IO.File]::Exists($temporary)) { [IO.File]::Delete($temporary) } }
}

function Invoke-SafTransaction([string]$Root, [object[]]$Operations) {
    $snapshots = @{}; $parents = New-Object 'Collections.Generic.List[string]'
    foreach ($operation in $Operations) {
        $path = Get-SafTarget -Root $Root -Relative $operation.relative
        if ($snapshots.ContainsKey($path)) { throw "Duplicate transaction path: $($operation.relative)" }
        $actual = Get-SafExistingHash $path -Raw
        if ($operation.PSObject.Properties['expected'] -and $actual -ne $operation.expected) { throw "File changed during planning: $($operation.relative)" }
        if ($null -ne $actual) { $snapshots[$path] = [IO.File]::ReadAllBytes($path) }
        else { $snapshots[$path] = $null }
    }
    try {
        foreach ($operation in $Operations) {
            $path = Get-SafTarget -Root $Root -Relative $operation.relative
            $parent = [IO.Path]::GetDirectoryName($path); $missing = New-Object 'Collections.Generic.List[string]'
            while (-not [IO.Directory]::Exists($parent)) { $missing.Add($parent); $parent = [IO.Path]::GetDirectoryName($parent) }
            for ($i = $missing.Count - 1; $i -ge 0; $i--) { [void][IO.Directory]::CreateDirectory($missing[$i]); $parents.Add($missing[$i]) }
            if ($operation.delete) { [IO.File]::Delete($path) } else { Write-SafAtomic -Path $path -Bytes $operation.bytes }
        }
    } catch {
        $failure = $_
        foreach ($path in $snapshots.Keys) {
            try {
                $relative = $path.Substring($Root.Length + 1).Replace([char]92, [char]47)
                [void](Get-SafTarget -Root $Root -Relative $relative)
                if ($null -eq $snapshots[$path]) { if ([IO.File]::Exists($path)) { [IO.File]::Delete($path) } }
                else { Write-SafAtomic -Path $path -Bytes $snapshots[$path] }
            } catch { Write-Warning "Recovery needs manual review: $path" }
        }
        for ($i = $parents.Count - 1; $i -ge 0; $i--) {
            if ([IO.Directory]::Exists($parents[$i]) -and @(Get-ChildItem -LiteralPath $parents[$i] -Force).Count -eq 0) { [IO.Directory]::Delete($parents[$i]) }
        }
        throw $failure
    }
}

function Set-SafState([string]$Root, [ValidateSet('bootstrap', 'installation', 'audit')][string]$Section, $Value) {
    $lease = $null
    if (-not $script:SafOperationLocks.ContainsKey($Root) -or -not $script:SafOperationLocks[$Root].CanWrite) { $lease = Enter-SafOperation -Root $Root }
    try {
        $state = Read-SafState -Root $Root; $state.$Section = $Value
        $path = Get-SafTarget -Root $Root -Relative 'SAF.lock.json'
        Invoke-SafTransaction -Root $Root -Operations @([pscustomobject]@{ relative = 'SAF.lock.json'; bytes = ConvertTo-SafBytes $state
            delete = $false; expected = Get-SafExistingHash $path -Raw })
    } finally { if ($lease) { $lease.Dispose() } }
}

function New-SafBackup([string]$Root, [string[]]$RelativePaths, [string]$Reason) {
    $relativeBase = '.agent/backup/' + [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ') + '-' + [Guid]::NewGuid().ToString('N')
    $base = Get-SafTarget -Root $Root -Relative $relativeBase
    $items = New-Object 'Collections.Generic.List[object]'
    foreach ($relative in @($RelativePaths | Sort-Object -Unique)) {
        if ($relative.StartsWith('.agent/', [StringComparison]::OrdinalIgnoreCase)) { throw 'Backup cannot contain local runtime storage.' }
        $source = Get-SafTarget -Root $Root -Relative $relative
        if (-not [IO.File]::Exists($source)) { continue }
        $bytes = [IO.File]::ReadAllBytes($source)
        $target = Get-SafTarget -Root $Root -Relative ($relativeBase + '/files/' + $relative)
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($target))
        [IO.File]::WriteAllBytes($target, $bytes)
        if ((Get-SafByteHash ([IO.File]::ReadAllBytes($target))) -ne (Get-SafByteHash $bytes)) { throw 'Backup verification failed.' }
        $items.Add([pscustomobject]@{ path = $relative; sha256 = Get-SafByteHash $bytes; size = $bytes.Length })
    }
    [void][IO.Directory]::CreateDirectory($base)
    [IO.File]::WriteAllBytes((Join-Path $base 'inventory.json'), (ConvertTo-SafBytes ([ordered]@{
        schemaVersion = 1; createdAtUtc = [DateTime]::UtcNow.ToString('o'); reason = $Reason; files = @($items.ToArray())
    })))
    return $base
}

function Write-SafLog([string]$Root, [string]$Action, [string]$Result, [int]$ExitCode, $Data) {
    try {
        $path = Get-SafTarget -Root $Root -Relative ('.agent/saf_log/' + [DateTime]::UtcNow.ToString('yyyy-MM-dd') + '.jsonl')
        [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
        # Callers supply only relative paths/status data, never arbitrary argv or remote URLs.
        $line = ([ordered]@{ schemaVersion = 1; operationId = $script:SafOperationId; startedAtUtc = $script:SafStartedAtUtc; completedAtUtc = [DateTime]::UtcNow.ToString('o')
            action = $Action; result = $Result; exitCode = $ExitCode; data = $Data } | ConvertTo-Json -Compress -Depth 12) + "`n"
        $stream = [IO.File]::Open($path, [IO.FileMode]::Append, [IO.FileAccess]::Write, [IO.FileShare]::Read)
        try { $bytes = $script:SafUtf8.GetBytes($line); $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    } catch { Write-Warning 'SAF operation log could not be written; the reported operation result is unchanged.' }
}

function Get-SafRuntimeIgnoreOperation([string]$Root) {
    $path = Get-SafTarget -Root $Root -Relative '.gitignore'
    $body = if ([IO.File]::Exists($path)) { [IO.File]::ReadAllText($path, $script:SafUtf8) } else { '' }
    $lines = @($body.Replace("`r`n", "`n").Split("`n"))
    $missing = @(@('/.agent/backup/', '/.agent/saf_log/', '/.agent/operation.lock') | Where-Object { $_ -cnotin $lines })
    if ($missing.Count -eq 0) { return $null }
    if ($body.Length -gt 0 -and -not $body.EndsWith("`n")) { $body += "`n" }
    $body += ($missing -join "`n") + "`n"
    return [pscustomobject]@{ relative = '.gitignore'; bytes = $script:SafUtf8.GetBytes($body); delete = $false; expected = Get-SafExistingHash $path -Raw }
}

function Read-SafBlob([string]$Source, [string]$Commit, [string]$Relative) {
    Assert-SafRelative $Relative
    $tree = Invoke-SafGit -Arguments @('-C', $Source, 'ls-tree', $Commit, '--', $Relative) -Text
    if ($tree -notmatch '^(100644|100755) blob [0-9a-f]{40}\t') { throw "Source is not a regular Git blob: $Relative" }
    return ,(Invoke-SafGit -Arguments @('-C', $Source, 'show', ($Commit + ':' + $Relative)))
}

function Get-SafRelease([string]$Root, [string]$Repository, [string]$Ref, [string]$SourcePath) {
    $temporary = $null
    try {
        Assert-SafRepository $Repository
        if (-not $Ref -or $Ref.StartsWith('-')) { throw 'Invalid source ref.' }
        if ($SourcePath) {
            $source = [IO.Path]::GetFullPath($SourcePath)
            if ($source.Equals($Root, [StringComparison]::OrdinalIgnoreCase)) { throw 'SourcePath cannot equal the target repository.' }
            $commit = Invoke-SafGit -Arguments @('-C', $source, 'rev-parse', ($Ref + '^{commit}')) -Text
        } else {
            $temporary = Join-Path ([IO.Path]::GetTempPath()) ('saf-source-' + [Guid]::NewGuid().ToString('N'))
            [void](Invoke-SafGit -Arguments @('init', '--bare', '--quiet', $temporary))
            [void](Invoke-SafGit -Arguments @('-C', $temporary, 'fetch', '--quiet', '--depth=1', '--no-tags', $Repository, $Ref))
            $source = $temporary; $commit = Invoke-SafGit -Arguments @('-C', $source, 'rev-parse', 'FETCH_HEAD^{commit}') -Text
        }
        if ($commit -notmatch '^[0-9a-f]{40}$') { throw 'Source must resolve to one Git commit.' }
        $manifestBytes = Read-SafBlob -Source $source -Commit $commit -Relative 'SAF.json'
        $manifest = Read-SafJson $manifestBytes
        if ($manifest.schemaVersion -ne 1 -or $manifest.handlerProtocolVersion -ne 1) { throw '[SAF_REFRESH] Unsupported SAF contract. Rerun init.ps1.' }
        if ($manifest.frameworkVersion -notmatch '^\d+\.\d+\.\d+$' -or [version]$manifest.frameworkVersion -lt [version]'2.0.0') { throw 'Expected a SAF release version >= 2.0.0.' }
        $payload = @{}
        foreach ($entry in @($manifest.files)) {
            Assert-SafRelative $entry.source; Assert-SafRelative $entry.target
            if ($payload.ContainsKey($entry.target) -or $entry.target -in @('SAF.json', 'SAF.lock.json')) { throw 'Duplicate or reserved SAF target.' }
            if ($entry.mode -eq 'managed') { Assert-SafManaged $entry.target }
            elseif ($entry.mode -eq 'seed') {
                if ($entry.target -notin @('debug.bat', 'docs/.gitkeep') -and -not $entry.target.StartsWith('docs-ai/current/', [StringComparison]::Ordinal)) { throw 'Invalid seed target.' }
            } else { throw 'Unknown SAF file mode.' }
            if ($entry.sha256 -notmatch '^[0-9a-f]{64}$') { throw 'Invalid SAF payload hash.' }
            $bytes = Read-SafBlob -Source $source -Commit $commit -Relative $entry.source
            if ((Get-SafHash $bytes) -ne $entry.sha256) { throw "SAF payload hash mismatch: $($entry.source)" }
            $payload[$entry.target] = [pscustomobject]@{ mode = $entry.mode; hash = $entry.sha256; bytes = $bytes }
        }
        if (@($manifest.bootstrapFiles).Count -ne $script:SafHandlers.Count -or
            @(Compare-Object ($script:SafHandlers | Sort-Object) (@($manifest.bootstrapFiles) | Sort-Object)).Count -ne 0) { throw 'Invalid bootstrap handler set.' }
        foreach ($required in ($script:SafHandlers + @('AGENTS.md', 'docs-ai/common/rules.md', 'docs-ai/common/codedesign.md', 'docs-ai/common/UIUX.md'))) {
            if (-not $payload.ContainsKey($required) -or $payload[$required].mode -ne 'managed') { throw "Missing managed payload: $required" }
        }
        foreach ($required in @('debug.bat', 'docs/.gitkeep', 'docs-ai/current/1_architecture.md', 'docs-ai/current/1_dependency.md',
            'docs-ai/current/1_changelogs/.gitkeep', 'docs-ai/current/1_bugreports/.gitkeep', 'docs-ai/current/1_archived/.gitkeep')) {
            if (-not $payload.ContainsKey($required) -or $payload[$required].mode -ne 'seed') { throw "Missing project seed: $required" }
        }
        return [pscustomobject]@{ manifest = $manifest; manifestBytes = $manifestBytes; manifestHash = Get-SafHash $manifestBytes
            commit = $commit; repository = $Repository; ref = $Ref; payload = $payload }
    } finally { if ($temporary) { Remove-SafTemporary -Path $temporary -Prefix 'saf-source-' } }
}

function Remove-SafTemporary([string]$Path, [string]$Prefix) {
    if (-not [IO.Directory]::Exists($Path)) { return }
    $absolute = [IO.Path]::GetFullPath($Path)
    $base = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92, [char]47)
    if (-not [IO.Path]::GetDirectoryName($absolute).Equals($base, [StringComparison]::OrdinalIgnoreCase) -or
        [IO.Path]::GetFileName($absolute) -notmatch ('^' + [regex]::Escape($Prefix) + '[0-9a-f]{32}$')) { throw 'Refusing unexpected temporary cleanup path.' }
    Remove-Item -LiteralPath $absolute -Recurse -Force
}
