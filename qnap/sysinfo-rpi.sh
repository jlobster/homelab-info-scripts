#!/bin/bash
# Pi-hole System Information Collection Script
# Created: 2025-12-26
# Purpose: Document Pi-hole configuration and system state

echo "=== DATE ==="
date
echo ""

echo "=== PI-HOLE VERSION ==="
pihole version 2>/dev/null || echo "Pi-hole CLI not available"
echo ""

echo "=== PI-HOLE STATUS ==="
pihole status 2>/dev/null || echo "Status check not available"
echo ""

echo "=== OS / HARDWARE ==="
uname -a
echo ""
if [ -f /etc/os-release ]; then
    cat /etc/os-release
    echo ""
fi
if [ -f /proc/device-tree/model ]; then
    echo "Hardware:"
    cat /proc/device-tree/model 2>/dev/null
    echo ""
    echo ""
fi
echo ""

echo "=== NETWORK INTERFACES ==="
ip addr show 2>/dev/null || ifconfig -a
echo ""

echo "=== ROUTES ==="
ip route show 2>/dev/null || route -n
echo ""

echo "=== DNS CONFIG ==="
cat /etc/resolv.conf 2>/dev/null
echo ""

echo "=== PI-HOLE CONFIG SUMMARY ==="
if [ -f /etc/pihole/pihole.toml ]; then
    echo "--- Upstream DNS Servers ---"
    grep -A5 "upstreams = \[" /etc/pihole/pihole.toml 2>/dev/null
    echo ""
    
    echo "--- Local Domain ---"
    grep "name = " /etc/pihole/pihole.toml | grep -v "^#" | head -1
    echo ""
    
    echo "--- Custom DNS Hosts ---"
    grep -A20 "hosts = \[" /etc/pihole/pihole.toml 2>/dev/null
    echo ""
    
    echo "--- Blocking Configuration ---"
    grep "active = " /etc/pihole/pihole.toml | head -1
    grep "mode = " /etc/pihole/pihole.toml | grep -v "listeningMode" | head -1
    echo ""
    
    echo "--- Reverse Server (Conditional Forwarding) ---"
    grep -A2 "revServers = \[" /etc/pihole/pihole.toml 2>/dev/null
    echo ""
    
    echo "--- DHCP Status ---"
    grep "^\[dhcp\]" -A2 /etc/pihole/pihole.toml 2>/dev/null | grep "active"
    echo ""
else
    echo "pihole.toml not found"
fi
echo ""

echo "=== KNOWN CLIENTS ==="
echo "Total unique clients in database:"
sudo sqlite3 /etc/pihole/pihole-FTL.db "SELECT COUNT(DISTINCT ip) FROM client_by_id WHERE ip NOT LIKE '127.%' AND ip NOT LIKE '::1';" 2>/dev/null
echo ""
echo "Clients with hostnames (sample - first 50):"
sudo sqlite3 /etc/pihole/pihole-FTL.db "SELECT ip, name FROM client_by_id WHERE name IS NOT NULL AND name != '' AND ip NOT LIKE '127.%' ORDER BY ip LIMIT 50;" 2>/dev/null
echo ""

echo "=== ACTIVE DEVICES (with MAC addresses) ==="
echo "Recent devices on network (last 7 days):"
sudo sqlite3 /etc/pihole/pihole-FTL.db "SELECT n.hwaddr, na.ip, na.name, n.macVendor FROM network n LEFT JOIN network_addresses na ON n.id = na.network_id WHERE na.lastSeen > strftime('%s','now','-7 days') ORDER BY na.ip LIMIT 100;" 2>/dev/null
echo ""

echo "=== TOP 20 QUERYING CLIENTS (LAST 24H) ==="
sudo sqlite3 /etc/pihole/pihole-FTL.db <<EOF
.mode line
SELECT q.client AS 'IP Address', 
       COALESCE(c.name, '(no hostname)') AS 'Hostname', 
       COUNT(*) AS 'Queries'
FROM queries q 
LEFT JOIN client_by_id c ON q.client = c.ip 
WHERE q.timestamp > strftime('%s','now','-24 hours') 
GROUP BY q.client 
ORDER BY Queries DESC 
LIMIT 20;
EOF
echo ""

echo "=== FTL SERVICE STATUS ==="
systemctl status pihole-FTL --no-pager 2>/dev/null | head -20 || echo "systemctl not available"
echo ""

echo "=== LISTENING PORTS ==="
netstat -tulpn 2>/dev/null | grep -E "LISTEN|:53|:80|:443" || ss -tulpn | grep -E "LISTEN|:53|:80|:443"
echo ""

echo "=== DISK USAGE ==="
df -h / /boot 2>/dev/null
echo ""

echo "=== MEMORY ==="
free -h 2>/dev/null || cat /proc/meminfo | head -10
echo ""
