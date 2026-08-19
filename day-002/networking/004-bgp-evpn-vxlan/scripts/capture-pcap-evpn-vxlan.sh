#!/usr/bin/env bash
set -euo pipefail

TOPO="bgp-evpn-vxlan-lab"
PREFIX="clab-${TOPO}"
OUT="captures/$(date +%Y%m%d-%H%M%S)"

LEAF1="${PREFIX}-leaf1"
SPINE="${PREFIX}-spine"
LEAF2="${PREFIX}-leaf2"

mkdir -p "$OUT"

echo "============================================================"
echo " EVPN / VXLAN CAPTURE"
echo " Output: $OUT"
echo "============================================================"

cleanup() {
    echo
    echo "[*] Stopping tcpdump processes..."
    for c in "$LEAF1" "$SPINE" "$LEAF2"; do
        docker exec "$c" pkill tcpdump 2>/dev/null || true
    done
}

trap cleanup EXIT

###############################################################################
# PHASE 1: EVPN CONTROL PLANE
###############################################################################

echo
echo "============================================================"
echo " PHASE 1: EVPN CONVERGENCE"
echo "============================================================"

echo "[*] Starting BGP captures..."

# leaf1 -> spine
docker exec "$LEAF1" \
    tcpdump -i eth1 -nn -s 0 -w /tmp/evpn-leaf1-spine.pcap \
    'tcp port 179' >/dev/null 2>&1 &

# spine eth1 -> leaf1
docker exec "$SPINE" \
    tcpdump -i eth1 -nn -s 0 -w /tmp/evpn-spine-leaf1.pcap \
    'tcp port 179' >/dev/null 2>&1 &

# spine eth2 -> leaf2
docker exec "$SPINE" \
    tcpdump -i eth2 -nn -s 0 -w /tmp/evpn-spine-leaf2.pcap \
    'tcp port 179' >/dev/null 2>&1 &

# leaf2 -> spine
docker exec "$LEAF2" \
    tcpdump -i eth1 -nn -s 0 -w /tmp/evpn-leaf2-spine.pcap \
    'tcp port 179' >/dev/null 2>&1 &

sleep 2

echo "[*] Clearing EVPN sessions to force convergence..."

docker exec "$LEAF1" \
    vtysh -c 'clear bgp l2vpn evpn *' || true

docker exec "$LEAF2" \
    vtysh -c 'clear bgp l2vpn evpn *' || true

sleep 8

echo "[*] Copying EVPN pcaps..."

docker cp "$LEAF1:/tmp/evpn-leaf1-spine.pcap" \
    "$OUT/evpn-leaf1-spine.pcap"

docker cp "$SPINE:/tmp/evpn-spine-leaf1.pcap" \
    "$OUT/evpn-spine-leaf1.pcap"

docker cp "$SPINE:/tmp/evpn-spine-leaf2.pcap" \
    "$OUT/evpn-spine-leaf2.pcap"

docker cp "$LEAF2:/tmp/evpn-leaf2-spine.pcap" \
    "$OUT/evpn-leaf2-spine.pcap"

echo
echo "[*] EVPN convergence state:"
echo

docker exec "$SPINE" \
    vtysh -c 'show bgp l2vpn evpn route' \
    > "$OUT/spine-evpn-routes.txt"

docker exec "$LEAF1" \
    vtysh -c 'show bgp l2vpn evpn route' \
    > "$OUT/leaf1-evpn-routes.txt"

docker exec "$LEAF2" \
    vtysh -c 'show bgp l2vpn evpn route' \
    > "$OUT/leaf2-evpn-routes.txt"

cat "$OUT/spine-evpn-routes.txt"

###############################################################################
# ASSIMILATE EVPN PCAPS
###############################################################################

echo
echo "============================================================"
echo " EVPN ASSIMILATION"
echo "============================================================"

for pcap in "$OUT"/evpn-*.pcap; do
    base="$(basename "$pcap" .pcap)"

    echo
    echo "------------------------------------------------------------"
    echo "$base"
    echo "------------------------------------------------------------"

    tshark -r "$pcap" \
        -Y 'bgp.update' \
        -T fields \
        -e frame.number \
        -e frame.time_relative \
        -e ip.src \
        -e ip.dst \
        -e tcp.srcport \
        -e tcp.dstport \
        -e bgp.path_attribute \
        2>/dev/null \
        | tee "$OUT/${base}-updates.txt" || true
done

echo
echo "[*] Looking specifically for EVPN NLRI..."

