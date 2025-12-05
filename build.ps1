# Version 1.4.2

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

$loveVersion = "11.5"
$setup = $false
$buildWindows = $true
$buildLinux = $true

# Windows specific files required for build
$windowsRequiredFiles = @(
    "game.ico", "license.txt", "love.dll", "love.exe", "love.ico",
    "lovec.exe", "lua51.dll", "mpg123.dll", "msvcp120.dll",
    "msvcr120.dll", "OpenAL32.dll", "SDL2.dll"
)

# OS-specific binary paths
$basePath = Join-Path $versionsFolder "$loveVersion"
$binaries = @{
    "win32" = Join-Path $basePath "win32"
    "win64" = Join-Path $basePath "win64"
    "linux" = Join-Path $basePath "linux.AppImage" # NO 32-BIT VERSION
}

# -------------------
# Fetch Parameters
# -------------------
# b for build, d for debug, s for setup
foreach ($arg in $args) {
    if ($arg -like "-*") {
        $arg = $arg -replace '-', ''
        $chars = $arg.ToCharArray()
        $setup = "s" -in $chars

        if ("w" -in $chars) { $buildWindows = $true; $buildLinux = $false }
        elseif ("l" -in $chars) { $buildWindows = $false; $buildLinux = $true }
        elseif ("b" -in $chars) { $buildWindows = $true; $buildLinux = $true }
        else { $buildWindows = $false; $buildLinux = $false }
    }
}

# -------------------
# Info
# -------------------
Write-Host "[INFO] Starting build for LOVE version $loveVersion ($bit-bit)"
Write-Host "[INFO] Setup is $($setup ? 'enabled' : 'disabled')."
switch ("$buildWindows$buildLinux") {
    "TrueTrue"   { Write-Host "[INFO] Building for Windows and Linux." }
    "TrueFalse"  { Write-Host "[INFO] Building for Windows only." }
    "FalseTrue"  { Write-Host "[INFO] Building for Linux only." }
    default      { Write-Host "[INFO] Building for none." }
}

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

if (-not $setup) {
    # Check if version's folder exists, i.e. $versionFolder + $loveVersion
    if (!(Test-Path (Join-Path $versionsFolder $loveVersion))) {
        $setup = $true
    }

    # Check Windows build integrity
    # https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip as reference
    if ($buildWindows) {
        # 1. Check Windows folder i.e. $binaries["win$bit"]
        # 2. Check Windows files and enable setup flag if missing any files
        foreach ($bit in @("32", "64")) {
            if (!(Test-Path $binaries["win$bit"])) {
                $setup = $true
            } else {
                foreach ($file in $windowsRequiredFiles) {
                    if (!(Test-Path (Join-Path $binaries["win$bit"] $file))) {
                        $setup = $true
                        Write-Host "[WARNING] Missing win$bit files, installing..."
                        break
                    }
                }
            }
        }
    }

    # Check Linux AppImage integrity
    # https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage as reference (no 32 bit)
    if ($buildLinux) {
        if (!(Test-Path $binaries["linux"])) {
            $setup = $true
            Write-Host "[WARNING] Missing linux files, installing..."
        }
    }
}

