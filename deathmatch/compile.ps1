$root = Split-Path -Parent $PSScriptRoot
$source = Join-Path $PSScriptRoot "deathmatch.sma"
$compiler = Join-Path $root "cstrike\addons\amxmodx\scripting\amxxpc.exe"
$include = Join-Path $root "cstrike\addons\amxmodx\scripting\include"
$output = Join-Path $root "cstrike\addons\amxmodx\plugins\deathmatch.amxx"

& $compiler $source "-i$include" "-o$output"
exit $LASTEXITCODE
