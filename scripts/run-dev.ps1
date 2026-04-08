param(
  [string]$Device = "",
  [switch]$SkipBackend,
  [switch]$SkipFlutter
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$backendRoot = Join-Path $repoRoot 'backend'
$pythonExe = Join-Path $repoRoot '.venv\Scripts\python.exe'

if (-not (Test-Path $pythonExe)) {
  throw "Python not found at $pythonExe. Create the venv first."
}

if (-not $SkipBackend) {
  $backendLog = Join-Path $backendRoot 'backend.log'
  $backendCommand = "Set-Location '$backendRoot'; & '$pythonExe' -m uvicorn main:app --host 0.0.0.0 --port 8000 --reload *>> '$backendLog'"
  Start-Process -FilePath powershell -ArgumentList @('-NoExit', '-Command', $backendCommand) -WorkingDirectory $backendRoot | Out-Null
  Write-Host "Backend starting on http://127.0.0.1:8000"
}

if (-not $SkipFlutter) {
  Set-Location $repoRoot
  $flutterArgs = @('run')
  if ($Device.Trim()) {
    $flutterArgs += @('-d', $Device.Trim())
  }

  $flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
  if (-not $flutterCommand) {
    throw 'Flutter SDK is not on PATH.'
  }

  & flutter @flutterArgs
}
