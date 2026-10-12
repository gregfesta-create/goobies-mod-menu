<#
.SYNOPSIS
    Collects Goobies crash information into one zip on your Desktop, ready to attach to a GitHub issue.
.DESCRIPTION
    Read-only on the game folder; needs no admin rights and no network; never prompts. Copies UE4SS
    logs, mod configuration, the newest crash folder's context and (if small enough) the newest crash
    dump. Text files are sanitized: user name, profile folder (long and 8.3 form), computer name,
    Steam and lobby IDs, IP and e-mail addresses, network host names and the account fields in
    CrashContext.runtime-xml are replaced. Dump files (.dmp) are binary and cannot be sanitized;
    use -NoDump to leave them out. On failure it writes Goobies_crash_report_FAILED.txt explaining
    how to retry.
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File CollectCrashReport.ps1
.EXAMPLE
    powershell -ExecutionPolicy Bypass -File CollectCrashReport.ps1 -GameDir "D:\SteamLibrary\steamapps\common\Goobies" -NoDump
#>
[CmdletBinding()]
param(
    [string]$GameDir,        # Goobies folder (common\Goobies, or Goobies_DX11 / Goobies_Vulkan inside it); auto-detected if omitted
    [string]$OutDir,         # where the zip goes; default is your Desktop
    [string]$CrashesRoot,    # default %LOCALAPPDATA%\Shooter\Saved\Crashes
    [string]$SteamRoot,      # Steam folder; default from the registry (HKCU\Software\Valve\Steam)
    [switch]$NoDump,         # never include a .dmp file
    [switch]$NoExplorer      # do not open Explorer (or Notepad on failure) at the end
)
$ErrorActionPreference = 'Stop'
$Version = '1.1.0'
$MaxDumpBytes = 20MB

function Test-GameRoot([string]$Dir) {
    return $Dir -and (Test-Path -LiteralPath (Join-Path $Dir 'Shooter\Binaries\Win64') -PathType Container)
}

# A folder may be a game root itself or hold several (Steam ships Goobies_DX11\ and Goobies_Vulkan\).
# With several, prefer the newest UE4SS.log, then one with a Mods folder, then DX11.
$script:GameChoice = $null
function Select-GameRoot([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $null }
    $cands = @(@($Dir) + @(Get-ChildItem -LiteralPath $Dir -Directory | ForEach-Object { $_.FullName }) |
               Where-Object { Test-GameRoot $_ })
    if ($cands.Count -le 1) { return $cands | Select-Object -First 1 }
    $ranked = $cands | ForEach-Object {
        $w = Join-Path $_ 'Shooter\Binaries\Win64'
        $log = Get-Item -LiteralPath (Join-Path $w 'UE4SS.log') -ErrorAction SilentlyContinue
        [pscustomobject]@{ Dir = $_; Log = $(if ($log) { $log.LastWriteTimeUtc } else { [datetime]::MinValue })
                           Mods = [int](Test-Path -LiteralPath (Join-Path $w 'Mods')); Dx = [int]((Split-Path -Leaf $_) -match 'DX11') }
    } | Sort-Object Log, Mods, Dx -Descending
    $best = $ranked[0]
    $why = if ($best.Log -ne [datetime]::MinValue) { 'newest UE4SS.log' } elseif ($best.Mods) { 'has a Mods folder' } else { 'DX11 default' }
    $script:GameChoice = "Found several Goobies installs: $(($cands | ForEach-Object { Split-Path -Leaf $_ }) -join ', '). " +
                         "Using $(Split-Path -Leaf $best.Dir) ($why); pass -GameDir to pick another."
    return $best.Dir
}

