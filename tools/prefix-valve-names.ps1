$root = Split-Path -Parent $PSScriptRoot
$path = if ($args.Count -gt 0) { $args[0] } else { Join-Path $root "cstrike\BotProfile.db" }

if (-not (Test-Path -LiteralPath $path)) {
	Write-Error "Файл не найден: $path"
	exit 1
}

$text = [System.IO.File]::ReadAllText($path)
$newline = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = $text -split "`r`n|`n", -1
$changed = 0

for ($i = 0; $i -lt $lines.Length; $i++) {
	if ($lines[$i] -match '^(\S+)\s+"([^"]+)"\s*$') {
		$name = $Matches[2]
		if ($name.StartsWith("Valve Bot ")) {
			continue
		}
		$lines[$i] = '{0} "{1}"' -f $Matches[1], "Valve Bot $name"
		$changed++
	}
}

if ($changed -gt 0) {
	$endsWithNewline = $text.EndsWith("`n")
	$output = ($lines -join $newline)
	if ($endsWithNewline -and -not $output.EndsWith($newline)) {
		$output += $newline
	}
	$utf8 = New-Object System.Text.UTF8Encoding $false
	[System.IO.File]::WriteAllText($path, $output, $utf8)
}

Write-Output "Обновлено ников: $changed"
exit 0
