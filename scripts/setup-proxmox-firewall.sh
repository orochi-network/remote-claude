#!/bin/bash
# setup-proxmox-firewall.sh
#
# Run on the Proxmox HOST (not inside the VM).
# Sets up port forwarding to the agent47 VM and restricts access to allowed IPs only.
#
# Usage:
#   bash scripts/setup-proxmox-firewall.sh
#
# To remove all rules added by this script:
#   bash scripts/setup-proxmox-firewall.sh --flush

set -euo pipefail

# ─── Config ───────────────────────────────────────────────────────────────────
VM_IP="10.11.0.2"

ALLOWED_IPS=(
    "152.42.226.163"
    "115.79.199.138"
)

# Ports to forward and restrict (from docker-compose-dev.yaml)
# Format: "host_port:vm_port" or "start:end" for ranges
declare -A PORT_RANGES=(
    ["ssh"]="2201:2209"
    ["verdaccio"]="4873"
    ["mcp_playwright"]="8931"
)

# Auto-detect the external interface (the one with the default route)
EXTERNAL_IF=$(ip route | awk '/^default/ {print $5; exit}')
# ──────────────────────────────────────────────────────────────────────────────

if [[ "${1:-}" == "--flush" ]]; then
    echo "Flushing nat PREROUTING and FORWARD rules for VM $VM_IP..."
    iptables -t nat -F PREROUTING
    iptables -t nat -F POSTROUTING
    # Remove FORWARD rules targeting VM (flush all — re-run script to restore)
    iptables -F FORWARD
    echo "Done. Run without --flush to re-apply rules."
    exit 0
fi

echo "External interface: $EXTERNAL_IF"
echo "VM IP: $VM_IP"
echo "Allowed IPs: ${ALLOWED_IPS[*]}"
echo ""

# ─── Enable IP forwarding ─────────────────────────────────────────────────────
echo "Enabling IP forwarding..."
echo 1 > /proc/sys/net/ipv4/ip_forward
# Persist across reboots
grep -q "^net.ipv4.ip_forward" /etc/sysctl.conf \
    && sed -i 's/^net.ipv4.ip_forward.*/net.ipv4.ip_forward=1/' /etc/sysctl.conf \
    || echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf

# ─── Helper: apply rules for a single port or range ──────────────────────────
apply_port_rules() {
    local port_spec="$1"  # e.g. "2201:2209" or "4873"

    # DNAT: forward all traffic on this port/range to VM
    iptables -t nat -A PREROUTING \
        -p tcp --dport "$port_spec" \
        -j DNAT --to-destination "$VM_IP"

    # FORWARD: allow only whitelisted IPs
    for ip in "${ALLOWED_IPS[@]}"; do
        iptables -A FORWARD \
            -s "$ip" -d "$VM_IP" \
            -p tcp --dport "$port_spec" \
            -j ACCEPT
    done

    # FORWARD: drop everything else destined for VM on this port
    iptables -A FORWARD \
        -d "$VM_IP" -p tcp --dport "$port_spec" \
        -j DROP
}

# ─── Apply rules for all port groups ─────────────────────────────────────────
for label in "${!PORT_RANGES[@]}"; do
    port_spec="${PORT_RANGES[$label]}"
    echo "Configuring $label ($port_spec)..."
    apply_port_rules "$port_spec"
done

# ─── Allow established/related connections back through ──────────────────────
iptables -A FORWARD \
    -d "$VM_IP" \
    -m state --state ESTABLISHED,RELATED \
    -j ACCEPT

# ─── MASQUERADE return traffic from VM to internet ───────────────────────────
iptables -t nat -A POSTROUTING \
    -s "$VM_IP" -o "$EXTERNAL_IF" \
    -j MASQUERADE

# ─── Persist rules ───────────────────────────────────────────────────────────
echo ""
echo "Saving rules..."
if command -v iptables-save &>/dev/null; then
    if [ -d /etc/iptables ]; then
        iptables-save > /etc/iptables/rules.v4
        echo "Saved to /etc/iptables/rules.v4"
    else
        mkdir -p /etc/iptables
        iptables-save > /etc/iptables/rules.v4
        # Ensure rules load on boot via /etc/network/interfaces post-up
        if ! grep -q "iptables-restore" /etc/network/interfaces 2>/dev/null; then
            echo "" >> /etc/network/interfaces
            echo "# Restore iptables rules on boot" >> /etc/network/interfaces
            echo "post-up iptables-restore < /etc/iptables/rules.v4" >> /etc/network/interfaces
            echo "Added post-up restore hook to /etc/network/interfaces"
        fi
    fi
fi

echo ""
echo "Done. Port forwarding and IP restriction active."
echo ""
echo "Allowed access:"
for ip in "${ALLOWED_IPS[@]}"; do
    echo "  - $ip"
done
echo ""
echo "Forwarded ports → $VM_IP:"
for label in "${!PORT_RANGES[@]}"; do
    echo "  - $label: ${PORT_RANGES[$label]}"
done
echo ""
echo "To remove all rules: bash scripts/setup-proxmox-firewall.sh --flush"