# -------------------
# Setup
# -------------------
if ($setup) {
    Write-Host "[INFO] Starting setup..."
    # Create Folders
    if (Test-Path $basePath) {
        Remove-Item -Path $basePath -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $basePath | Out-Null
    if (Test-Path $basePath) {
        Remove-Item -Path $basePath -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $basePath | Out-Null
    Write-Host "[INFO] Created folder: $basePath"

    # Windows
    # https://github.com/love2d/love/releases/download/11.5/love-11.5-win64.zip as reference
    # 1. Download
    # 2. Extract
    # 3. Rename folder to $binaries["win$bit"]
    foreach ($bit in @("32", "64")) {
        $url = "https://github.com/love2d/love/releases/download/$loveVersion/love-$loveVersion-win$bit.zip"
        $zipPath = Join-Path $basePath "love-$loveVersion-win$bit.zip"
        $expectedPath = Join-Path $basePath "love-$loveVersion-win$bit"

        Write-Host "[INFO] Downloading $url"
        Invoke-WebRequest -Uri $url -OutFile $zipPath
        Write-Host "[SUCCESS] Downloaded $url to $zipPath" 

        Write-Host "[INFO] Extracting $zipPath to $basePath"
        Expand-Archive -Path $zipPath -DestinationPath $basePath -Force
        Write-Host "[SUCCESS] Extracted $zipPath to $basePath"

        Write-Host "[INFO] Renaming $expectedPath to $($binaries["win$bit"])"
        Move-Item -Path $expectedPath -Destination $binaries["win$bit"] -Force
        Write-Host "[SUCCESS] Renamed $expectedPath to $($binaries["win$bit"])"
    }

    # Linux
    # https://github.com/love2d/love/releases/download/11.5/love-11.5-x86_64.AppImage as reference (no 32 bit)
    # 1. Download
    # 2. Rename file to $binaries["linux"]
    $url = "https://github.com/love2d/love/releases/download/$loveVersion/love-$loveVersion-x86_64.AppImage"
    $zipPath = Join-Path $basePath "love-$loveVersion-x86_64.AppImage"
    $expectedPath = Join-Path $basePath "love-$loveVersion-x86_64.AppImage"

    Write-Host "[INFO] Downloading $url"
    Invoke-WebRequest -Uri $url -OutFile $zipPath
    Write-Host "[SUCCESS] Downloaded $url to $zipPath" 

    Write-Host "[INFO] Renaming $expectedPath to $($binaries["linux"])"
    Move-Item -Path $expectedPath -Destination $binaries["linux"] -Force
    Move-Item -Path $expectedPath -Destination $binaries["linux"] -Force
    Write-Host "[SUCCESS] Renamed $expectedPath to $($binaries["linux"])"
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

# -------------------
# Build Windows
# -------------------
if ($buildWindows) {
    Write-Host "[INFO] Starting Windows build..."

    foreach ($bit in @("32", "64")) {
        Write-Host "[INFO] Building for win$bit..."
        # Prepare release folder for Windows
        $folder = Join-Path $releaseFolder "win$bit"
        if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }
        New-Item -ItemType Directory -Path $folder | Out-Null
        Write-Host "[INFO] Cleared previous win$bit builds."

        # Copy DLLs and support files
        Get-ChildItem $binaries["win$bit"] -Exclude "*.exe" -File -Recurse | ForEach-Object {
            Copy-Item $_.FullName -Destination $folder -Force
            Write-Host "[SUCCESS] Copied $($_.Name) to release folder."
        }

        # Append game.love to executables
        $exeFiles = @("love.exe", "lovec.exe")
        foreach ($exe in $exeFiles) {
            $exePath = Join-Path $binaries["win$bit"] $exe
            if (Test-Path $exePath) {
                $outputName = if ($exe -eq "lovec.exe") { "$appName-debug.exe" } else { "$appName.exe" }
                appendGameToFile $exePath $folder $outputName
            } else {
                Write-Warning "[WARN] $exe not found in $($binaries["win$bit"]), skipping."
            }
        }
        Write-Host "[INFO] Finished win$bit build."

        # Create release ZIP
        Write-Host "[INFO] Creating win$bit release ZIP..."
        $zipName = Join-Path $releaseFolder "$appName-win$bit.zip"
        if (Test-Path $zipName) { Remove-Item $zipName -Force }

        $releaseZip = [System.IO.Compression.ZipFile]::Open($zipName, "Create")
        Get-ChildItem $folder -Recurse -File | ForEach-Object {

            [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($releaseZip, $_.FullName, $_.Name) | Out-Null
            Write-Host "[SUCCESS] Added $($_.Name) to ZIP"
        }
        $releaseZip.Dispose()
        Write-Host "[SUCCESS] Created win$bit release ZIP: $zipName"
    }
}

# -------------------
# Build Linux
# -------------------
if ($buildLinux) {
    Write-Host "[INFO] Starting Linux build..."

    # Clear previous Linux AppImage
    $filePath = Join-Path $releaseFolder "$appName.AppImage"
    if (Test-Path $filePath) {
        Remove-Item $filePath -Force 
        Write-Host "[INFO] Cleared previous Linux build."
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

    Write-Host "[SUCCESS] Finished Linux build."
}