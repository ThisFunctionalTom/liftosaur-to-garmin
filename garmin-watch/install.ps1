param(
    [string]$SdkPath,
    [string]$DeveloperKey,
    [string]$WatchDrive = 'F:'
)

$buildScript = Join-Path $PSScriptRoot 'build.ps1'
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Could not find the build script at $buildScript"
}

$driveRoot = $WatchDrive.Trim().TrimEnd('\', '/')
if ($driveRoot -notmatch '^[A-Za-z]:$') {
    throw "WatchDrive must be a drive letter such as F: or F:\ (received '$WatchDrive')."
}
$appsPath = Join-Path "$driveRoot\" 'GARMIN/APPS'
if (-not (Test-Path -LiteralPath $appsPath -PathType Container)) {
    throw "Garmin watch app folder not found at $appsPath. Make sure the watch is mounted as a drive and pass -WatchDrive if it is not F:."
}

Write-Host 'Building Liftosaur...'
$buildArgs = @{}
if (-not [string]::IsNullOrWhiteSpace($SdkPath)) { $buildArgs.SdkPath = $SdkPath }
if (-not [string]::IsNullOrWhiteSpace($DeveloperKey)) { $buildArgs.DeveloperKey = $DeveloperKey }
& $buildScript @buildArgs
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$programPath = Join-Path $PSScriptRoot 'bin/Liftosaur.prg'
if (-not (Test-Path -LiteralPath $programPath -PathType Leaf)) {
    throw "Build completed without producing $programPath"
}

$destinationPath = Join-Path $appsPath 'Liftosaur.prg'
Copy-Item -LiteralPath $programPath -Destination $destinationPath -Force
Write-Host "Installed Liftosaur to $destinationPath"
Write-Host 'Eject the watch safely, then disconnect it to finish installation.'
