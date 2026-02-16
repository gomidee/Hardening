#!/bin/bash
# Palmtree v2 — Debian VPS Hardening Script
# By Gomidee (rewritten)
#
# What this script does:
#   1. Creates user 'victor' with password login
#   2. Installs and configures UFW (deny all incoming, allow Tailscale only)
#   3. Disables IPv6 entirely
#   4. Blocks ICMP ping (server won't respond to pings)
#   5. Installs and configures Tailscale as an exit node
#   6. Locks down SSH to Tailscale interface only (backup for Tailscale SSH)
#   7. Enables Tailscale SSH as primary access method
#   8. Sets up unattended-upgrades for automatic security patches
#   9. Disables bash history
#  10. Disables root login
#
# Requirements:
#   - Fresh Debian 12 VPS
#   - Run as root
#   - Internet connectivity (for package installs + Tailscale)

set -euo pipefail

# ─── Colors ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ─── Configuration ────────────────────────────────────────────────────────────
USERNAME="victor"
SSH_PORT=22

# ─── Helper Functions ─────────────────────────────────────────────────────────
log_info()  { echo -e "${CYAN}[INFO]${NC}  $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC}    $1"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

confirm() {
    local prompt="$1"
    local response
    echo -en "${YELLOW}${prompt} [Y/n]:${NC} "
    read -r response
    [[ "$response" =~ ^[Yy]$ || -z "$response" ]]
}

# ─── Pre-flight Checks ───────────────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    log_error "This script must be run as root."
    exit 1
fi

if ! grep -qi 'debian' /etc/os-release 2>/dev/null; then
    log_warn "This script is designed for Debian. Detected a different OS."
    if ! confirm "Continue anyway?"; then
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🌴 Palmtree v2 — Debian VPS Hardening${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  This script will:"
echo "    • Create user '${USERNAME}' with password auth"
echo "    • Block ALL external access (firewall + no pings)"
echo "    • Install Tailscale (exit node) as the only way in"
echo "    • Bind SSH to Tailscale interface as fallback"
echo "    • Enable automatic security updates"
echo "    • Disable IPv6, bash history, and root login"
echo ""

if ! confirm "Ready to proceed?"; then
    echo "Aborted."
    exit 0
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: System Update & Package Installation
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 1/8 — Updating system and installing packages..."

apt-get update -y
apt-get upgrade -y
apt-get install -y ufw unattended-upgrades apt-listchanges curl

log_ok "System updated and packages installed."

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: Create User
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 2/8 — Setting up user '${USERNAME}'..."

if id "${USERNAME}" &>/dev/null; then
    log_warn "User '${USERNAME}' already exists, skipping creation."
else
    adduser --gecos "" "${USERNAME}"
    usermod -aG sudo "${USERNAME}"
    log_ok "User '${USERNAME}' created and added to sudo group."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: Disable IPv6
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 3/8 — Disabling IPv6..."

cat > /etc/sysctl.d/99-disable-ipv6.conf << 'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF

sysctl --system > /dev/null 2>&1

log_ok "IPv6 disabled."

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: Configure UFW Firewall
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 4/8 — Configuring UFW firewall..."

# Reset UFW to clean state (non-interactive)
ufw --force reset > /dev/null 2>&1

# Default policies: deny everything incoming, allow outgoing
ufw default deny incoming
ufw default allow outgoing

# Allow Tailscale WireGuard port (required for Tailscale to connect)
ufw allow 41641/udp comment "Tailscale WireGuard"

# Allow all traffic on the Tailscale interface (this is your internal network)
ufw allow in on tailscale0 comment "Tailscale interface"

# Disable IPv6 in UFW
sed -i 's/^IPV6=yes/IPV6=no/' /etc/default/ufw

# ─── Harden before.rules (block ICMP ping) ───────────────────────────────────
cp /etc/ufw/before.rules /etc/ufw/before.rules.backup.$(date +%s)

cat > /etc/ufw/before.rules << 'RULES'
#
# Palmtree hardened before.rules
# Blocks ICMP echo (ping) requests, allows essential traffic only
#
*filter
:ufw-before-input - [0:0]
:ufw-before-output - [0:0]
:ufw-before-forward - [0:0]
:ufw-not-local - [0:0]

# Loopback — allow all
-A ufw-before-input -i lo -j ACCEPT
-A ufw-before-output -o lo -j ACCEPT

# Established/related connections — allow
-A ufw-before-input -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-output -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
-A ufw-before-forward -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Invalid packets — drop
-A ufw-before-input -m conntrack --ctstate INVALID -j ufw-logging-deny
-A ufw-before-input -m conntrack --ctstate INVALID -j DROP

# ICMP — drop echo-request (ping), allow the rest
-A ufw-before-input -p icmp --icmp-type echo-request -j DROP
-A ufw-before-input -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-input -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-input -p icmp --icmp-type parameter-problem -j ACCEPT

# ICMP forwarding (for exit node)
-A ufw-before-forward -p icmp --icmp-type destination-unreachable -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type time-exceeded -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type parameter-problem -j ACCEPT
-A ufw-before-forward -p icmp --icmp-type echo-request -j ACCEPT

# DHCP client
-A ufw-before-input -p udp --sport 67 --dport 68 -j ACCEPT

# Non-local traffic handling
-A ufw-before-input -j ufw-not-local
-A ufw-not-local -m addrtype --dst-type LOCAL -j RETURN
-A ufw-not-local -m addrtype --dst-type MULTICAST -j RETURN
-A ufw-not-local -m addrtype --dst-type BROADCAST -j RETURN
-A ufw-not-local -m limit --limit 3/min --limit-burst 10 -j ufw-logging-deny
-A ufw-not-local -j DROP

# mDNS + UPnP (optional, safe to keep)
-A ufw-before-input -p udp -d 224.0.0.251 --dport 5353 -j ACCEPT
-A ufw-before-input -p udp -d 239.255.255.250 --dport 1900 -j ACCEPT

COMMIT
RULES

# Enable UFW
ufw --force enable

log_ok "UFW configured — all external ports blocked except Tailscale (41641/udp)."

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 5: Block ICMP via sysctl (belt and suspenders)
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 5/8 — Blocking ICMP ping at kernel level..."

cat > /etc/sysctl.d/99-no-icmp.conf << 'EOF'
net.ipv4.icmp_echo_ignore_all = 1
EOF

sysctl --system > /dev/null 2>&1

log_ok "ICMP ping blocked (kernel + firewall)."

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 6: Install and Configure Tailscale
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 6/8 — Installing Tailscale..."

if command -v tailscale &>/dev/null; then
    log_warn "Tailscale already installed, skipping install."
else
    curl -fsSL https://tailscale.com/install.sh | sh
    log_ok "Tailscale installed."
fi

# Enable IP forwarding for exit node
cat > /etc/sysctl.d/99-tailscale-forwarding.conf << 'EOF'
net.ipv4.ip_forward = 1
EOF

sysctl --system > /dev/null 2>&1

log_info "Bringing up Tailscale as exit node with SSH enabled..."
echo ""
echo -e "${YELLOW}  ┌─────────────────────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}  │  A browser link will appear — open it to authenticate  │${NC}"
echo -e "${YELLOW}  │  your Tailscale account.                               │${NC}"
echo -e "${YELLOW}  └─────────────────────────────────────────────────────────┘${NC}"
echo ""

tailscale up --advertise-exit-node --ssh

log_ok "Tailscale is up (exit node + Tailscale SSH enabled)."
echo ""
log_warn "REMINDER: Go to the Tailscale admin console and approve the exit node."
log_warn "          https://login.tailscale.com/admin/machines"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 7: Lock Down SSH
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 7/8 — Locking down SSH to Tailscale interface only..."

# Wait for tailscale0 to get an IP
TAILSCALE_IP=""
for i in {1..10}; do
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)
    if [[ -n "$TAILSCALE_IP" ]]; then
        break
    fi
    sleep 2
done

if [[ -z "$TAILSCALE_IP" ]]; then
    log_error "Could not detect Tailscale IP. SSH config unchanged."
    log_warn "You'll need to manually set ListenAddress in /etc/ssh/sshd_config"
else
    # Backup sshd_config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%s)

    cat > /etc/ssh/sshd_config.d/99-palmtree.conf << SSHEOF
# Palmtree hardening — SSH only via Tailscale
# Generated on $(date)

# Listen ONLY on Tailscale interface
ListenAddress ${TAILSCALE_IP}

Port ${SSH_PORT}

# Disable root login
PermitRootLogin no

# Allow password auth (over Tailscale only, so this is safe)
PasswordAuthentication yes

# Hardening
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowAgentForwarding no

# Only allow our user
AllowUsers ${USERNAME}
SSHEOF

    systemctl restart sshd
    log_ok "SSH locked to Tailscale IP (${TAILSCALE_IP}) — only user '${USERNAME}' can log in."
fi

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 8: Automatic Security Updates + Cleanup
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
log_info "STEP 8/8 — Configuring automatic security updates..."

# Enable unattended-upgrades
cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

systemctl enable unattended-upgrades
systemctl start unattended-upgrades

log_ok "Automatic security updates enabled."

# ─── Disable bash history for all users ───────────────────────────────────────
log_info "Disabling bash history..."

for homedir in /root "/home/${USERNAME}"; do
    if [[ -d "$homedir" ]]; then
        # Remove existing history settings and add disable
        sed -i '/^HISTSIZE=/d; /^HISTFILESIZE=/d' "${homedir}/.bashrc" 2>/dev/null || true
        echo 'HISTSIZE=0' >> "${homedir}/.bashrc"
        echo 'HISTFILESIZE=0' >> "${homedir}/.bashrc"
        # Clear any existing history file
        rm -f "${homedir}/.bash_history" 2>/dev/null || true
    fi
done

log_ok "Bash history disabled for root and ${USERNAME}."

# ─── Disable root password login ─────────────────────────────────────────────
passwd -l root

log_ok "Root password login disabled."

# ═══════════════════════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════════════════════
TAILSCALE_IP_FINAL=$(tailscale ip -4 2>/dev/null || echo "unknown")

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  🌴 Palmtree hardening complete!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "  Summary:"
echo "  ────────────────────────────────────────────────────"
echo "    User:              ${USERNAME}"
echo "    Tailscale IP:      ${TAILSCALE_IP_FINAL}"
echo "    SSH (fallback):    ssh ${USERNAME}@${TAILSCALE_IP_FINAL}"
echo "    Tailscale SSH:     ssh ${USERNAME}@<machine-name>"
echo "    External access:   BLOCKED"
echo "    Ping response:     BLOCKED"
echo "    IPv6:              DISABLED"
echo "    Auto-updates:      ENABLED"
echo "    Exit node:         ENABLED (approve in admin console)"
echo "  ────────────────────────────────────────────────────"
echo ""
echo -e "  ${YELLOW}⚠  Don't forget to approve the exit node in Tailscale admin:${NC}"
echo -e "  ${YELLOW}   https://login.tailscale.com/admin/machines${NC}"
echo ""
echo -e "  ${YELLOW}⚠  Test your Tailscale SSH access BEFORE closing this session!${NC}"
echo ""

if confirm "Would you like to reboot now? (recommended)"; then
    log_info "Rebooting..."
    reboot
else
    log_ok "Done. Reboot when you're ready."
fi
