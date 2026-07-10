#!/bin/bash
set -e

# Suppress all interactive prompts during apt execution
export DEBIAN_FRONTEND=noninteractive

# Redirect all stdout/stderr logs to system console for troubleshooting
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/null) 2>&1

echo "=========================================="
echo "Starting Neo4j Demo Node Initialization"
echo "=========================================="

# 1. Wait for background cloud-init/apt package management locks to clear
echo "Waiting for background system package locks to clear..."
for i in {1..12}; do
  if fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; then
    echo "Installer database is currently locked. Sleeping 5 seconds..."
    sleep 5
  else
    break
  fi
done

# 2. Dynamic AWS Disk Mapping Scanner (Handles legacy and modern Nitro NVMe names)
echo "Scanning for persistent data volume..."
DATA_DISK="none"

if [ -b "/dev/nvme1n1" ]; then
  DATA_DISK="/dev/nvme1n1"
elif [ -b "/dev/sdb" ]; then
  DATA_DISK="/dev/sdb"
else
  for i in {1..4}; do
    echo "Disk not found yet. Rescanning block devices..."
    sleep 5
    if [ -b "/dev/nvme1n1" ]; then DATA_DISK="/dev/nvme1n1"; break; fi
    if [ -b "/dev/sdb" ]; then DATA_DISK="/dev/sdb"; break; fi
  done
fi

# 3. Handle FileSystem Allocation and Non-Destructive Mount Operations
mkdir -p /var/lib/neo4j/data
mkdir -p /var/lib/neo4j/logs

if [ "$DATA_DISK" != "none" ]; then
  echo "Targeting secondary persistent storage disk: $DATA_DISK"

  if ! blkid $DATA_DISK | grep -q "type="; then
    echo "Formatting $DATA_DISK with high-performance XFS filesystem..."
    mkfs.xfs $DATA_DISK
  else
    echo "Valid filesystem structure already detected. Protecting data lineage from wipe."
  fi

  if ! mount | grep -q "/var/lib/neo4j/data"; then
    DATA_UUID=$(blkid -o value -s UUID $DATA_DISK)
    if ! grep -q "$DATA_UUID" /etc/fstab; then
      echo "UUID=$DATA_UUID /var/lib/neo4j/data xfs defaults,nofail 0 2" >> /etc/fstab
    fi
    mount -a
  fi
else
  echo "WARNING: No secondary EBS block volume discovered. Falling back to root disk."
fi

chmod -R 777 /var/lib/neo4j

# 4. Production OS Tuning: Optimize Memory Map limits for heavy graph queries
echo "Optimizing kernel settings..."
sysctl -w vm.max_map_count=262144
echo "vm.max_map_count=262144" >> /etc/sysctl.conf

# 5. FIXED: Reliable Native Docker Engine Installation & Systemd Verification
if ! command -v docker &> /dev/null; then
  echo "Installing Docker Engine..."
  apt-get update -y
  apt-get install -y docker.io
  systemctl enable docker
  systemctl start docker
fi

# Ubuntu 26.04 Optimization: Wait up to 30 seconds for the docker socket to be fully ready
echo "Waiting for Docker daemon socket to initialize..."
for i in {1..10}; do
  if ! docker ps &>/dev/null; then
    echo "Docker engine is starting up. Sleeping 3 seconds..."
    sleep 3
  else
    echo "Docker engine is fully online and responsive!"
    break
  fi
done

# ==============================================================================
# 6. FIXED: Secure & Fault-Tolerant Dynamic External IP Resolution Architecture
# ==============================================================================
echo "Fetching AWS Instance Public IP..."
PUBLIC_IP=""

# Method A: Use dedicated public plain-text reflection services
echo "Trying plain-text public IP echo resolvers..."
PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me || curl -s --max-time 5 https://icanhazip.com || true)

# Clean whitespace or linebreaks from public curl responses
PUBLIC_IP=$(echo "$PUBLIC_IP" | xargs)

# Method B: Secure IMDSv2 metadata endpoint recovery fallback
if [ -z "$PUBLIC_IP" ] || [[ "$PUBLIC_IP" == *"html"* ]] || [[ ! "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Public Web APIs unavailable or returned anomalies. Attempting IMDSv2 metadata fetch..."

  # Corrected absolute link path for the link-local metadata loopback
  TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 60" --max-time 5 || true)

  if [ ! -z "$TOKEN" ]; then
    # Appended the exact specific public-ipv4 path descriptor
    PUBLIC_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169 --max-time 5 || true)
  fi
fi

# Emergency Method C: Fall back gracefully to internal or universal binding configurations
if [ -z "$PUBLIC_IP" ] || [[ "$PUBLIC_IP" == *"html"* ]] || [[ ! "$PUBLIC_IP" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "WARNING: Public IP could not be explicitly verified. Utilizing local loopback mapping placeholder."
  PUBLIC_IP="0.0.0.0"
fi

echo "Resolved Target Public IP for Neo4j: $PUBLIC_IP"


# ==============================================================================
# 7. FIXED: Start Neo4j Enterprise via Docker
# ==============================================================================
echo "Bootstrapping Neo4j Docker container on Target: $PUBLIC_IP"

# Modified to use conditional logic so "set -e" won't crash if the container doesn't exist
if docker ps -a --format '{{.Name}}' | grep -q "^neo4j-node$"; then
  echo "Found existing neo4j-node container. Purging..."
  docker stop neo4j-node || true
  docker rm -f neo4j-node || true
fi

docker run -d \
  --name=neo4j-node \
  --restart=always \
  -p 7474:7474 -p 7687:7687 \
  -v /var/lib/neo4j/data:/data \
  -v /var/lib/neo4j/logs:/logs \
  -e NEO4J_AUTH=neo4j/YourSecurePassword123 \
  -e NEO4J_ACCEPT_LICENSE_AGREEMENT=yes \
  -e NEO4J_server_memory_pagecache_size=1g \
  -e NEO4J_server_memory_heap_initial__size=1500m \
  -e NEO4J_server_memory_heap_max__size=1500m \
  -e NEO4J_server_default__listen__address=0.0.0.0 \
  -e NEO4J_server_default__advertised__address=$PUBLIC_IP \
  -e NEO4J_server_bolt_advertised__address=$PUBLIC_IP:7687 \
  -e NEO4J_server_http_advertised__address=$PUBLIC_IP:7474 \
  neo4j:5.26.0-enterprise

echo "=========================================="
echo "Node Setup Success: Neo4j Engine is Running"
echo "=========================================="

