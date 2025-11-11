# Version 1.3.0

# -------------------
# Configuration
# -------------------
$appName = "game"
$requireFiles = @("main.lua")
$requireFolders = @("src")

$buildFolder = "build"
$versionsFolder = Join-Path $buildFolder "version"
$releaseFolder = Join-Path $buildFolder "release"
$loveZip = Join-Path $releaseFolder "${appName}.love"

$love2dVersion = "11.5"
$bit = "64"
$buildWindows = $true
$buildLinux = $true
$autoRun = $true
$debug = $false

# Windows specific files required for build
$windowsRequiredFiles = @(
    "game.ico", "license.txt", "love.dll", "love.exe", "love.ico",
    "lovec.exe", "lua51.dll", "mpg123.dll", "msvcp120.dll",
    "msvcr120.dll", "OpenAL32.dll", "SDL2.dll"
)

# OS-specific binary paths
$basePath = Join-Path $versionsFolder "$love2dVersion/x$bit"
$binaries = @{
    "windows" = Join-Path $basePath "windows"
    "linux"   = Join-Path $basePath "linux.AppImage"
}

# -------------------
# Fetch Parameters
# -------------------
# r for run (autorun), b for build, d for debug
foreach ($arg in $args) {
    if ($arg -like "-*") {
        $arg = $arg -replace '-', ''
        $autoRun = "r" -in $arg.ToCharArray() ? $true : $false
        $debug = "d" -in $arg.ToCharArray() ? $true : $false

        if ("w" -in $arg.ToCharArray()) { $buildWindows = $true; $buildLinux = $false }
        elseif ("l" -in $arg.ToCharArray()) { $buildWindows = $false; $buildLinux = $true }
        elseif ("b" -in $arg.ToCharArray()) { $buildWindows = $true; $buildLinux = $true }
        else { $buildWindows = $false; $buildLinux = $false }
    }
}

# -------------------
# Info
# -------------------
Write-Host "[INFO] Starting build for LOVE version $love2dVersion ($bit-bit)"
switch ("$buildWindows$buildLinux") {
    "TrueTrue"   { Write-Host "[INFO] Building for Windows and Linux." }
    "TrueFalse"  { Write-Host "[INFO] Building for Windows only." }
    "FalseTrue"  { Write-Host "[INFO] Building for Linux only." }
    default      { Write-Host "[INFO] Building for none." }
}

Write-Host "[INFO] Autorun is $($autoRun ? 'enabled' : 'disabled')."
Write-Host "[INFO] Debug mode is $($debug ? 'enabled' : 'disabled')."

# -------------------
# Helper Functions
# -------------------
function appendGameToFile($filePath, $outputFolder, $name) {
    # Debug info
    # Write-Host "$filePath, $releaseFolder, $name"

    $outPath = Join-Path $outputFolder "$name"
    Write-Host "[INFO] Processing $outPath"

    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $gameBytes = [System.IO.File]::ReadAllBytes($loveZip)
    [System.IO.File]::WriteAllBytes($outPath, $fileBytes + $gameBytes)

    Write-Host "[SUCCESS] $appName.love appended to $outPath"
}

# -------------------
# Prepare Directories
# -------------------
$versionsFolder = ($versionsFolder -replace '\\','/').TrimEnd('/')
$releaseFolder  = ($releaseFolder  -replace '\\','/').TrimEnd('/')
$loveZip        = ($loveZip        -replace '\\','/').TrimEnd('/')


foreach ($folder in @($buildFolder, $versionsFolder, $releaseFolder)) {
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Path $folder | Out-Null
        Write-Host "[INFO] Created folder: $folder"
    }
}

# -------------------
# Prepare game.love
# -------------------
if (Test-Path $loveZip) { Remove-Item $loveZip }

Add-Type -AssemblyName "System.IO.Compression.FileSystem"
$zip = [System.IO.Compression.ZipFile]::Open($loveZip, 'Create')

foreach ($file in $requireFiles) {
    if (Test-Path $file) {
        $zipEntryName = ($file -replace '\\', '/') -replace '^\./', ''
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file, $zipEntryName) | Out-Null
        Write-Host "[INFO] Added $file to $loveZip"
    } else {
        Write-Warning "[WARN] Required file not found: $file"
    }
}

