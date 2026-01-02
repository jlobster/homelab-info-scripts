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

echo "=== DISK INVENTORY & SMART  ==="
# (QNAP-native)
echo
if [ -x /sbin/qcli_storage ]; then
  echo "--- DISK TOPOLOGY ---"
  /sbin/qcli_storage -p
else
  echo "qcli_storage not available"
fi
echo

echo "--- PHYSICAL DISKS ---"
/sbin/hal_app --pd_enum enc_id=0 2>/dev/null
echo ""

echo "--- PHYSICAL ENCLOSURES ---"
for f in /etc/enclosure_*.conf; do
  [ -f "$f" ] || continue
  echo
  echo "-- $f"
  sed 's/^/  /' "$f"
done

## SMART status no longer natively available via CLI, requires smartctl, which needs to be installed via Entware
# if [ -x /sbin/get_hd_smartinfo ]; then
#   echo
#   echo "--- SMART PER DISK SLOT ---"
#   for disk in $(/sbin/qcli_storage -p 2>/dev/null | awk '/^[0-9]+/ {print $1}'); do
#     echo
#     echo "--- DISK SLOT $disk ---"
#     /sbin/get_hd_smartinfo -d "$disk"
#   done
# else
#   echo "get_hd_smartinfo not available"
# fi
# echo

echo "--- BLOCK DEVICES ---"
echo "--- /proc/partitions ---"
cat /proc/partitions 2>/dev/null || echo "Not available"
echo

## fdisk requires admin/root on QNAP (block devices not accessible to non-root users)
# if command -v fdisk >/dev/null 2>&1; then
#   echo "--- fdisk -l ---"
#   fdisk -l 2>/dev/null
# else
#   echo "fdisk not available"
# fi
# echo

echo "=== STORAGE POOLS ==="
# RAID array details
cat /proc/mdstat 2>/dev/null || echo "No MD arrays found"
echo

echo "=== STORAGE VOLUMES ==="
echo "--- THIN POOL STATUS ---"
lvs -o lv_name,vg_name,lv_size,data_percent,metadata_percent vg1/tp1 2>/dev/null | grep -v WARNING
echo ""

echo "--- CACHE TIER STATUS ---"
lvs -o lv_name,vg_name,lv_size,data_percent,metadata_percent vg256/lv256 2>/dev/null | grep -v WARNING
echo ""

echo "--- VOLUME DEFINITIONS ---"
if [ -f /etc/volume.conf ]; then
  awk '
    /^\[VOL_/ { print "\n" $0 }
    /volName|raidName|mappingName|internal|filesystem|raidLevel|ssdCache/ {
      printf "  %-14s %s\n", $1, $3
    }
  ' /etc/volume.conf
else
  echo "/etc/volume.conf not found"
fi
echo

echo "--- SSD CACHE (CACHEDEV / DM-CACHE) ---"
if ls /sys/block/dm-* >/dev/null 2>&1; then
  for dm in /sys/block/dm-*; do
    echo
    echo "--- $(basename "$dm") ---"
    cat "$dm/dm/name" 2>/dev/null
    cat "$dm/dm/uuid" 2>/dev/null
  done
else
  echo "No dm-cache devices detected"
fi
echo

echo "=== STORAGE FILESYSTEMS ==="
echo "--- DISK USAGE (DF) ---"
df -h 2>/dev/null | grep -E 'Filesystem|/dev/md|/share/CACHEDEV'
echo

echo "=== STORAGE CONSUMERS ==="
echo "--- SMB SHARES ---"
if [ -f /etc/config/smb.conf ]; then
  awk '
    /^\[/ && $0 !~ /global/ { print "\n" $0 }
    /path =/ { print "  " $0 }
  ' /etc/config/smb.conf
else
  echo "smb.conf not found"
fi
echo

echo "=== INSTALLED QPKGS (STATUS & VERSION) ==="
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

echo "--- QPKG SUMMARY ---"
if [ -f /etc/config/qpkg.conf ]; then
    total=$(grep -c '^\[' /etc/config/qpkg.conf)
    enabled=$(grep -E "^\[|^Enable" /etc/config/qpkg.conf | awk '/^\[/ {pkg=$0} /^Enable/ && $3 == "TRUE" {count++} END {print count}')
    disabled=$((total - enabled))
    echo "Total QPKGs: $total"
    echo "  Enabled:   $enabled"
    echo "  Disabled:  $disabled"
    echo ""
fi

echo "=== KEY SYSTEM SERVICES ==="
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
if command -v ss >/dev/null 2>&1; then
  ss -tuln
elif command -v netstat >/dev/null 2>&1; then
  netstat -tuln
else
  echo "No socket inspection tool available"
fi
echo

echo "=== ROUTES ==="
ip route 2>/dev/null || netstat -rn
echo

echo "=== GPU / ACCELERATORS (QNAP / NVIDIA) ==="

echo "--- LOADED NVIDIA KERNEL MODULES ---"
lsmod | grep -Ei '^nvidia|nvidia_' || echo "No NVIDIA modules loaded"
echo

echo "--- NVIDIA GPU INFORMATION (KERNEL-EXPOSED) ---"
if [ -d /proc/driver/nvidia/gpus ]; then
  for g in /proc/driver/nvidia/gpus/*; do
    echo "GPU: $g"
    cat "$g/information"
    echo
  done
else
  echo "No /proc/driver/nvidia/gpus directory found"
fi

echo "--- NVIDIA DEVICE NODES ---"
ls -l /dev | grep -Ei 'nvidia|dri' || echo "No NVIDIA device nodes found"
echo

echo "--- PCI VISIBILITY (BEST-EFFORT) ---"
lspci 2>/dev/null | grep -Ei 'vga|3d|display|nvidia' || echo "GPU not exposed via lspci (expected on QTS)"
