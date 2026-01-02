#!/bin/sh

echo "=== DATE ==="
date
echo

echo "=== QNAP SYSTEM ==="
uname -a
getcfg system "Model"
getcfg system "Version"
getcfg system "Platform"
echo

echo "=== CPU INFO ==="
cat /proc/cpuinfo
echo

echo "=== MEMORY (RAM) ==="
free -h 2>/dev/null || cat /proc/meminfo
echo

echo "=== STORAGE SUMMARY ==="
df -h /share/CACHEDEV1_DATA 2>/dev/null
echo ""
echo "Thin Pool Status:"
lvs -o lv_name,vg_name,lv_size,data_percent,metadata_percent vg1/tp1 2>/dev/null | grep -v WARNING
echo ""
echo "Cache Tier Status:"
lvs -o lv_name,vg_name,lv_size,data_percent,metadata_percent vg256/lv256 2>/dev/null | grep -v WARNING
echo ""

echo "=== STORAGE POOLS ==="
cat /proc/mdstat 2>/dev/null || echo "RAID info not available"
echo ""

echo "=== STORAGE VOLUMES ==="
# Volume information
/sbin/getcfg -f /etc/config/smb.conf 2>/dev/null | grep -E "^\[|path" || echo "Volume config not readable"
echo

echo "=== DISK USAGE (DF) ==="
df -h | grep -E 'Filesystem|/dev/md|/share/CACHEDEV'
echo

echo "=== PHYSICAL DISKS ==="
/sbin/hal_app --pd_enum enc_id=0 2>/dev/null || echo "Physical disk info not available"
echo ""

echo "=== MDADM ARRAYS ==="
# RAID array details
cat /proc/mdstat 2>/dev/null || echo "No MD arrays found"
echo

echo "=== BLOCK DEVICES ==="
# All block devices
lsblk 2>/dev/null || echo "lsblk not available"
echo

echo "=== SMART STATUS (BRIEF) ==="
# HDDs: Use hdparm for temperature and health
for dev in /dev/sd[a-e]; do
    [ -b "$dev" ] || continue
    device_name=$(basename "$dev")
    echo "Device: $dev"
    hdparm -H "$dev" 2>&1 | grep -E "temperature|range" | sed 's/^/  /'
done

# NVMe: Note requires web UI or check /tmp/smart files
if [ -b /dev/nvme0n1 ]; then
    echo "Device: /dev/nvme0n1"
    if [ -f /tmp/smart/smart_0_1.info ]; then
        temp_line=$(grep "Composite Temperature" /tmp/smart/smart_0_1.info 2>/dev/null)
        if [ -n "$temp_line" ]; then
            temp_raw=$(echo "$temp_line" | cut -d',' -f6)
            temp_c=$((temp_raw / 10 - 273))  # Convert from Kelvin*10 to Celsius
            echo "  drive temperature (celsius) is:  $temp_c"
        fi
    else
        echo "  SMART data available in QTS web interface"
    fi
fi
echo ""

echo "=== QNAP PACKAGES (QPKG) ==="

# Parse qpkg.conf for detailed status
if [ -f /etc/config/qpkg.conf ]; then
    echo "-- Installed QPKGs (Status & Version) --"
    awk '
    BEGIN { pkg="" }
    /^\[.*\]/ { 
        if (pkg != "") print ""
        pkg = $0
        gsub(/[\[\]]/, "", pkg)
        printf "Package: %s\n", pkg
    }
    /^Enable =/ { printf "  Status: %s\n", ($3 == "TRUE" ? "ENABLED" : "DISABLED") }
    /^Version =/ { printf "  Version: %s\n", $3 }
    /^Date =/ { printf "  Installed: %s\n", $3 }
    /^Shell =/ { printf "  Shell: %s\n", $3 }
    ' /etc/config/qpkg.conf
    echo ""
fi

echo "-- QPKG Summary --"
if [ -f /etc/config/qpkg.conf ]; then
    total=$(grep -c '^\[' /etc/config/qpkg.conf)
    enabled=$(grep -E "^\[|^Enable" /etc/config/qpkg.conf | awk '/^\[/ {pkg=$0} /^Enable/ && $3 == "TRUE" {count++} END {print count}')
    disabled=$((total - enabled))
    echo "Total QPKGs: $total"
    echo "  Enabled:   $enabled"
    echo "  Disabled:  $disabled"
    echo ""
fi

echo "-- Key System Services --"
for svc in smb.sh nfs.sh apache.sh ssh.sh crond.sh syslog-ng.sh; do
    if [ -f "/etc/init.d/$svc" ]; then
        printf "%-20s [PRESENT]\n" "$svc"
    fi
done
echo

echo "=== CONTAINER STATION / DOCKER STATUS ==="
# Container Station status
if /sbin/getcfg "container-station" Enable -f /etc/config/qpkg.conf 2>/dev/null | grep -q TRUE; then
    echo "Container Station: ENABLED"
    echo "Version: $(/sbin/getcfg "container-station" Version -f /etc/config/qpkg.conf 2>/dev/null)"
    echo "Install Date: $(/sbin/getcfg "container-station" Date -f /etc/config/qpkg.conf 2>/dev/null)"
else
    echo "Container Station: DISABLED or not installed"
fi
echo

echo "=== CONTAINER NETWORK BRIDGES ==="
# More detail on Docker networks
ip addr show | grep -A 2 "^[0-9]*: br-" 2>/dev/null || echo "No Docker bridges found"
echo

echo "=== NETWORK INTERFACES ==="
ip addr 2>/dev/null || ifconfig -a
echo

echo "=== LISTENING PORTS (HOST) ==="
ss -tulpen 2>/dev/null || netstat -tulpen
echo

echo "=== ROUTES ==="
ip route 2>/dev/null || netstat -rn
echo

echo "=== GPU / ACCELERATORS (QNAP / NVIDIA) ==="

echo "-- Loaded NVIDIA kernel modules --"
lsmod | grep -Ei '^nvidia|nvidia_' || echo "No NVIDIA modules loaded"
echo

echo "-- NVIDIA GPU information (kernel-exposed) --"
if [ -d /proc/driver/nvidia/gpus ]; then
  for g in /proc/driver/nvidia/gpus/*; do
    echo "GPU: $g"
    cat "$g/information"
    echo
  done
else
  echo "No /proc/driver/nvidia/gpus directory found"
fi

echo "-- NVIDIA device nodes --"
ls -l /dev | grep -Ei 'nvidia|dri' || echo "No NVIDIA device nodes found"
echo

echo "-- PCI visibility (best-effort, informational only) --"
lspci 2>/dev/null | grep -Ei 'vga|3d|display|nvidia' || echo "GPU not exposed via lspci (expected on QTS)"