for pcap in "$OUT"/evpn-*.pcap; do
    base="$(basename "$pcap" .pcap)"

    tshark -r "$pcap" \
        -Y 'bgp && (bgp.evpn || bgp.mp_reach_nlri || bgp.mp_unreach_nlri)' \
        -V 2>/dev/null \
        > "$OUT/${base}-evpn-detail.txt" || true
done

echo
echo "[*] EVPN phase complete."

###############################################################################
# PHASE 2: VXLAN DATA PLANE
###############################################################################

echo
echo "============================================================"
echo " PHASE 2: VXLAN DATA PLANE"
echo "============================================================"

echo "[*] Starting VXLAN captures..."

# leaf1 underlay
docker exec "$LEAF1" \
    tcpdump -i eth1 -nn -s 0 -w /tmp/vxlan-leaf1-eth1.pcap \
    'udp port 4789' >/dev/null 2>&1 &

# spine toward leaf1
docker exec "$SPINE" \
    tcpdump -i eth1 -nn -s 0 -w /tmp/vxlan-spine-eth1.pcap \
    'udp port 4789' >/dev/null 2>&1 &

# spine toward leaf2
docker exec "$SPINE" \
    tcpdump -i eth2 -nn -s 0 -w /tmp/vxlan-spine-eth2.pcap \
    'udp port 4789' >/dev/null 2>&1 &

# leaf2 underlay
docker exec "$LEAF2" \
    tcpdump -i eth1 -nn -s 0 -w /tmp/vxlan-leaf2-eth1.pcap \
    'udp port 4789' >/dev/null 2>&1 &

sleep 2

echo "[*] Generating RED traffic..."

docker exec "${PREFIX}-client-red" \
    ping -c 5 10.100.0.12 \
    | tee "$OUT/red-ping.txt"

sleep 3

echo "[*] Copying VXLAN pcaps..."

docker cp "$LEAF1:/tmp/vxlan-leaf1-eth1.pcap" \
    "$OUT/vxlan-leaf1-eth1.pcap"

docker cp "$SPINE:/tmp/vxlan-spine-eth1.pcap" \
    "$OUT/vxlan-spine-eth1.pcap"

docker cp "$SPINE:/tmp/vxlan-spine-eth2.pcap" \
    "$OUT/vxlan-spine-eth2.pcap"

docker cp "$LEAF2:/tmp/vxlan-leaf2-eth1.pcap" \
    "$OUT/vxlan-leaf2-eth1.pcap"

###############################################################################
# ASSIMILATE VXLAN PCAPS
###############################################################################

echo
echo "============================================================"
echo " VXLAN ASSIMILATION"
echo "============================================================"

for pcap in "$OUT"/vxlan-*.pcap; do
    base="$(basename "$pcap" .pcap)"

    echo
    echo "------------------------------------------------------------"
    echo "$base"
    echo "------------------------------------------------------------"

    tshark -r "$pcap" \
        -Y 'vxlan' \
        -T fields \
        -e frame.number \
        -e frame.time_relative \
        -e ip.src \
        -e ip.dst \
        -e udp.srcport \
        -e udp.dstport \
        -e vxlan.vni \
        -e eth.src \
        -e eth.dst \
        2>/dev/null \
        | tee "$OUT/${base}-vxlan.txt" || true
done

###############################################################################
# MERGE CAPTURES
###############################################################################

echo
echo "============================================================"
echo " MERGING CAPTURES"
echo "============================================================"

if command -v mergecap >/dev/null 2>&1; then

    mergecap -w "$OUT/evpn-convergence-all.pcap" \
        "$OUT"/evpn-*.pcap

    mergecap -w "$OUT/vxlan-dataplane-all.pcap" \
        "$OUT"/vxlan-*.pcap

    echo "[+] Created:"
    echo "    $OUT/evpn-convergence-all.pcap"
    echo "    $OUT/vxlan-dataplane-all.pcap"

fi

###############################################################################
# FINAL STATE
###############################################################################

echo
echo "============================================================"
echo " FINAL EVPN STATE"
echo "============================================================"

echo
echo "--- LEAF1 ---"
docker exec "$LEAF1" \
    vtysh -c 'show bgp l2vpn evpn route type 2' || true

docker exec "$LEAF1" \
    vtysh -c 'show bgp l2vpn evpn route type 3' || true

echo
echo "--- LEAF2 ---"
docker exec "$LEAF2" \
    vtysh -c 'show bgp l2vpn evpn route type 2' || true

docker exec "$LEAF2" \
    vtysh -c 'show bgp l2vpn evpn route type 3' || true

echo
echo "============================================================"
echo " DONE"
echo " Output directory:"
echo " $OUT"
echo "============================================================"
