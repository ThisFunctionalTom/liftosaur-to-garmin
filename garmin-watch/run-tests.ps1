param(
    [string]$SdkPath
)

if ([string]::IsNullOrWhiteSpace($SdkPath)) {
    $sdkConfigPath = Join-Path $env:APPDATA 'Garmin/ConnectIQ/current-sdk.cfg'
    if (-not (Test-Path -LiteralPath $sdkConfigPath -PathType Leaf)) {
        throw "Could not find the active SDK config at $sdkConfigPath. Pass -SdkPath explicitly."
    }
    $SdkPath = (Get-Content -LiteralPath $sdkConfigPath -Raw).Trim()
}

$SdkPath = [System.IO.Path]::GetFullPath($SdkPath)
$buildScript = Join-Path $PSScriptRoot 'build.ps1'
$simulatorLauncher = Join-Path $SdkPath 'bin/connectiq.bat'
$testLauncher = Join-Path $SdkPath 'bin/monkeydo.bat'
$testProgram = Join-Path $PSScriptRoot 'bin/Liftosaur-tests.prg'

foreach ($requiredPath in @($buildScript, $simulatorLauncher, $testLauncher)) {
    if (-not (Test-Path -LiteralPath $requiredPath -PathType Leaf)) {
        throw "Required Connect IQ tool not found: $requiredPath"
    }
}

Write-Host 'Building state-machine unit tests...'
& $buildScript -SdkPath $SdkPath -UnitTest
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host 'Starting the Connect IQ simulator...'
Start-Process -FilePath $simulatorLauncher -WorkingDirectory (Join-Path $SdkPath 'bin')
Start-Sleep -Seconds 5

Write-Host 'Running Liftosaur state-machine tests on fenix5...'
& $testLauncher $testProgram 'fenix5' /t
exit $LASTEXITCODE
