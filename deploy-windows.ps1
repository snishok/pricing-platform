$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest

function Resolve-DockerComposeCommand {
  if (Get-Command docker -ErrorAction SilentlyContinue) {
    try {
      docker compose version | Out-Null
      return @("docker", "compose")
    } catch {
      # fallthrough
    }
  }

  if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
    return @("docker-compose")
  }

  throw "Docker Compose not found. Install Docker Desktop (with Compose)."
}

function Invoke-Compose {
  param(
    [Parameter(Mandatory=$true)][string[]]$ComposeCmd,
    [Parameter(Mandatory=$true)][string[]]$Args
  )
  $cmd = $ComposeCmd + $Args
  & $cmd[0] $cmd[1..($cmd.Length-1)]
}

function Wait-HttpOk {
  param(
    [Parameter(Mandatory=$true)][string]$Url,
    [int]$TimeoutSeconds = 180
  )
  $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
  while ((Get-Date) -lt $deadline) {
    try {
      $res = Invoke-WebRequest -UseBasicParsing -TimeoutSec 5 -Uri $Url
      if ($res.StatusCode -ge 200 -and $res.StatusCode -lt 300) {
        return
      }
    } catch {
      Start-Sleep -Seconds 2
      continue
    }
    Start-Sleep -Seconds 2
  }
  throw "Timed out waiting for $Url"
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $repoRoot

$compose = Resolve-DockerComposeCommand

$profiles = @()
if ($env:TS_AUTHKEY) {
  $profiles += @("--profile", "tailscale")
}

Write-Host "Starting Docker stack..."
Invoke-Compose -ComposeCmd $compose -Args ($profiles + @("up", "-d", "--build"))

Write-Host "Waiting for API readiness..."
Wait-HttpOk -Url "http://localhost:8080/api/readyz" -TimeoutSeconds 240

Write-Host "Seeding demo data (10,000 products)..."
Invoke-Compose -ComposeCmd $compose -Args @("exec", "-T", "backend", "python", "-m", "app.cli.seed_demo_data", "--products", "10000")

Write-Host "Running backend tests..."
Invoke-Compose -ComposeCmd $compose -Args @("exec", "-T", "backend", "pytest", "-q")

Write-Host "Smoke check search endpoint..."
Wait-HttpOk -Url "http://localhost:8080/api/healthz" -TimeoutSeconds 30
Wait-HttpOk -Url "http://localhost:8080/api/pricing/search?q=Demo&per_page=1&page=1" -TimeoutSeconds 30

Write-Host ""
Write-Host "Deployed successfully."
Write-Host "- App:  http://localhost:8080"
Write-Host "- API:  http://localhost:8080/api/docs"
Write-Host ""
Write-Host "To stop: docker compose down"

