#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).ProviderPath,
    [string]$Repository = 'https://github.com/Evigila/AGENTS.md.git',
    [string]$Ref = 'main', [string]$SourcePath
)
# Evaluation through irm | iex must not terminate the caller's shell.
try {
& {
    [CmdletBinding()]
    param(
        [string]$ProjectRoot = (Get-Location).ProviderPath,
        [string]$Repository = 'https://github.com/Evigila/AGENTS.md.git',
        [string]$Ref = 'main', [string]$SourcePath
    )
    Set-StrictMode -Version Latest
    $ErrorActionPreference = 'Stop'
    $cache = $null; $lease = $null; $root = $null; $coreLoaded = $false; $result = 'error'
    $startedAtUtc = [DateTime]::UtcNow.ToString('o')
    $encoding = New-Object Text.UTF8Encoding($false, $true)
    function Invoke-BootGit([string[]]$Arguments, [switch]$Text) {
        $quoted = foreach ($value in $Arguments) {
            '"' + [regex]::Replace([regex]::Replace($value, '(\\*)"', '$1$1\"'), '(\\+)$', '$1$1') + '"'
        }
        $start = New-Object Diagnostics.ProcessStartInfo
        $start.FileName = 'git'; $start.Arguments = $quoted -join ' '; $start.UseShellExecute = $false; $start.CreateNoWindow = $true
        $start.RedirectStandardOutput = $true; $start.RedirectStandardError = $true; $start.EnvironmentVariables['GIT_TERMINAL_PROMPT'] = '0'
        $process = New-Object Diagnostics.Process; $process.StartInfo = $start; $buffer = New-Object IO.MemoryStream
        try {
            [void]$process.Start(); $errorTask = $process.StandardError.ReadToEndAsync()
            $process.StandardOutput.BaseStream.CopyTo($buffer); $process.WaitForExit(); [void]$errorTask.Result
            if ($process.ExitCode -ne 0) { throw 'Bootstrap Git acquisition failed. Verify source access and ref.' }
            if ($Text) { return $encoding.GetString($buffer.ToArray()).Trim() }
            return ,$buffer.ToArray()
        } finally { $buffer.Dispose(); $process.Dispose() }
    }
    function Read-BootBlob([string]$Relative) {
        $tree = Invoke-BootGit @('-C', $source, 'ls-tree', $commit, '--', $Relative) -Text
        if ($tree -notmatch '^(100644|100755) blob [0-9a-f]{40}\t') { throw "Bootstrap source is not a regular Git blob: $Relative" }
        return ,(Invoke-BootGit @('-C', $source, 'show', ($commit + ':' + $Relative)))
    }
    try {
        $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd([char]92, [char]47)
        $gitRoot = Invoke-BootGit @('-C', $root, 'rev-parse', '--show-toplevel') -Text
        if (-not $root.Equals([IO.Path]::GetFullPath($gitRoot).TrimEnd([char]92, [char]47), [StringComparison]::OrdinalIgnoreCase)) { throw 'Run initialization at the target Git repository root.' }
        if (-not $Repository -or $Repository.StartsWith('-') -or -not $Ref -or $Ref.StartsWith('-')) { throw 'Invalid bootstrap source or ref.' }
        $repositoryUri = $null
        if ([Uri]::TryCreate($Repository, [UriKind]::Absolute, [ref]$repositoryUri) -and $repositoryUri.Scheme -in @('http', 'https') -and
            ($repositoryUri.UserInfo -or $repositoryUri.Query -or $repositoryUri.Fragment)) { throw 'Use a credential-free repository URL and the existing Git credential helper.' }
        $cache = Join-Path ([IO.Path]::GetTempPath()) ('saf-init-' + [Guid]::NewGuid().ToString('N'))
        [void][IO.Directory]::CreateDirectory($cache)
        if ($SourcePath) {
            $source = [IO.Path]::GetFullPath($SourcePath)
            if ($source.Equals($root, [StringComparison]::OrdinalIgnoreCase)) { throw 'SourcePath cannot equal the target repository.' }
            $commit = Invoke-BootGit @('-C', $source, 'rev-parse', ($Ref + '^{commit}')) -Text
        } else {
            $source = Join-Path $cache 'source'
            [void](Invoke-BootGit @('init', '--bare', '--quiet', $source))
            [void](Invoke-BootGit @('-C', $source, 'fetch', '--quiet', '--depth=1', '--no-tags', $Repository, $Ref))
            $commit = Invoke-BootGit @('-C', $source, 'rev-parse', 'FETCH_HEAD^{commit}') -Text
        }
        if ($commit -notmatch '^[0-9a-f]{40}$') { throw 'Bootstrap must resolve one exact Git commit.' }
        $manifest = $encoding.GetString((Read-BootBlob 'SAF.json')) | ConvertFrom-Json
        if ($manifest.schemaVersion -ne 1 -or $manifest.handlerProtocolVersion -ne 1 -or
            $manifest.frameworkVersion -notmatch '^\d+\.\d+\.\d+$') { throw 'Unsupported bootstrap manifest.' }
        $handlers = @('origin.bat', 'local.bat', 'scripts/origin.ps1', 'scripts/local.ps1', 'scripts/saf-core.ps1')
        if (@($manifest.bootstrapFiles).Count -ne 5 -or @(Compare-Object ($handlers | Sort-Object) (@($manifest.bootstrapFiles) | Sort-Object)).Count -ne 0) { throw 'Invalid bootstrap handler set.' }
        $payload = @{}
        foreach ($relative in $handlers) {
            $entries = @($manifest.files | Where-Object target -eq $relative)
            if ($entries.Count -ne 1 -or $entries[0].source -ne $relative -or $entries[0].mode -ne 'managed' -or $entries[0].sha256 -notmatch '^[0-9a-f]{64}$') { throw "Invalid bootstrap entry: $relative" }
            $bytes = Read-BootBlob $relative
            $normalized = $encoding.GetBytes($encoding.GetString($bytes).TrimStart([char]0xFEFF).Replace("`r`n", "`n"))
            $algorithm = [Security.Cryptography.SHA256]::Create()
            try { $hash = ([BitConverter]::ToString($algorithm.ComputeHash($normalized))).Replace('-', '').ToLowerInvariant() } finally { $algorithm.Dispose() }
            if ($hash -ne $entries[0].sha256) { throw "Bootstrap hash mismatch: $relative" }
            $payload[$relative] = [pscustomobject]@{ bytes = $bytes; hash = $hash }
        }
        $corePath = Join-Path $cache 'saf-core.ps1'
        [IO.File]::WriteAllBytes($corePath, $payload['scripts/saf-core.ps1'].bytes)
        . $corePath
        $script:SafStartedAtUtc = $startedAtUtc
        $coreLoaded = $true; $root = Get-SafRoot -ProjectRoot $root
        $lease = Enter-SafOperation -Root $root
        $state = Read-SafState -Root $root
        $lockHash = Get-SafExistingHash (Get-SafTarget $root 'SAF.lock.json') -Raw
        $backup = New-SafBackup -Root $root -RelativePaths ($handlers + @('SAF.lock.json', 'AGENTS.lock.json', 'AGENTS.ensure.json', '.gitignore')) -Reason 'init'
        $operations = New-Object 'Collections.Generic.List[object]'; $hashes = [ordered]@{}
        foreach ($relative in $handlers) {
            $target = Get-SafTarget $root $relative
            $operations.Add([pscustomobject]@{ relative = $relative; bytes = $payload[$relative].bytes; delete = $false; expected = Get-SafExistingHash $target -Raw })
            $hashes[$relative] = $payload[$relative].hash
        }
        $ignoreOperation = Get-SafRuntimeIgnoreOperation -Root $root
        if ($ignoreOperation) { $operations.Add($ignoreOperation) }
        $state.bootstrap = [pscustomobject]@{ handlerProtocolVersion = 1; repository = $Repository; ref = $Ref; commit = $commit; managedFiles = [pscustomobject]$hashes }
        $operations.Add([pscustomobject]@{ relative = 'SAF.lock.json'; bytes = ConvertTo-SafBytes $state; delete = $false; expected = $lockHash })
        Invoke-SafTransaction -Root $root -Operations $operations.ToArray()
        $result = 'initialized'
        Write-Host "[SAF] Handler set deployed. Recovery snapshot: $backup"
        Write-Host '[SAF] Next: .\origin.bat -sync'
    } finally {
        if ($coreLoaded -and $root) { Write-SafLog -Root $root -Action 'init' -Result $result -ExitCode $(if ($result -eq 'initialized') { 0 } else { 1 }) -Data $null }
        if ($lease) { $lease.Dispose() }
        if ($cache -and [IO.Directory]::Exists($cache)) {
            $absolute = [IO.Path]::GetFullPath($cache)
            $temporaryRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([char]92, [char]47)
            if (-not [IO.Path]::GetDirectoryName($absolute).Equals($temporaryRoot, [StringComparison]::OrdinalIgnoreCase) -or
                [IO.Path]::GetFileName($absolute) -notmatch '^saf-init-[0-9a-f]{32}$') { throw 'Refusing unexpected bootstrap cleanup path.' }
            Remove-Item -LiteralPath $absolute -Recurse -Force
        }
    }
} -ProjectRoot $ProjectRoot -Repository $Repository -Ref $Ref -SourcePath $SourcePath
} catch {
    # Re-throw at file scope so -File reports a failed bootstrap to its caller.
    throw
}
