# Version 1.0.1

# -------------------
# Configuration
# -------------------
$appName = "game"
$require = @("main.lua")

$buildFolder = "build"
$versionsFolder = Join-Path $buildFolder "version"
$releaseFolder = Join-Path $buildFolder "release"
$loveZip = Join-Path $releaseFolder "${appName}.love"

$love2dVersion = "11.5"
$buildWindows = $true
$buildLinux = $true

# Windows specific files required for build
$windowsRequiredFiles = @(
    "game.ico", "license.txt", "love.dll", "love.exe", "love.ico",
    "lovec.exe", "lua51.dll", "mpg123.dll", "msvcp120.dll",
    "msvcr120.dll", "OpenAL32.dll", "SDL2.dll"
)

# OS-specific binary paths
$basePath = Join-Path $versionsFolder $love2dVersion
$binaries = @{
    "windows" = Join-Path $basePath "windows"
    "linux"   = Join-Path $basePath "linux.AppImage"
}

Write-Host "[INFO] Starting build for LÖVE version $love2dVersion"
Write-Host "[INFO] Windows: $buildWindows, Linux: $buildLinux"

# -------------------
# Helper Functions
# -------------------
function appendGameToFile($filePath, $releaseFolder, $name) {
    $outPath = Join-Path $releaseFolder "$name.exe"
    Write-Host "[INFO] Processing $outPath"

    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $gameBytes = [System.IO.File]::ReadAllBytes($loveZip)
    [System.IO.File]::WriteAllBytes($outPath, $fileBytes + $gameBytes)

    Write-Host "[SUCCESS] $appName.love appended to $outPath"
}

# -------------------
# Prepare Directories
# -------------------
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

foreach ($file in $require) {
    if (Test-Path $file) {
        $zipEntryName = ($file -replace '\\', '/') -replace '^\./', ''
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $file, $zipEntryName) | Out-Null
        Write-Host "[INFO] Added $file to $loveZip"
    } else {
        Write-Warning "[WARN] Required file not found: $file"
    }
}
$zip.Dispose()
Write-Host "[SUCCESS] Created game.love archive."

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
            $outputName = if ($exe -eq "lovec.exe") { "$appName-debug" } else { $appName }
            appendGameToFile $exePath $folder $outputName
        } else {
            Write-Warning "[WARN] $exe not found in $windowsBinaries, skipping."
        }
    }

    Write-Host "[SUCCESS] Windows build complete"

    # Create release ZIP
    Write-Host "[INFO] Creating Windows release ZIP..."
    $zipName = Join-Path $releaseFolder "$appName-windows-x86-64.zip"
    if (Test-Path $zipName) { Remove-Item $zipName -Force }

    $releaseZip = [System.IO.Compression.ZipFile]::Open($zipName, "Create")
    Get-ChildItem $folder -Recurse -File | ForEach-Object {
        $zipEntryName = $_.Name
        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($releaseZip, $_.FullName, $zipEntryName) | Out-Null
        $rel = [System.IO.Path]::GetRelativePath($buildFolder, $_.FullName) -replace '\\','/'
        Write-Host "[SUCCESS] Added build/$rel to ZIP"
    }
    $releaseZip.Dispose()
    Write-Host "[SUCCESS] Created Windows release ZIP: $zipName"
    Write-Host "[SUCCESS] Finished Windows build."
} else {
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
    Copy-Item $linuxBinary -Destination $filePath -Force
    Write-Host "[INFO] Copied $appName.AppImage to $releaseFolder"

    # Append game.love to the AppImage (in-place, no ZIP)
    $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
    $gameBytes = [System.IO.File]::ReadAllBytes($loveZip)
    [System.IO.File]::WriteAllBytes($appImageDest, $fileBytes + $gameBytes)
    Write-Host "[SUCCESS] Appended $appName.love to $filePath"

    # Try to set executable bit on Linux only
    if ($IsLinux)  {
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            & chmod +x $appImageDest
        }
    }

    Write-Host "[SUCCESS] Finished Linux build."
}