# Topology

## Logical topology

```text
                         iBGP-LU
                    +----------------+
                    |      RR1       |
                    |    2.2.2.2     |
                    +----------------+
                     /              \
                    /                \
              PE1 1.1.1.1        PE2 4.4.4.4
                 +-----+          +-----+
                 |     |----------|     |
                 +-----+  VPNv4   +-----+
                  | | |            | | |
                red green blue   red green blue
                  | | |            | | |
               clients          servers
```

RR1 provides the BGP-LU transport control plane. PE1 and PE2 establish the VPNv4 session directly.

## Addressing

### PE1

```text
lo    1.1.1.1/32
eth1  192.0.2.1/30   PE1-RR1
eth3  10.1.0.1/24   red
eth4  10.2.0.1/24   green
eth5  10.3.0.1/24   blue
```

### RR1

```text
lo    2.2.2.2/32
eth1  192.0.2.2/30   PE1
eth2  192.0.2.5/30   PE2
```

### PE2

```text
lo    4.4.4.4/32
eth2  192.0.2.10/30 PE2-RR1
eth3  10.1.1.1/24   red
eth4  10.2.1.1/24   green
eth5  10.3.1.1/24   blue
```

## Customer endpoints

```text
client-red    10.1.0.2/24  -> PE1 red 10.1.0.1
server-red    10.1.1.2/24  -> PE2 red 10.1.1.1

client-green  10.2.0.2/24  -> PE1 green 10.2.0.1
server-green  10.2.1.2/24  -> PE2 green 10.2.1.1

client-blue   10.3.0.2/24  -> PE1 blue 10.3.0.1
server-blue   10.3.1.2/24  -> PE2 blue 10.3.1.1
```

The endpoints have their directly attached PE as the default gateway, so no additional customer routes are needed for these `/24`s.

## BGP

### Transport

```text
PE1 <---- iBGP-LU ----> RR1 <---- iBGP-LU ----> PE2
```

PE1 advertises `1.1.1.1/32`; PE2 advertises `4.4.4.4/32`.

### VPN

```text
PE1 <---------------- VPNv4 ----------------> PE2
```

The RR does not need VPNv4 peering for this topology.

## VRF RD/RT plan

PE1:

```text
red    RD 65000:100   RT export 65000:100
green  RD 65000:101   RT export 65000:101
blue   RD 65000:102   RT export 65000:102
```

PE2:

```text
red    RD 65000:200   RT import 65000:100   RT export 65000:200
green  RD 65000:201   RT import 65000:101   RT export 65000:201
blue   RD 65000:202   RT import 65000:102   RT export 65000:202
```

This deliberately uses different RD and RT values to verify that FRR preserves them independently.

## FRR edge case

We encountered an issue where the configured VPN export RT could be overwritten by the RD-derived value when both were present.

Relevant fix:

```text
9cbdc0b9b0d6c977b76bf30c81adf44a4236a49e
```

The issue was described as:

```text
bgpd: prevent rt vpn export from being overwritten by rd value
```

Use:

```text
./scripts/patch-rt-pe2.sh
```

when the workaround is required.

Packet capture should confirm, for example:

```text
RD = 65000:200
RT = 65000:100
```

## MPLS

Transport labels are installed from BGP-LU.

Inspect with:

```text
show mpls table
ip -f mpls route show
ip route show
```

The forwarding path observed in the lab includes:

```text
push -> swap -> PHP/pop
```

PHP was verified by observing an `implicit-null` operation and the corresponding label pop in packet captures.

## Capturing the dataplane

Use the PE transport interfaces:

```text
PE1 eth1
PE2 eth2
```

rather than only the VRF-facing interfaces.

Run:

```text
./scripts/ping-and-capture-vrf-mpls-traffic.sh
```

This generates traffic and captures the relevant packets, then copies and merges the pcaps.

Install `tcpdump` in the Alpine endpoint containers if endpoint-side captures are desired.

## What to inspect

### BGP-LU

```text
MP_REACH_NLRI
AFI IPv4
SAFI 4 (Labeled Unicast)
Label Stack
```

### VPNv4

```text
MP_REACH_NLRI
AFI IPv4
SAFI 128 (Labeled VPN Unicast)
Route Distinguisher
VPN Label
Extended Community / Route Target
```

### MPLS dataplane

Correlate packet labels with:

```text
show mpls table
ip -f mpls route show
```

Look for:

```text
label push
label swap
PHP / label pop
ICMP request
ICMP reply
```

The BGP control-plane UPDATEs themselves are not expected to carry an MPLS outer label simply because the UPDATE advertises labeled NLRI.

## Lab scripts

```text
./scripts/fix-bgp-lu.sh
./scripts/patch-rt-pe2.sh
./scripts/ping-and-capture-vrf-mpls-traffic.sh
```
