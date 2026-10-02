# Builds the addon textures from media\icon-source.jpg:
#   media\icon.tga  64x64 uncompressed 32-bit TGA (AddOns list, minimap button, title bars)
#   media\logo.png  512x512 (README, addon sites)
param(
	[string]$Source = (Join-Path $PSScriptRoot '..\media\icon-source.jpg')
)
Add-Type -AssemblyName System.Drawing
$media = Join-Path $PSScriptRoot '..\media'

function Resize([System.Drawing.Image]$img, [int]$size) {
	$bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
	$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
	$g.DrawImage($img, 0, 0, $size, $size)
	$g.Dispose()
	return $bmp
}

function Write-Tga([System.Drawing.Bitmap]$bmp, [string]$path) {
	$w = $bmp.Width
	$h = $bmp.Height
	$out = New-Object byte[] (18 + $w * $h * 4)
	$out[2] = 2                      # uncompressed true colour
	$out[12] = $w -band 0xFF; $out[13] = $w -shr 8
	$out[14] = $h -band 0xFF; $out[15] = $h -shr 8
	$out[16] = 32                    # bits per pixel
	$out[17] = 0x28                  # 8 alpha bits, top-left origin
	$i = 18
	for ($y = 0; $y -lt $h; $y++) {
		for ($x = 0; $x -lt $w; $x++) {
			$c = $bmp.GetPixel($x, $y)
			$out[$i] = $c.B; $out[$i + 1] = $c.G; $out[$i + 2] = $c.R; $out[$i + 3] = $c.A
			$i += 4
		}
	}
	[IO.File]::WriteAllBytes($path, $out)
}

$img = [System.Drawing.Image]::FromFile((Resolve-Path $Source))
try {
	$icon = Resize $img 64
	Write-Tga $icon (Join-Path $media 'icon.tga')
	$icon.Dispose()
	$logo = Resize $img 512
	$logo.Save((Join-Path $media 'logo.png'), [System.Drawing.Imaging.ImageFormat]::Png)
	$logo.Dispose()
} finally {
	$img.Dispose()
}
Get-ChildItem $media | Select-Object Name, Length
