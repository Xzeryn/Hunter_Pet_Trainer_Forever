# Builds dist\Hunter_Pet_Trainer_Forever-<version>.zip for manual CurseForge uploads.
# Contains only what the game needs: the .toc, every file it loads, the icon, LICENSE, README.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem

$name = 'Hunter_Pet_Trainer_Forever'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$toc = Join-Path $root "$name.toc"

$version = (Select-String -Path $toc -Pattern '^## Version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
$files = @("$name.toc", 'media/icon.tga', 'LICENSE', 'README.md')
$files += Get-Content $toc | Where-Object { $_ -match '^\s*[^#\s].*\.(lua|xml)\s*$' } | ForEach-Object { $_.Trim() }

$dist = Join-Path $root 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null
$zipPath = Join-Path $dist "$name-$version.zip"
if (Test-Path $zipPath) {
	Remove-Item $zipPath
}

# Entries use forward slashes under a top-level folder so the zip unpacks straight into Interface\AddOns.
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
try {
	foreach ($file in $files) {
		$path = Join-Path $root $file
		if (-not (Test-Path $path)) {
			throw "Missing file listed for the release: $file"
		}
		[void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $path, "$name/$($file -replace '\\', '/')", 'Optimal')
	}
} finally {
	$zip.Dispose()
}

"Built $zipPath"
$files | ForEach-Object { "  $name/$_" }