foreach ($folder in $requireFolders) {
    if (Test-Path $folder) {
        Get-ChildItem -Path $folder -Recurse -File | ForEach-Object {
            $relative = [System.IO.Path]::GetRelativePath((Get-Location), $_.FullName)
            $zipEntryName = ($relative -replace '\\', '/') -replace '^\./', ''

            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_, $zipEntryName) | Out-Null
            Write-Host "[INFO] Added $zipEntryName to $loveZip"
        }
    } else {
        Write-Warning "[WARN] Required folder not found: $folder"
    }
}
$zip.Dispose()
Write-Host "[SUCCESS] Created game.love archive."

# Autorun
if ($autoRun) {
    Write-Host "[INFO] Running $appName.love with LOVE2D... (Debug: $debug)"
    $exe = "$($binaries['windows'])\love$($debug ? 'c' : '').exe"
    & $exe $loveZip
}

# -------------------
# Build Windows
# -------------------
if ($buildWindows) {
    Write-Host "[INFO] Starting Windows build..."

    $windowsBinaries = $binaries["windows"]
    if (!(Test-Path $windowsBinaries)) {
        New-Item -ItemType Directory -Path $windowsBinaries | Out-Null
        Write-Host "[INFO] Created Windows binaries folder: $windowsBinaries"
    }

    # Check for required files
    foreach ($file in $windowsRequiredFiles) {
        $filePath = Join-Path $windowsBinaries $file
        if (!(Test-Path $filePath)) {
            Write-Warning "[ERROR] Missing required Windows file: $file"
            Write-Warning "[WARN] Windows build skipped due to missing files."
            $buildWindows = $false
        }
    }
}

if ($buildWindows) {
    # Prepare release folder for Windows
    $folder = Join-Path $releaseFolder "windows"
    if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }
    New-Item -ItemType Directory -Path $folder | Out-Null
    Write-Host "[INFO] Cleared Previous Windows builds."

    # Copy DLLs and support files
    Get-ChildItem $windowsBinaries -Exclude "*.exe" -File -Recurse | ForEach-Object {
        Copy-Item $_.FullName -Destination $folder -Force
        Write-Host "[SUCCESS] Copied $($_.Name) to release folder."
    }

    # Append game.love to executables
    $exeFiles = @("love.exe", "lovec.exe")
    foreach ($exe in $exeFiles) {
        $exePath = Join-Path $windowsBinaries $exe
        if (Test-Path $exePath) {
            $outputName = if ($exe -eq "lovec.exe") { "$appName-debug.exe" } else { "$appName.exe" }
            appendGameToFile $exePath $folder $outputName
        } else {
            Write-Warning "[WARN] $exe not found in $windowsBinaries, skipping."
        }
    }

    Write-Host "[INFO] Finished Windows build."

    # Create release ZIP
    Write-Host "[INFO] Creating Windows release ZIP..."
    $zipName = Join-Path $releaseFolder "$appName-windows-x$bit.zip"
    if (Test-Path $zipName) { Remove-Item $zipName -Force }

    $releaseZip = [System.IO.Compression.ZipFile]::Open($zipName, "Create")
    Get-ChildItem $folder -Recurse -File | ForEach-Object {

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($releaseZip, $_.FullName, $_.Name) | Out-Null
        Write-Host "[SUCCESS] Added $($_.Name) to ZIP"
    }
    $releaseZip.Dispose()
    Write-Host "[SUCCESS] Created Windows release ZIP: $zipName"
    Write-Host "[INFO] Finished Windows ZIP Build."
}

# -------------------
# Build Linux
# -------------------
if ($buildLinux) {
    Write-Host "[INFO] Starting Linux build..."

    $linuxBinary = $binaries["linux"]
    if (!(Test-Path $linuxBinary)) {
        Write-Warning "[ERROR] Missing Linux AppImage binary: $linuxBinary"
        Write-Warning "[WARN] Linux build skipped due to missing files."
        $buildLinux = $false
    }
}

if ($buildLinux) {
    # Clear previous Linux AppImage
    $filePath = Join-Path $releaseFolder "$appName.AppImage"
    if (Test-Path $filePath) {
        Remove-Item $filePath -Force 
        Write-Host "[INFO] Cleared Previous Linux build."
    }

    # Copy AppImage to release folder (treat as standalone executable like love.exe)
    Copy-Item $binaries["linux"] -Destination $filePath -Force
    Write-Host "[SUCCESS] Copied $appName.AppImage to $releaseFolder"

    # Append game.love to the AppImage (in-place, no ZIP)
    appendGameToFile $filePath $releaseFolder "$appName.AppImage"

    # Try to set executable bit on Linux only
    if ($IsLinux)  {
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            & chmod +x $appImageDest
        }
    }

    Write-Host "[INFO] Finished Linux build."
}