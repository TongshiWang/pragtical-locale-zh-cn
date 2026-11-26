$ErrorActionPreference = "Stop"

$candidates = @(
  (Join-Path $env:LOCALAPPDATA "Programs\Pragtical\user"),
  (Join-Path $env:APPDATA "pragtical"),
  (Join-Path $env:USERPROFILE ".config\pragtical")
)

$removed = $false
foreach ($userDir in $candidates) {
  if (Test-Path $userDir) {
    $target = Join-Path $userDir "plugins\locale_zh_cn"
    if (Test-Path $target) {
      Remove-Item -Recurse -Force $target
      Write-Host "Removed locale_zh_cn from: $target" -ForegroundColor Yellow
      $removed = $true
    }
  }
}

if ($removed) {
  Write-Host "Uninstalled locale_zh_cn. Restart Pragtical for changes to take effect." -ForegroundColor Green
} else {
  Write-Host "No locale_zh_cn installation found in standard Pragtical user directories."
}