# Steam: SteamPath (registry, or -SteamRoot) plus every library listed in libraryfolders.vdf.
function Find-SteamGame {
    $steam = $SteamRoot
    if (-not $steam) {
        try { $steam = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath).SteamPath } catch { return $null }
    }
    if (-not $steam) { return $null }
    $steam = [IO.Path]::GetFullPath($steam)   # registry value uses forward slashes
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path -LiteralPath $vdf) {
        foreach ($m in [regex]::Matches([IO.File]::ReadAllText($vdf), '"path"\s+"([^"]+)"')) {
            $libs += $m.Groups[1].Value -replace '\\\\', '\'
        }
    }
    foreach ($lib in $libs | Select-Object -Unique) {
        $found = Select-GameRoot (Join-Path $lib 'steamapps\common\Goobies')
        if ($found) { return $found }
    }
    return $null
}

# The script's own folder (or a parent of it), when it sits inside or beside a Goobies install.
function Find-ParentGame {
    $dir = $PSScriptRoot
    while ($dir) {
        $found = Select-GameRoot $dir
        if ($found) { return $found }
        $parent = Split-Path -Parent $dir
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Format-Span([TimeSpan]$Span) {
    $s = $Span.Duration()
    if ($s.TotalDays -ge 1) { return '{0}d {1}h' -f [math]::Floor($s.TotalDays), $s.Hours }
    if ($s.TotalHours -ge 1) { return '{0}h {1}m' -f $s.Hours, $s.Minutes }
    return '{0}m' -f [math]::Floor($s.TotalMinutes)
}

# Read a text file even while the game still has it open for writing. Honour a BOM; otherwise
# decode as strict UTF-8 and fall back to the ANSI code page, so non-ASCII names in a cp1252 file still match.
function Read-Shared([string]$Path) {
    $fs = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite, Delete')
    try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); $b = $ms.ToArray() } finally { $fs.Dispose() }
    if ($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB -and $b[2] -eq 0xBF) { return [Text.Encoding]::UTF8.GetString($b, 3, $b.Length - 3) }
    if ($b.Length -ge 2 -and $b[0] -eq 0xFF -and $b[1] -eq 0xFE) { return [Text.Encoding]::Unicode.GetString($b, 2, $b.Length - 2) }
    if ($b.Length -ge 2 -and $b[0] -eq 0xFE -and $b[1] -eq 0xFF) { return [Text.Encoding]::BigEndianUnicode.GetString($b, 2, $b.Length - 2) }
    try { return (New-Object Text.UTF8Encoding($false, $true)).GetString($b) } catch { return [Text.Encoding]::Default.GetString($b) }
}

