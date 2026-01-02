#!/bin/sh

# Full path to docker binary on QNAP
DOCKER="/share/CACHEDEV1_DATA/.qpkg/container-station/bin/docker"

echo "=== DATE ==="
date
echo

echo "=== DOCKER ENGINE ==="
$DOCKER version
echo

echo "=== DOCKER INFO (RUNTIME SUMMARY) ==="
$DOCKER info
echo

echo "=== CONTAINERS (RUNNING) ==="
$DOCKER ps
echo

echo "=== CONTAINERS (ALL) ==="
$DOCKER ps -a
echo

echo "=== IMAGES ==="
$DOCKER images
echo

echo "=== NETWORKS ==="
$DOCKER network ls
echo

echo "=== VOLUMES ==="
$DOCKER volume ls
echo

echo "=== GPU CAPABILITY (DOCKER VIEW) ==="
$DOCKER info | grep -A 5 "Runtimes:" 2>/dev/null || echo "Runtime info not available"
echo

echo "=== DOCKER CONTEXT ==="
$DOCKER context ls 2>/dev/null || echo "Docker contexts not supported"
echo

echo "=== DOCKGE STACKS INVENTORY ==="
if [ -d "/share/Container/stacks" ]; then
    echo "Found stacks directory: /share/Container/stacks"
    echo
    for stackdir in /share/Container/stacks/*; do
        if [ -d "$stackdir" ]; then
            stackname=$(basename "$stackdir")
            echo "Stack: $stackname"
            
            # Look for compose file
            if [ -f "$stackdir/compose.yaml" ]; then
                echo "  Compose: compose.yaml ($(stat -c %s "$stackdir/compose.yaml" 2>/dev/null || stat -f %z "$stackdir/compose.yaml" 2>/dev/null || echo "?") bytes)"
            elif [ -f "$stackdir/docker-compose.yml" ]; then
                echo "  Compose: docker-compose.yml ($(stat -c %s "$stackdir/docker-compose.yml" 2>/dev/null || stat -f %z "$stackdir/docker-compose.yml" 2>/dev/null || echo "?") bytes)"
            elif [ -f "$stackdir/docker-compose.yaml" ]; then
                echo "  Compose: docker-compose.yaml ($(stat -c %s "$stackdir/docker-compose.yaml" 2>/dev/null || stat -f %z "$stackdir/docker-compose.yaml" 2>/dev/null || echo "?") bytes)"
            else
                echo "  Compose: NOT FOUND"
            fi
            
            # Look for .env file
            if [ -f "$stackdir/.env" ]; then
                echo "  Env file: .env ($(stat -c %s "$stackdir/.env" 2>/dev/null || stat -f %z "$stackdir/.env" 2>/dev/null || echo "?") bytes)"
            fi
            
            # Check if stack appears to be running
            if $DOCKER ps --format '{{.Label "com.docker.compose.project"}}' 2>/dev/null | grep -q "^${stackname}$"; then
                echo "  Status: RUNNING"
            else
                echo "  Status: stopped or not deployed"
            fi
            echo
        fi
    done
else
    echo "Dockge stacks directory not found at /share/Container/stacks"
fi
echo

echo "=== DOCKER BRIDGE NETWORKS ==="
# Show custom Docker bridge networks with IP ranges
$DOCKER network ls --filter driver=bridge --format "{{.Name}}" 2>/dev/null | while read netname; do
    if [ "$netname" != "bridge" ]; then
        echo "Network: $netname"
        $DOCKER network inspect "$netname" --format '  Subnet: {{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>/dev/null
        $DOCKER network inspect "$netname" --format '  Gateway: {{range .IPAM.Config}}{{.Gateway}}{{end}}' 2>/dev/null
        echo
    fi
done
echo

echo "=== CONTAINER RESOURCE USAGE (SNAPSHOT) ==="
# Check if docker stats is available before using it
if $DOCKER stats --no-stream --help >/dev/null 2>&1; then
    $DOCKER stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" 2>/dev/null || echo "Docker stats not available or containers not running"
else
    echo "Docker stats command not available on this system"
fi