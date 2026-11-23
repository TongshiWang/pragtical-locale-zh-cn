$ErrorActionPreference = "Stop"

$candidates = @(
  (Join-Path $env:LOCALAPPDATA "Programs\Pragtical\user"),
  (Join-Path $env:APPDATA "pragtical"),
  (Join-Path $env:USERPROFILE ".config\pragtical")
)

$userDir = $candidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $userDir) {
  $userDir = Join-Path $env:LOCALAPPDATA "Programs\Pragtical\user"
}

$target = Join-Path $userDir "plugins\locale_zh_cn"
New-Item -ItemType Directory -Force -Path $target | Out-Null
Copy-Item -Force "$PSScriptRoot\plugins\locale_zh_cn\*.lua" $target

Write-Host "Installed locale_zh_cn to: $target" -ForegroundColor Green
Write-Host "Please restart Pragtical to apply Simplified Chinese localization."
