param([Parameter(Mandatory = $true)][string]$FactorioExe, [switch]$SpaceAge)
$ErrorActionPreference = 'Stop'
$source = Split-Path $PSScriptRoot -Parent
$root = Join-Path $env:TEMP ('pbb-integration-' + [guid]::NewGuid().ToString('N'))
$mod = Join-Path $root 'mods/ParallelBeltBuilder'
$utf8 = [Text.UTF8Encoding]::new($false)
foreach ($dir in @($mod, "$root/data", "$root/data/saves", "$root/data/mods", "$root/data/archive", "$root/data/temp", "$root/data/script-output", "$root/data/scenarios")) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
Copy-Item "$source/info.json", "$source/data.lua", "$source/control.lua" -Destination $mod
Copy-Item "$source/scripts", "$source/graphics", "$source/locale", $PSScriptRoot -Destination $mod -Recurse
$control = [IO.File]::ReadAllText("$mod/control.lua")
$control = 'local run_integration = require("tests.integration")' + "`n" + $control
$control = $control.Replace('  state.init()', '  state.init()' + "`n" + '  run_integration()')
$control += @'

script.on_nth_tick(1, function()
  local p = storage.players[storage.pbb_test_player]
  assert(p.count == 7 and p.side == "left" and p.placement == "normal", "saved settings")
  assert(p.plan and #p.preview_objects > 0 and p.preview_objects[1].valid, "saved plan/preview")
  log("PBB RELOAD PASS")
  script.on_nth_tick(1, nil)
end)
'@
[IO.File]::WriteAllText("$mod/control.lua", $control, $utf8)
$data = Join-Path (Split-Path (Split-Path (Split-Path $FactorioExe -Parent) -Parent) -Parent) 'data'
$config = "[path]`nread-data=$($data.Replace('\','/'))`nwrite-data=$($root.Replace('\','/'))/data`n"
[IO.File]::WriteAllText("$root/config.ini", $config, $utf8)
$names = @('base', 'ParallelBeltBuilder')
if ($SpaceAge) { $names += @('quality', 'elevated-rails', 'space-age', 'recycler') }
$mods = @{mods = @(@('base', 'ParallelBeltBuilder', 'quality', 'elevated-rails', 'space-age', 'recycler') | ForEach-Object { @{name = $_; enabled = $_ -in $names} })} | ConvertTo-Json -Depth 4
[IO.File]::WriteAllText("$root/mods/mod-list.json", $mods, $utf8)
$common = @('--config', "$root/config.ini", '--mod-directory', "$root/mods", '--disable-audio')
Write-Output "Test artifacts: $root"
function Invoke-TestFactorio($extra, $label) {
    $arguments = @($common + $extra | ForEach-Object { '"' + $_ + '"' })
    $process = Start-Process -FilePath $FactorioExe -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput "$root/$label.log" -RedirectStandardError "$root/$label-error.log"
    $result = @(Get-Content "$root/$label.log") + @(Get-Content "$root/$label-error.log")
    if ($process.ExitCode -ne 0) { $result | Select-Object -Last 40 | Write-Host; throw "$label failed" }
    return $result
}
$output = Invoke-TestFactorio @('--create', "$root/test.zip") 'create'
if (!($output -match 'PBB INTEGRATION PASS')) { $output | Select-Object -Last 40; throw 'Integration failed' }
$output | Select-String 'PBB INTEGRATION PASS'
$output = Invoke-TestFactorio @('--benchmark', "$root/test.zip", '--benchmark-ticks', '2', '--benchmark-runs', '1') 'reload'
if (!($output -match 'PBB RELOAD PASS')) { $output | Select-Object -Last 40; throw 'Reload failed' }
$output | Select-String 'PBB RELOAD PASS'