# Redaction rules, built once: profile paths (long and 8.3, either slash) first, then names.
$profiles = @($env:USERPROFILE)
try { $profiles += (New-Object -ComObject Scripting.FileSystemObject).GetFolder($env:USERPROFILE).ShortPath } catch { }
$profiles = @($profiles | Where-Object { $_ } | ForEach-Object { $_.TrimEnd('\', '/') } | Select-Object -Unique)
$Redactions = New-Object System.Collections.Generic.List[object]
foreach ($p in $profiles) {
    $rx = (($p -split '[\\/]+' | ForEach-Object { [regex]::Escape($_) }) -join '[\\/]+') + '(?![A-Za-z0-9])'
    $Redactions.Add(@("(?i)$rx", '<userprofile>'))
}
$names = @(@($env:USERNAME) + @($profiles | ForEach-Object { Split-Path -Leaf $_ }) | Where-Object { $_.Length -ge 2 } |
           Sort-Object Length -Descending | Select-Object -Unique)
foreach ($n in $names) { $Redactions.Add(@(('(?i)(?<![A-Za-z0-9])' + [regex]::Escape($n) + '(?![A-Za-z0-9])'), '<user>')) }
if ($env:COMPUTERNAME) { $Redactions.Add(@(('(?i)(?<![A-Za-z0-9])' + [regex]::Escape($env:COMPUTERNAME) + '(?![A-Za-z0-9])'), '<pc>')) }
$octet = '(?:25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)'
foreach ($rule in @(
        @('(?s)<(UserName|LoginId|EpicAccountId|MachineId|UserActivityHint)>.*?</\1>', '<$1></$1>'),
        @('(?<!\d)7656119\d{10}(?!\d)', '<steamid>'),
        @('(?<!\d)109775\d{12}(?!\d)', '<lobby>'),
        # Bounded e-mail parts keep this linear on very long tokens.
        @('(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9.-]{1,253}\.[A-Za-z]{2,24}', '<email>'),
        # Four octets only (1.1.3 stays), and not version numbers such as "version 4.27.2.0", "v4.27.2.0", "UE4.27.2.0".
        @("(?<!\d)(?<!\d\.)(?<!(?i:\bv|\bver|\bversion|\bue)[\s:=]*)(?:$octet\.){3}$octet(?!\.?\d)", '<ip>'),
        @('(?<![\w:\\])\\\\[A-Za-z0-9][A-Za-z0-9._$-]*\\', '\\<host>\'))) { $Redactions.Add($rule) }

function Protect-Text([string]$Text) {
    foreach ($r in $Redactions) { $Text = [regex]::Replace($Text, $r[0], $r[1]) }
    return $Text
}

$included = New-Object System.Collections.Generic.List[string]
$skipped = New-Object System.Collections.Generic.List[string]
function Add-TextFile([string]$Source, [string]$Rel) {
    if (-not (Test-Path -LiteralPath $Source -PathType Leaf)) { return }
    try {
        $dest = Join-Path $stage $Rel
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
        [IO.File]::WriteAllText($dest, (Protect-Text (Read-Shared $Source)), (New-Object Text.UTF8Encoding($false)))
        $included.Add($Rel)
    } catch { $skipped.Add("$Rel ($($_.Exception.Message))") }   # e.g. locked by another program
}

# Never prompt: on failure leave a text file next to where the zip would go and open it.
function Write-Failure([string]$Reason) {
    # Sanitized like the report (people paste this file into issues); a script under the profile
    # folder keeps a working command by spelling the profile as $env:USERPROFILE.
    $cmd = (Protect-Text ('powershell -NoProfile -ExecutionPolicy Bypass -File "{0}" -GameDir "<your Goobies folder>"' -f $PSCommandPath)).Replace('<userprofile>', '$env:USERPROFILE')
    $text = @('CollectCrashReport.ps1 could not create a crash report.', '', "Reason: $(Protect-Text $Reason)", '', 'How to retry:',
        '1. Find your Goobies folder: in Steam, right-click Goobies > Manage > Browse local files.',
        '2. Open PowerShell in the folder that holds CollectCrashReport.ps1: Shift+right-click an empty spot in it',
        '   and choose "Open PowerShell window here" (Windows 11: right-click > "Open in Terminal").',
        '3. Run this command, with <your Goobies folder> replaced by the folder from step 1:', '', "   $cmd", '',
        'If Windows blocks the script: right-click it > Properties > Unblock, or run Unblock-File on it.') -join "`r`n"
    Write-Output $text
    $dir = $OutDir
    try { New-Item -ItemType Directory -Force -Path $dir | Out-Null } catch { $dir = $env:TEMP }
    $file = Join-Path $dir 'Goobies_crash_report_FAILED.txt'
    [IO.File]::WriteAllText($file, $text)
    if (-not $NoExplorer) { Start-Process notepad.exe -ArgumentList "`"$file`"" }
}

if (-not $OutDir) { $OutDir = [Environment]::GetFolderPath('Desktop') }
if (-not $OutDir) { $OutDir = $env:USERPROFILE }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$stage = Join-Path $env:TEMP "Goobies_crash_report_$stamp`_$PID"
$zipPath = $null; $zipDone = $false
try {
    # ---- 1. locate the game ------------------------------------------------------------------
    if ($GameDir) {
        $found = Select-GameRoot $GameDir
        if (-not $found) { throw "Goobies was not found at '$GameDir' (expected a Shooter\Binaries\Win64 folder in it or in a Goobies_DX11 / Goobies_Vulkan folder inside it)." }
        $GameDir = $found
    } else {
        $GameDir = Find-SteamGame
        if (-not $GameDir) { $GameDir = Find-ParentGame }
        if (-not $GameDir) { throw 'The Goobies install was not found automatically (checked your Steam libraries and the folders around this script).' }
    }
    $GameDir = (Resolve-Path -LiteralPath $GameDir).Path.TrimEnd('\')
    if ($script:GameChoice) { Write-Output $script:GameChoice }
    Write-Output "Game folder: $GameDir"
    $win64 = Join-Path $GameDir 'Shooter\Binaries\Win64'
    if (-not $CrashesRoot) { $CrashesRoot = Join-Path $env:LOCALAPPDATA 'Shooter\Saved\Crashes' }
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    # ---- 2. logs and configuration ---------------------------------------------------------
    Get-ChildItem -LiteralPath $win64 -File -Filter 'UE4SS*.log*' | ForEach-Object { Add-TextFile $_.FullName $_.Name }
    Add-TextFile (Join-Path $win64 'UE4SS-settings.ini') 'UE4SS-settings.ini'
    Add-TextFile (Join-Path $win64 'Configs\ModList.ini') 'ModList.ini'
    $mods = Join-Path $win64 'Mods'
    Add-TextFile (Join-Path $mods 'mods.txt') 'mods.txt'
    $folderLines = @()
    if (Test-Path -LiteralPath $mods) {
        foreach ($d in Get-ChildItem -LiteralPath $mods -Directory | Sort-Object Name) {
            $state = if (Test-Path -LiteralPath (Join-Path $d.FullName 'enabled.txt')) { 'enabled.txt' } else { '-' }
            $folderLines += ('{0,-32} {1}' -f $d.Name, $state)
            Add-TextFile (Join-Path $d.FullName 'mod_menu.ini') "mods\$($d.Name)\mod_menu.ini"
        }
    }
    [IO.File]::WriteAllText((Join-Path $stage 'mod_folders.txt'), (Protect-Text ($folderLines -join "`r`n")))
    $included.Add('mod_folders.txt')

    # ---- 3. newest crash folder and newest dump ----------------------------------------------
    $crash = $null
    if (Test-Path -LiteralPath $CrashesRoot) {
        $crash = Get-ChildItem -LiteralPath $CrashesRoot -Directory | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    $dumps = @(Get-ChildItem -LiteralPath $win64 -File -Filter 'crash_*.dmp')
    $ctxRaw = ''
    if ($crash) {
        $ctxPath = Join-Path $crash.FullName 'CrashContext.runtime-xml'
        if (Test-Path -LiteralPath $ctxPath) { try { $ctxRaw = Read-Shared $ctxPath } catch { } }
        Add-TextFile $ctxPath 'crash\CrashContext.runtime-xml'
        Add-TextFile (Join-Path $crash.FullName 'CrashReportClient.ini') 'crash\CrashReportClient.ini'
        $dumps += @(Get-ChildItem -LiteralPath $crash.FullName -File -Filter 'UEMinidump.dmp')
    }
    $dump = $dumps | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $dump) { $dumpNote = 'No crash dump found.' }
    elseif ($NoDump) { $dumpNote = "Dump $($dump.Name) left out because -NoDump was used." }
    elseif ($dump.Length -gt $MaxDumpBytes) {
        $dumpNote = 'Dump {0} left out: {1:N1} MB is over the 20 MB limit.' -f $dump.Name, ($dump.Length / 1MB)
    } else {
        try {
            $crashDir = New-Item -ItemType Directory -Force -Path (Join-Path $stage 'crash')
            Copy-Item -LiteralPath $dump.FullName -Destination $crashDir.FullName -Force
            $included.Add("crash\$($dump.Name)")
            $dumpNote = "Dump $($dump.Name) included (binary, not sanitized; rerun with -NoDump to omit)."
        } catch {   # e.g. still locked by the crashing game or the crash reporter
            $skipped.Add("crash\$($dump.Name) ($($_.Exception.Message))")
            $dumpNote = "Dump $($dump.Name) could not be read; see Skipped below."
        }
    }

    # ---- 4. summary, with warnings when the crash may not match this install or session -------
    $exes = @(Get-ChildItem -LiteralPath $GameDir -File -Filter 'Goobies*.exe' | ForEach-Object { $_.Name })
    $warnings = @()
    $crashTime = 'none found'
    if ($crash) {
        $crashTime = '{0} ({1}), {2} ago' -f $crash.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'), $crash.Name,
                     (Format-Span ((Get-Date) - $crash.LastWriteTime))
        $log = Get-Item -LiteralPath (Join-Path $win64 'UE4SS.log') -ErrorAction SilentlyContinue
        if ($log) {   # UE4SS.log is rewritten on every launch, so it marks the latest game session
            $delta = $crash.LastWriteTime - $log.LastWriteTime
            $crashTime += '; {0} {1} UE4SS.log ({2})' -f (Format-Span $delta), $(if ($delta.Ticks -lt 0) { 'before' } else { 'after' }),
                          $log.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
            if ($delta.TotalMinutes -lt -10) { $warnings += 'this crash is older than the latest game session - may not be the crash you are reporting.' }
            if ($delta.TotalMinutes -gt 10) { $warnings += 'this crash happened after the last logged session - the log may be from a different run.' }
        }
        $m = [regex]::Match($ctxRaw, '<(?:RootDir|BaseDir)>([^<]+)</')
        if ($m.Success) {
            try { $ctxDir = [IO.Path]::GetFullPath($m.Groups[1].Value).TrimEnd('\') } catch { $ctxDir = $m.Groups[1].Value }
            if (-not ($ctxDir -ieq $GameDir -or $ctxDir.StartsWith($GameDir + '\', [StringComparison]::OrdinalIgnoreCase))) {
                $warnings += "this crash came from a different Goobies copy: $ctxDir"
            }
        }
    }
    foreach ($w in $warnings) { Write-Output "Note: $(Protect-Text $w)" }
    $fileLines = foreach ($rel in $included) { '  {0}  {1:N0} bytes' -f $rel, (Get-Item -LiteralPath (Join-Path $stage $rel)).Length }
    $summary = @(
        "CollectCrashReport.ps1 version $Version",
        "Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')",
        "Windows: $([Environment]::OSVersion.VersionString)",
        "Game folder: $GameDir",
        "Game executables: $(if ($exes) { $exes -join ', ' } else { 'none found' })",
        "Newest crash folder: $crashTime"
    ) + @($warnings | ForEach-Object { "WARNING: $_" }) + @($dumpNote, 'Included files:') + $fileLines +
        @($skipped | ForEach-Object { "Skipped (could not read): $_" })
    [IO.File]::WriteAllText((Join-Path $stage 'summary.txt'), (Protect-Text ($summary -join "`r`n")))

    # ---- 5. zip with forward-slash entry names (portable across unzip tools) --------------------
    Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
    $zipPath = Join-Path (Resolve-Path -LiteralPath $OutDir).Path "Goobies_crash_report_$stamp.zip"
    $zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try {
        foreach ($f in Get-ChildItem -LiteralPath $stage -Recurse -File) {
            $entry = $f.FullName.Substring($stage.Length + 1) -replace '\\', '/'
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, $entry)
        }
    } finally { $zip.Dispose() }
    $zipDone = $true
} catch {
    if ($zipPath -and -not $zipDone -and (Test-Path -LiteralPath $zipPath -PathType Leaf)) { Remove-Item -LiteralPath $zipPath -Force }
    Write-Failure $_.Exception.Message
    exit 1
} finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}

Remove-Item -LiteralPath (Join-Path $OutDir 'Goobies_crash_report_FAILED.txt') -Force -ErrorAction SilentlyContinue
Write-Output "Crash report written to: $zipPath"
Write-Output 'Attach it to a new "Crash report" issue on GitHub (drag the zip into the issue form).'
if (-not $NoExplorer) { Start-Process explorer.exe -ArgumentList "/select,`"$zipPath`"" }
exit 0
