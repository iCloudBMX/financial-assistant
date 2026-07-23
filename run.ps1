#!/usr/bin/env pwsh
# One command to run the app on the Android emulator: boot it, deps + drift codegen, launch.
$ErrorActionPreference = 'Stop'

function Get-Emulator { (adb devices | Select-String 'emulator-\d+\s+device') -replace '\s+device','' -replace '\s','' | Select-Object -First 1 }

$sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME } else { "$env:LOCALAPPDATA\Android\Sdk" }
$emuExe = "$sdk\emulator\emulator.exe"

$serial = Get-Emulator
if (-not $serial) {
    $emu = & $emuExe -list-avds | Where-Object { $_.Trim() } | Select-Object -First 1
    if (-not $emu) { throw "No Android emulator found. Create one in Android Studio." }
    Write-Host "Booting emulator: $emu"
    # Software GPU (swiftshader): host-GPU mode crashes this AVD ('error: closed' / unsupported).
    Start-Process $emuExe -ArgumentList '-avd', $emu, '-gpu', 'swiftshader_indirect', '-no-boot-anim'
    # Wait for it to reach 'device' state + finish booting (cold boot can take ~2 min).
    $deadline = (Get-Date).AddSeconds(240)
    while (-not ($serial = Get-Emulator)) {
        if ((Get-Date) -gt $deadline) { throw "Emulator did not come online within 4 min." }
        Start-Sleep 3
    }
    while ((adb -s $serial shell getprop sys.boot_completed 2>$null).Trim() -ne '1') {
        if ((Get-Date) -gt $deadline) { throw "Emulator booted but never finished starting." }
        Start-Sleep 3
    }
}
Write-Host "Using device: $serial"

flutter pub get
dart run build_runner build
flutter run -d $serial @args
