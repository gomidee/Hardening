#!/bin/bash
# n8n Docker Setup for Hardened VPS
# Run this AFTER palmtree.sh has completed and you've rebooted
#
# What this does:
#   1. Installs Docker CE on Debian 12
#   2. Adds your user to the docker group
#   3. Creates a docker-compose.yml for n8n
#   4. Starts n8n bound to the Tailscale interface only
#   5. Enables auto-start on boot
#
# n8n will be accessible at: http://<tailscale-ip>:5678
# NOT accessible from the public internet

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# ─── Pre-flight ───────────────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    log_error "Run as root."
    exit 1
fi

# Get Tailscale IP
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
if [[ -z "$TAILSCALE_IP" ]]; then
    log_error "Tailscale is not running or has no IPv4 address."
    log_error "Run palmtree.sh first and make sure Tailscale is connected."
    exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🐳 n8n Docker Setup${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Tailscale IP: ${TAILSCALE_IP}"
echo "  n8n will be at: http://${TAILSCALE_IP}:5678"
echo ""

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: Install Docker
# ═══════════════════════════════════════════════════════════════════════════════
log_info "STEP 1/4 — Installing Docker..."

if command -v docker &>/dev/null; then
    log_warn "Docker already installed, skipping."
else
    # Install prerequisites
    apt-get update -y
    apt-get install -y ca-certificates curl gnupg

    # Add Docker GPG key
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
    chmod a+r /etc/apt/keyrings/docker.asc

    # Add Docker repo
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
      tee /etc/apt/sources.list.d/docker.list > /dev/null

    apt-get update -y
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    # Enable and start Docker
    systemctl enable docker
    systemctl start docker

    log_ok "Docker installed."
fi

# Add victor to docker group
if id "victor" &>/dev/null; then
    usermod -aG docker victor
    log_ok "User 'victor' added to docker group."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Create n8n directory and docker-compose.yml
# ═══════════════════════════════════════════════════════════════════════════════
log_info "STEP 2/4 — Creating n8n configuration..."

N8N_DIR="/home/victor/n8n"
mkdir -p "${N8N_DIR}"

cat > "${N8N_DIR}/docker-compose.yml" << EOF
services:
  n8n:
    image: n8nio/n8n
    container_name: n8n
    restart: unless-stopped
    ports:
      # Bind to Tailscale IP only — not accessible from public internet
      - "${TAILSCALE_IP}:5678:5678"
    environment:
      - GENERIC_TIMEZONE=Australia/Brisbane
      - TZ=Australia/Brisbane
      - N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true
      - NODES_EXCLUDE=[]
    volumes:
      - n8n_data:/home/node/.n8n

volumes:
  n8n_data:
EOF

chown -R victor:victor "${N8N_DIR}"

log_ok "docker-compose.yml created at ${N8N_DIR}/"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Start n8n
# ═══════════════════════════════════════════════════════════════════════════════
log_info "STEP 3/4 — Starting n8n..."

cd "${N8N_DIR}"
docker compose pull
docker compose up -d

log_ok "n8n is running."

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Verify
# ═══════════════════════════════════════════════════════════════════════════════
log_info "STEP 4/4 — Verifying..."

# Wait for n8n to start
sleep 5

if docker compose ps | grep -q "running"; then
    log_ok "n8n container is healthy."
else
    log_warn "Container may still be starting. Check with: docker compose ps"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🐳 n8n is ready!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Access n8n:       http://${TAILSCALE_IP}:5678"
echo "  Config location:  ${N8N_DIR}/docker-compose.yml"
echo "  Logs:             cd ${N8N_DIR} && docker compose logs -f"
echo "  Restart:          cd ${N8N_DIR} && docker compose restart"
echo "  Stop:             cd ${N8N_DIR} && docker compose down"
echo ""
echo "  n8n is bound to your Tailscale IP only."
echo "  It will auto-restart on reboot."
echo ""
echo -e "  ${YELLOW}⚠  The Execute Command node is enabled (NODES_EXCLUDE=[])${NC}"
echo -e "  ${YELLOW}⚠  First visit will prompt you to create an n8n account${NC}"
echo ""
