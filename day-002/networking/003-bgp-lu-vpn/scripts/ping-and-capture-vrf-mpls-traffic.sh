#!/usr/bin/env bash
set -euo pipefail

PE1="clab-bgp-lu-vpn-rr-pe1"
RR1="clab-bgp-lu-vpn-rr-rr1"
PE2="clab-bgp-lu-vpn-rr-pe2"

OUT="./mpls-pcap-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

echo "[+] Capturing MPLS traffic..."

# Start captures
docker exec -d "$PE1" sh -c \
  "tcpdump -ni eth1 -s 0 -w /tmp/pe1-eth1.pcap 'mpls'"

docker exec -d "$RR1" sh -c \
  "tcpdump -ni eth1 -s 0 -w /tmp/rr1-eth1.pcap 'mpls'"

docker exec -d "$RR1" sh -c \
  "tcpdump -ni eth2 -s 0 -w /tmp/rr1-eth2.pcap 'mpls'"

docker exec -d "$PE2" sh -c \
  "tcpdump -ni eth2 -s 0 -w /tmp/pe2-eth2.pcap 'mpls'"

sleep 2

echo "[+] Generating red-VRF traffic..."
echo "    PE1: 10.1.0.1 -> PE2: 10.1.1.1"

SUCCESS=0

for i in {1..10}; do
    if docker exec "$PE1" \
        ip vrf exec red ping -c 2 -W 1 10.1.1.1 >/dev/null 2>&1
    then
        echo "[+] Ping successful."
        SUCCESS=1
        break
    fi

    echo "    attempt $i failed; retrying..."
    sleep 1
done

if [[ "$SUCCESS" -ne 1 ]]; then
    echo "[!] Ping never succeeded."
    echo "[!] Stopping captures anyway..."
fi

sleep 1

echo "[+] Stopping tcpdump..."

docker exec "$PE1" pkill -TERM tcpdump || true
docker exec "$RR1" pkill -TERM tcpdump || true
docker exec "$PE2" pkill -TERM tcpdump || true

sleep 1

echo "[+] Copying captures..."

docker cp "$PE1:/tmp/pe1-eth1.pcap" "$OUT/"
docker cp "$RR1:/tmp/rr1-eth1.pcap" "$OUT/"
docker cp "$RR1:/tmp/rr1-eth2.pcap" "$OUT/"
docker cp "$PE2:/tmp/pe2-eth2.pcap" "$OUT/"

echo "[+] Merging..."

mergecap -w "$OUT/mpls-flow.pcap" \
    "$OUT/pe1-eth1.pcap" \
    "$OUT/rr1-eth1.pcap" \
    "$OUT/rr1-eth2.pcap" \
    "$OUT/pe2-eth2.pcap"

echo
echo "========================================"
echo " Done"
echo "========================================"
echo "Captures: $OUT/"
echo "Merged:   $OUT/mpls-flow.pcap"
echo

if [[ "$SUCCESS" -eq 1 ]]; then
    echo "[+] VRF ping succeeded."
else
    echo "[!] VRF ping FAILED."
fi


#!/usr/bin/env bash
set -euo pipefail

PE1="clab-bgp-lu-vpn-rr-pe1"
RR1="clab-bgp-lu-vpn-rr-rr1"
PE2="clab-bgp-lu-vpn-rr-pe2"

OUT="./mpls-pcap-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

echo "[+] Starting captures..."

# Capture MPLS + BGP control-plane traffic.
docker exec "$PE1" sh -c \
  'tcpdump -ni eth1 -nn -s 0 -w /tmp/pe1-eth1.pcap "mpls or tcp port 179" >/tmp/tcpdump.log 2>&1 & echo $! >/tmp/tcpdump.pid'

docker exec "$RR1" sh -c \
  'tcpdump -ni eth1 -nn -s 0 -w /tmp/rr1-eth1.pcap "mpls or tcp port 179" >/tmp/tcpdump-eth1.log 2>&1 & echo $! >/tmp/tcpdump-eth1.pid'

docker exec "$RR1" sh -c \
  'tcpdump -ni eth2 -nn -s 0 -w /tmp/rr1-eth2.pcap "mpls or tcp port 179" >/tmp/tcpdump-eth2.log 2>&1 & echo $! >/tmp/tcpdump-eth2.pid'

docker exec "$PE2" sh -c \
  'tcpdump -ni eth2 -nn -s 0 -w /tmp/pe2-eth2.pcap "mpls or tcp port 179" >/tmp/tcpdump.log 2>&1 & echo $! >/tmp/tcpdump.pid'

sleep 2

echo "[+] Generating red-VRF traffic..."
echo "    client-red -> server-red"

SUCCESS=0

for i in {1..10}; do
    if docker exec "$PE1" \
        ip vrf exec red ping -c 2 -W 1 10.1.1.2 >/dev/null 2>&1; then
        echo "[+] Ping successful."
        SUCCESS=1
        break
    fi

    echo "    attempt $i failed; retrying..."
    sleep 1
done

# Give tcpdump a moment to capture the return packets.
sleep 2

echo "[+] Stopping captures..."

# SIGINT lets tcpdump cleanly close the pcap.
docker exec "$PE1" sh -c \
  'kill -INT "$(cat /tmp/tcpdump.pid)" 2>/dev/null || true'

docker exec "$RR1" sh -c \
  'kill -INT "$(cat /tmp/tcpdump-eth1.pid)" 2>/dev/null || true'

docker exec "$RR1" sh -c \
  'kill -INT "$(cat /tmp/tcpdump-eth2.pid)" 2>/dev/null || true'

docker exec "$PE2" sh -c \
  'kill -INT "$(cat /tmp/tcpdump.pid)" 2>/dev/null || true'

# Wait for tcpdump to flush/exit.
sleep 2

echo "[+] Verifying captures..."

docker exec "$PE1" sh -c 'ls -lh /tmp/pe1-eth1.pcap'
docker exec "$RR1" sh -c 'ls -lh /tmp/rr1-eth1.pcap /tmp/rr1-eth2.pcap'
docker exec "$PE2" sh -c 'ls -lh /tmp/pe2-eth2.pcap'

echo "[+] Copying captures..."

docker cp "$PE1:/tmp/pe1-eth1.pcap" "$OUT/"
docker cp "$RR1:/tmp/rr1-eth1.pcap" "$OUT/"
docker cp "$RR1:/tmp/rr1-eth2.pcap" "$OUT/"
docker cp "$PE2:/tmp/pe2-eth2.pcap" "$OUT/"

echo "[+] Merging captures..."

mergecap -w "$OUT/mpls-flow.pcap" \
    "$OUT/pe1-eth1.pcap" \
    "$OUT/rr1-eth1.pcap" \
    "$OUT/rr1-eth2.pcap" \
    "$OUT/pe2-eth2.pcap"

echo
echo "========================================"
echo " Capture complete"
echo "========================================"
echo "Directory: $OUT"
echo "Merged:    $OUT/mpls-flow.pcap"
echo

if [[ "$SUCCESS" -eq 1 ]]; then
    echo "[+] VRF ping succeeded."
else
    echo "[!] VRF ping FAILED."
fi
