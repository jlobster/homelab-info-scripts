# collect-homelab-snapshots.ps1
# Generic homelab information collection script with configurable settings

# Simple .env file loader function
function Import-DotEnv {
    param([string]$Path = ".env")
    
    if (Test-Path $Path) {
        Get-Content $Path | ForEach-Object {
            if ($_ -match "^\s*([^#][^=]*?)=(.*)$") {
                $name = $matches[1].Trim()
                $value = $matches[2].Trim()
                # Remove surrounding quotes if present
                if ($value -match '^"(.*)"$' -or $value -match "^'(.*)'$") {
                    $value = $matches[1]
                }
                Set-Item -Path "env:$name" -Value $value
                Write-Verbose "Loaded environment variable: $name"
            }
        }
        Write-Host "Configuration loaded from $Path" -ForegroundColor Green
    } else {
        Write-Warning "Configuration file not found: $Path"
        Write-Warning "Copy .env.example to .env and customize for your environment"
        return $false
    }
    return $true
}

# Load configuration
$configLoaded = Import-DotEnv -Path ".env"
if (-not $configLoaded) {
    Write-Host "Exiting due to missing configuration file" -ForegroundColor Red
    exit 1
}

# Helper function to get environment variable with default
function Get-EnvVar {
    param(
        [string]$Name,
        [string]$Default = ""
    )
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { 
        return $value 
    } else { 
        return $Default 
    }
}

# Helper function to parse delimited configuration strings
function Parse-ConfigList {
    param(
        [string]$ConfigString,
        [string]$ItemSeparator = ";",
        [string]$ValueSeparator = ","
    )
    
    $results = @()
    if ($ConfigString) {
        $ConfigString.Split($ItemSeparator) | ForEach-Object {
            $parts = $_.Split($ValueSeparator)
            if ($parts.Length -ge 2) {
                # Ensure Values is always an array, even for single items
                $valueArray = @($parts[1..($parts.Length-1)] | ForEach-Object { $_.Trim() })
                $results += @{
                    Name = $parts[0].Trim()
                    Values = $valueArray
                }
            }
        }
    }
    return $results
}

# Load configuration values
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$defaultOutputBase = [Environment]::GetFolderPath('MyDocuments')
$outputBase = Get-EnvVar "HOMELAB_OUTPUT_BASE_DIR" $defaultOutputBase
$outputDir = Join-Path -Path $outputBase -ChildPath "Homelab\$timestamp"

$username = Get-EnvVar "HOMELAB_USERNAME" "admin"
$qnapScriptPath = Get-EnvVar "HOMELAB_QNAP_SCRIPT_PATH" "/share/homes/$username"
$piholeScriptPath = Get-EnvVar "HOMELAB_PIHOLE_SCRIPT_PATH" "/home/$username"
$piholeScript = Get-EnvVar "HOMELAB_PIHOLE_SCRIPT" "sysinfo-rpi.sh"
$piholeUseSudo = (Get-EnvVar "HOMELAB_PIHOLE_USE_SUDO" "true") -eq "true"
$openOutputDir = (Get-EnvVar "HOMELAB_OPEN_OUTPUT_DIR" "true") -eq "true"
$showProgress = (Get-EnvVar "HOMELAB_SHOW_PROGRESS" "true") -eq "true"

# Parse systems configuration
$systemsConfig = Get-EnvVar "HOMELAB_QNAP_SYSTEMS"
$systems = @()
if ($systemsConfig) {
    Parse-ConfigList $systemsConfig | ForEach-Object {
        $systems += @{
            Name = $_.Name
            IP = $_.Values[0]
        }
    }
}

# Parse tasks configuration
$tasksConfig = Get-EnvVar "HOMELAB_QNAP_TASKS"
$tasks = @()
if ($tasksConfig) {
    Parse-ConfigList $tasksConfig | ForEach-Object {
        $tasks += @{
            Label = $_.Name
            Remote = $_.Values[0]
            Suffix = if ($_.Values.Length -gt 1) { $_.Values[1] } else { "" }
        }
    }
}

