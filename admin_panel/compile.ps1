$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $PSScriptRoot "admin_panel.sma"
$compiler = Join-Path $root "cstrike\addons\amxmodx\scripting\amxxpc.exe"
$include = Join-Path $root "cstrike\addons\amxmodx\scripting\include"
$output = Join-Path $root "cstrike\addons\amxmodx\plugins\admin_panel.amxx"

& $compiler $source "-i$include" "-o$output"
exit $LASTEXITCODE
