#!/usr/bin/env bash
set -e

NODES=(
  clab-bgp-lu-vpn-rr-pe1
  clab-bgp-lu-vpn-rr-rr1
  clab-bgp-lu-vpn-rr-rr2
  clab-bgp-lu-vpn-rr-pe2
)

echo "== Loading MPLS modules on host =="
sudo modprobe mpls_router
sudo modprobe mpls_iptunnel
sudo modprobe mpls_gso

echo
echo "== Enabling MPLS in containers =="

for c in "${NODES[@]}"; do
    echo "--- $c ---"

    docker exec "$c" sysctl -w net.mpls.platform_labels=100000
    docker exec "$c" sysctl -w net.mpls.ip_ttl_propagate=0

    # Enable MPLS input on every non-loopback interface.
    for iface in $(docker exec "$c" sh -c \
        "ip -o link show | awk -F': ' '\$2 !~ /^lo(@|$)/ {print \$2}' | cut -d@ -f1"); do

        # Only configure interfaces that have an MPLS sysctl entry.
        if docker exec "$c" test -e "/proc/sys/net/mpls/conf/$iface/input"; then
            docker exec "$c" sysctl -w "net.mpls.conf.$iface.input=1"
        fi
    done

    echo
done

echo "== MPLS status =="
for c in "${NODES[@]}"; do
    echo "--- $c ---"
    docker exec "$c" sysctl net.mpls.platform_labels
    docker exec "$c" sh -c \
        'for f in /proc/sys/net/mpls/conf/*/input; do echo "$f=$(cat "$f")"; done'
done

echo
echo "Done."
