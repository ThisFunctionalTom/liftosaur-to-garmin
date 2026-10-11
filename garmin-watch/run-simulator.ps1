param(
    [string]$SdkPath,
    [string]$ProgramPath = (Join-Path $PSScriptRoot 'bin/Liftosaur.prg'),
    [string]$DeviceId = 'fenix5'
)

if ([string]::IsNullOrWhiteSpace($SdkPath)) {
    $sdkConfigPath = Join-Path $env:APPDATA 'Garmin/ConnectIQ/current-sdk.cfg'
    if (-not (Test-Path -LiteralPath $sdkConfigPath -PathType Leaf)) {
        throw "Could not find the active SDK config at $sdkConfigPath. Pass -SdkPath explicitly."
    }

    $SdkPath = (Get-Content -LiteralPath $sdkConfigPath -Raw).Trim()
    if ([string]::IsNullOrWhiteSpace($SdkPath)) {
        throw "The active SDK config is empty: $sdkConfigPath"
    }
}

$SdkPath = [System.IO.Path]::GetFullPath($SdkPath)
$buildScript = Join-Path $PSScriptRoot 'build.ps1'
if (-not (Test-Path -LiteralPath $buildScript -PathType Leaf)) {
    throw "Could not find the build script at $buildScript"
}

Write-Host 'Building Liftosaur...'
& $buildScript -SdkPath $SdkPath
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}

$ProgramPath = [System.IO.Path]::GetFullPath($ProgramPath)
$sdkBin = Join-Path $SdkPath 'bin'
$simulatorLauncher = Join-Path $sdkBin 'connectiq.bat'
$appLauncher = Join-Path $sdkBin 'monkeydo.bat'
$settingsPath = Join-Path $PSScriptRoot 'bin/Liftosaur-settings.json'

if (-not (Test-Path -LiteralPath $ProgramPath -PathType Leaf)) {
    throw "Could not find the built app at $ProgramPath. Build it first with .\build.ps1."
}
if (-not (Test-Path -LiteralPath $simulatorLauncher -PathType Leaf)) {
    throw "Could not find the simulator launcher at $simulatorLauncher"
}
if (-not (Test-Path -LiteralPath $appLauncher -PathType Leaf)) {
    throw "Could not find monkeydo.bat at $appLauncher"
}
if (-not (Test-Path -LiteralPath $settingsPath -PathType Leaf)) {
    throw "Could not find app settings metadata at $settingsPath. Build the app first with .\build.ps1."
}

Write-Host 'Starting the Connect IQ simulator...'
Start-Process -FilePath $simulatorLauncher -WorkingDirectory $sdkBin
Start-Sleep -Seconds 5

Write-Host "Launching Liftosaur on $DeviceId..."
Push-Location $PSScriptRoot
try {
    & $appLauncher $ProgramPath $DeviceId /a 'bin/Liftosaur-settings.json;GARMIN/Settings/LIFTOSAUR-settings.json'
} finally {
    Pop-Location
}
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