# Pi-hole configuration
$piholeIP = Get-EnvVar "HOMELAB_PIHOLE_IP"
$piholeUser = Get-EnvVar "HOMELAB_PIHOLE_USER" $username

# Validate required configuration
if ($systems.Count -eq 0) {
    Write-Warning "No QNAP systems configured. Check HOMELAB_QNAP_SYSTEMS in .env file"
}
if ($tasks.Count -eq 0) {
    Write-Warning "No QNAP tasks configured. Check HOMELAB_QNAP_TASKS in .env file"
}

# Create output directory
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

if ($showProgress) {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Collecting Homelab Snapshots" -ForegroundColor Cyan
    Write-Host "Time: $timestamp" -ForegroundColor Cyan
    Write-Host "Output: $outputDir" -ForegroundColor Cyan
    Write-Host "Systems: $($systems.Count) QNAP$(if ($piholeIP) { ", 1 Pi-hole" })" -ForegroundColor Cyan
    Write-Host "============================================`n" -ForegroundColor Cyan
}

$count = 0
$total = $systems.Count + $(if ($piholeIP) { 1 } else { 0 })
$jobs = @()

# Process QNAP systems
foreach ($system in $systems) {
    $count++
    if ($showProgress) {
        Write-Host "[$count/$total] Queueing $($system.Name)..." -ForegroundColor Yellow
    }
    $jobs += Start-Job -ScriptBlock {
        param($user, $ip, $scriptPath, $taskList, $outputDir, $systemName)
        $results = @()
        foreach ($task in $taskList) {
            $outPath = Join-Path $outputDir "$systemName$($task.Suffix).txt"
            $output = ssh "$user@$ip" "sh $scriptPath/$($task.Remote)" 2>&1
            $output | Out-File -FilePath $outPath -Encoding utf8
            $results += [pscustomobject]@{
                System  = $systemName
                Label   = $task.Label
                Success = ($LASTEXITCODE -eq 0)
            }
        }
        return $results
    } -ArgumentList $username, $system.IP, $qnapScriptPath, $tasks, $outputDir, $system.Name
}

# Wait for QNAP jobs to complete
$qnapResults = @()
if ($jobs.Count -gt 0) {
    Wait-Job -Job $jobs | Out-Null
    $qnapResults = $jobs | Receive-Job
    $jobs | Remove-Job | Out-Null
}

# Display QNAP results
if ($showProgress) {
    foreach ($system in $systems) {
        Write-Host "Results from $($system.Name):" -ForegroundColor Yellow
        foreach ($task in $tasks) {
            $result = $qnapResults | Where-Object { $_.System -eq $system.Name -and $_.Label -eq $task.Label } | Select-Object -First 1
            if ($result -and $result.Success) {
                Write-Host "  $($task.Label): OK" -ForegroundColor Green
            } else {
                Write-Host "  $($task.Label): ERROR" -ForegroundColor Red
            }
        }
        Write-Host ""
    }
}

# Process Pi-hole if configured
if ($piholeIP) {
    $count++
    if ($showProgress) {
        Write-Host "[$count/$total] Collecting from Pi-hole..." -ForegroundColor Yellow
    }
    
    $sudoPrefix = if ($piholeUseSudo) { "sudo " } else { "" }
    $piholeCommand = "$sudoPrefix$piholeScriptPath/$piholeScript"
    $piholeOutput = ssh "$piholeUser@$piholeIP" $piholeCommand 2>&1
    $piholeOutput | Out-File -FilePath "$outputDir\pihole.txt" -Encoding utf8
    
    if ($showProgress) {
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  System info: OK" -ForegroundColor Green
        } else {
            Write-Host "  System info: ERROR" -ForegroundColor Red
        }
        Write-Host ""
    }
}

if ($showProgress) {
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Collection complete!" -ForegroundColor Green
    Write-Host "Files saved to: $outputDir" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

# Open output directory if configured
if ($openOutputDir) {
    explorer $outputDir
}