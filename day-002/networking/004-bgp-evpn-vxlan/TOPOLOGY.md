# EVPN-VXLAN Topology

## Purpose

This lab is the first EVPN/VXLAN step after the MPLS/BGP-LU work.

It intentionally isolates **L2 EVPN over VXLAN** before introducing IRB, VRFs, L3VNIs, or Type-5 routes.

The control plane is BGP EVPN.

The overlay dataplane is VXLAN.

The Linux dataplane is built from bridges and traditional VXLAN interfaces.

## Nodes

| Node | Role | Image |
|---|---|---|
| spine | iBGP route reflector / underlay | `quay.io/frrouting/frr:10.7.0` |
| leaf1 | VTEP | `quay.io/frrouting/frr:10.7.0` |
| leaf2 | VTEP | `quay.io/frrouting/frr:10.7.0` |
| client-red | L2 host | `alpine:3.20` |
| client-green | L2 host | `alpine:3.20` |
| client-blue | L2 host | `alpine:3.20` |
| server-red | L2 host | `alpine:3.20` |
| server-green | L2 host | `alpine:3.20` |
| server-blue | L2 host | `alpine:3.20` |

FRR 10.7.0 is used deliberately so this lab stays aligned with the previous BGP-LU/VPN lab.

## Physical / underlay topology

```text
                         BGP EVPN
                    +----------------+
                    |      spine     |
                    |   RR .254      |
                    +---+--------+---+
                        |        |
                  10.0.1/30   10.0.2/30
                        |        |
                  +-----+--+  +--+-----+
                  |  leaf1 |  |  leaf2 |
                  | VTEP .1|  | VTEP .2|
                  +--+--+--+  +--+--+--+
                     |  |        |  |
                  red green blue red green blue
```

Loopbacks:

```text
spine  10.255.0.254/32
leaf1  10.255.0.1/32
leaf2  10.255.0.2/32
```

Physical links:

```text
leaf1 eth1  10.0.1.1/30
spine eth1  10.0.1.2/30

leaf2 eth1  10.0.2.1/30
spine eth2  10.0.2.2/30
```

The leafs advertise their VTEP loopbacks through IPv4 unicast BGP. The spine reflects those routes between the leafs.

## Overlay

The leafs establish BGP EVPN sessions to the spine/RR.

The spine has:

```text
neighbor leaf route-reflector-client
```

under both:

```text
address-family ipv4 unicast
```

and:

```text
address-family l2vpn evpn
```

The spine does not participate in the VXLAN dataplane.

Only the leafs are VTEPs.

## VNI mapping

```text
red    VLAN/L2 domain → VNI 100
green  VLAN/L2 domain → VNI 101
blue   VLAN/L2 domain → VNI 102
```

Each leaf has one Linux bridge and one traditional VXLAN interface per VNI:

```text
br-red   ↔ vxlan-red    VNI 100
br-green ↔ vxlan-green  VNI 101
br-blue  ↔ vxlan-blue   VNI 102
```

The host-facing interfaces are enslaved directly to the corresponding bridge.

## Host addressing

```text
red:
  client-red  10.100.0.11/24
  server-red  10.100.0.12/24

green:
  client-green  10.101.0.11/24
  server-green  10.101.0.12/24

blue:
  client-blue  10.102.0.11/24
  server-blue  10.102.0.12/24
```

There is no gateway.

A successful cross-leaf ping therefore proves L2 extension rather than L3 routing.

## Expected control-plane routes

After convergence:

### IPv4 underlay

leaf1 should learn:

```text
10.255.0.2/32
```

leaf2 should learn:

```text
10.255.0.1/32
```

### EVPN

The leafs should exchange EVPN routes through the RR.

Expect:

- Type-2 MAC/IP Advertisement routes for learned hosts
- Type-3 IMET routes for the VNIs

The EVPN route carries the VNI as dataplane information; Route Targets determine route import. FRR's current documentation explicitly separates these roles. citeturn1view0

## Packet path

For:

```text
client-red → server-red
```

the first packet can trigger local ARP/neighbor discovery.

After EVPN has learned the remote endpoint, the data path is conceptually:

```text
client-red
    |
eth2
    |
br-red
    |
vxlan-red
    |
UDP/4789
    |
leaf1 VTEP 10.255.0.1
    |
underlay
    |
leaf2 VTEP 10.255.0.2
    |
vxlan-red
    |
br-red
    |
server-red
```

The outer packet identifies the remote VTEP and carries the VNI.

The inner Ethernet frame is the original tenant frame.

## Useful commands

On leafs:

```bash
show bgp summary
show bgp l2vpn evpn summary
show bgp l2vpn evpn
show evpn vni
show evpn mac vni 100 detail
show evpn mac vni 101 detail
show evpn mac vni 102 detail
```

Linux:

```bash
ip -d link show vxlan-red
ip -d link show vxlan-green
ip -d link show vxlan-blue

bridge fdb show
bridge fdb show dev vxlan-red
bridge fdb show dev vxlan-green
bridge fdb show dev vxlan-blue
```

## Capture points

### BGP EVPN

Capture on the leaf ↔ spine underlay interface:

```text
tcp port 179
```

Look for:

```text
BGP UPDATE
MP_REACH_NLRI
AFI/SAFI = L2VPN / EVPN
```

### VXLAN dataplane

Capture on the leaf ↔ spine interface:

```text
udp port 4789
```

Look for:

```text
Outer IP:
  leaf VTEP → remote VTEP

UDP:
  destination port 4789

VXLAN:
  VNI 100 / 101 / 102

Inner Ethernet:
  original tenant MACs
```

This is the key control-plane/dataplane distinction:

```text
BGP EVPN
   ↓
learns MAC/IP/VTEP information

Linux + VXLAN
   ↓
actually transports the tenant Ethernet frame
```

## Reference model

FRR documentation describes:

- EVPN as BGP-based signaling for L2/L3 VPNs.
- MAC-VRFs as bridging/FDB plus ARP/NDP state.
- VNIs as L2 or L3 identifiers.
- `advertise-all-vni` as the command that enables the EVPN-VXLAN underlay.
- VXLAN interfaces with kernel learning disabled for EVPN-controlled dataplanes.

See the official FRR EVPN documentation for the authoritative implementation details. citeturn1view0turn2search0

Containerlab's Linux node kind supports startup `exec` commands, which is what this lab uses to build the Linux bridges and VXLAN devices inside the FRR containers. citeturn1search1turn1search7
