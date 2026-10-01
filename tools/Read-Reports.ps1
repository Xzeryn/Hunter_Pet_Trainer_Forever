# Decodes in-game data reports (HPTZ1: zlib+base64, HPTB1: base64) from GitHub issues.
#   tools\Read-Reports.ps1              open issues labelled data-report
#   tools\Read-Reports.ps1 -Number 12   one issue
#   tools\Read-Reports.ps1 -Text '...'  a pasted report
param(
	[int]$Number,
	[string]$Text,
	[string]$Repo = 'Xzeryn/Hunter_Pet_Trainer_Forever'
)

function ConvertFrom-HptReport([string]$body) {
	$m = [regex]::Match($body, 'HPT([ZB])1:\s*([A-Za-z0-9_\-\s]+)')
	if (-not $m.Success) {
		return $body
	}
	$b64 = ($m.Groups[2].Value -replace '\s', '').Replace('-', '+').Replace('_', '/')
	switch ($b64.Length % 4) {
		2 { $b64 += '==' }
		3 { $b64 += '=' }
	}
	$bytes = [Convert]::FromBase64String($b64)
	if ($m.Groups[1].Value -eq 'B') {
		return [Text.Encoding]::UTF8.GetString($bytes)
	}
	# Zlib = 2-byte header + raw deflate + checksum; DeflateStream reads the middle.
	$ms = New-Object IO.MemoryStream(, $bytes)
	$ms.Position = 2
	$ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionMode]::Decompress)
	$reader = New-Object IO.StreamReader($ds, [Text.Encoding]::UTF8)
	try {
		return $reader.ReadToEnd()
	} finally {
		$reader.Dispose()
	}
}

if ($Text) {
	ConvertFrom-HptReport $Text
	return
}

if ($Number) {
	$issues = @(gh issue view $Number --repo $Repo --json number,title,body | ConvertFrom-Json)
} else {
	$issues = @(gh issue list --repo $Repo --label data-report --state open --json number,title,body | ConvertFrom-Json)
}
foreach ($issue in $issues) {
	"=== #$($issue.number) $($issue.title) ==="
	ConvertFrom-HptReport $issue.body
	''
}
