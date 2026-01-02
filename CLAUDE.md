# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains a collection of scripts for gathering system information from homelab infrastructure. The scripts are designed to collect comprehensive snapshots of system state across multiple networked devices including QNAP NAS systems and Raspberry Pi-hole servers.

## Architecture

The project consists of three main components:

1. **Main Collection Script** (`collect-homelab-snapshots.ps1`):
   - PowerShell script that orchestrates parallel data collection
   - Uses .env configuration for flexible deployment
   - Connects to remote systems via SSH
   - Creates timestamped output directories
   - Executes system information scripts on target devices

2. **QNAP System Scripts** (`qnap/`):
   - `sysinfo-qnap.sh`: Comprehensive QNAP system information (hardware, storage, network, packages)
   - `dockerinfo-qnap.sh`: Docker container and stack information for QNAP systems
   - `sysinfo-rpi.sh`: Raspberry Pi system information with Pi-hole specific data

3. **Configuration System**:
   - `.env.example`: Template configuration file
   - `.env`: User-specific configuration (create from example)
   - Built-in .env file parser (no external dependencies)

## Configuration Setup

### Initial Setup

1. Copy the example configuration:
```powershell
Copy-Item .env.example .env
```

2. Edit `.env` with your homelab details:
```bash
# SSH Connection Settings
HOMELAB_USERNAME=your_username
HOMELAB_QNAP_SCRIPT_PATH=/share/homes/your_username
HOMELAB_PIHOLE_SCRIPT_PATH=/home/your_username

# QNAP Systems (Name1,IP1;Name2,IP2;...)
HOMELAB_QNAP_SYSTEMS=YourQNAP1,192.168.1.10;YourQNAP2,192.168.1.11

# Pi-hole Configuration
HOMELAB_PIHOLE_IP=192.168.1.2
HOMELAB_PIHOLE_USER=your_pihole_user
```

### Configuration Variables

#### Connection Settings
- `HOMELAB_USERNAME`: SSH username for QNAP systems
- `HOMELAB_QNAP_SCRIPT_PATH`: Path where scripts are stored on QNAP
- `HOMELAB_PIHOLE_SCRIPT_PATH`: Path where scripts are stored on Pi-hole

#### System Definitions
- `HOMELAB_QNAP_SYSTEMS`: Semicolon-separated list of Name,IP pairs
- `HOMELAB_PIHOLE_IP`: IP address of Pi-hole system
- `HOMELAB_PIHOLE_USER`: SSH username for Pi-hole

#### Task Configuration
- `HOMELAB_QNAP_TASKS`: Tasks to run on QNAP systems (Label,Script,Suffix format)
- `HOMELAB_PIHOLE_SCRIPT`: Script name to run on Pi-hole
- `HOMELAB_PIHOLE_USE_SUDO`: Whether to use sudo for Pi-hole script

#### Behavior Settings
- `HOMELAB_OUTPUT_BASE_DIR`: Custom output directory (default: Documents)
- `HOMELAB_OPEN_OUTPUT_DIR`: Auto-open output folder when complete
- `HOMELAB_SHOW_PROGRESS`: Display progress messages

## Usage

### Running the Main Collection Script

```powershell
# Execute from repository directory (requires .env file)
.\collect-homelab-snapshots.ps1
```

The script will:
- Load configuration from `.env` file
- Create timestamped output directory
- Connect to all configured systems in parallel
- Generate individual text files for each system/service
- Display success/failure status for each collection task
- Open the output directory when complete (if configured)

### Manual Script Execution

Execute individual scripts directly on target systems:

```bash
# On QNAP systems (adjust paths per your .env)
sh /share/homes/your_username/sysinfo-qnap.sh
sh /share/homes/your_username/dockerinfo-qnap.sh

# On Raspberry Pi
sudo /home/your_username/sysinfo-rpi.sh
```

## Deployment

### Script Deployment

System information scripts should be deployed to paths specified in `.env`:
- QNAP systems: Value of `HOMELAB_QNAP_SCRIPT_PATH`
- Raspberry Pi: Value of `HOMELAB_PIHOLE_SCRIPT_PATH`

### Output Structure

Generated files follow the naming pattern:
- `{SystemName}.txt` - System information
- `{SystemName}-docker.txt` - Docker information (if Docker task configured)
- `pihole.txt` - Pi-hole system information (if Pi-hole configured)

## Key Features

### QNAP System Information
- Hardware specifications (CPU, memory, storage)
- RAID array status and health
- Storage pool and volume information
- QPKG (package) inventory with status
- Docker container and stack management via Dockge
- Network configuration and GPU acceleration status

### Pi-hole Information
- DNS configuration and upstream servers
- Client device inventory with MAC addresses
- Query statistics and top clients
- System health and resource usage
- Active network devices and DHCP status

### Error Handling
- Non-blocking SSH failures
- Individual task success/failure tracking
- Graceful degradation when services are unavailable
- Comprehensive error reporting in output files

## Security Considerations

- SSH key-based authentication required
- No credentials stored in scripts
- Read-only data collection operations
- Sudo access required only for Pi-hole database queries