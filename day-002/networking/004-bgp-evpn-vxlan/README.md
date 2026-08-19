# EVPN-VXLAN Lab

A small FRRouting 10.7.0 EVPN/VXLAN lab for learning the control-plane and Linux dataplane interaction.

This lab intentionally starts with **L2 EVPN/VXLAN only**:

- IPv4 underlay
- iBGP underlay reachability
- one route reflector
- BGP EVPN overlay
- three L2VNIs: RED=100, GREEN=101, BLUE=102
- one host on each leaf per VNI
- Linux bridge + traditional VXLAN device per VNI
- EVPN Type-2 MAC/IP routes
- EVPN Type-3 IMET routes
- VXLAN UDP/4789 dataplane

It does **not** add IRB/L3VNI yet. That is deliberate: first verify L2 EVPN and VXLAN end-to-end, then build symmetric IRB on top.

## Versions

- FRR: `quay.io/frrouting/frr:10.7.0`
- Alpine hosts: `alpine:3.20`
- VXLAN UDP destination port: `4789`
- BGP AS: `65000`

FRR 10.7 documentation explicitly describes EVPN as the BGP control plane for bridged/routed VPNs, and `advertise-all-vni` under `address-family l2vpn evpn` is mandatory for EVPN-VXLAN on the underlay VRF. The Linux VXLAN interfaces in this lab use `nolearning`; FRR's documentation recommends disabling kernel dynamic MAC/VTEP learning for EVPN-controlled VXLAN interfaces. citeturn1view0turn2search0

## Topology

```text
                           iBGP IPv4 + BGP EVPN
                         10.0.1.0/30  10.0.2.0/30
                              |              |
                              |              |
                        +-----+--------------+------+
                        |          spine            |
                        |           RR              |
                        |       10.255.0.254        |
                        +-----+------+ +-----+------+
                              |              |
                         10.0.1.2       10.0.2.2
                              |              |
                         10.0.1.1       10.0.2.1
                        +-----+------+ +-----+------+
                        |   leaf1    | |   leaf2    |
                        | VTEP .1    | | VTEP .2    |
                        +--+---+---+-+ +--+---+---+-+
                           |   |   |      |   |   |
                          red grn blu    red grn blu
                           |   |   |      |   |   |
                         client*       server*
```

VTEP loopbacks:

| Node | VTEP / loopback |
|---|---|
| leaf1 | `10.255.0.1/32` |
| leaf2 | `10.255.0.2/32` |
| spine/RR | `10.255.0.254/32` |

Underlay links:

| Link | Addresses |
|---|---|
| leaf1 ↔ spine | `10.0.1.1/30 ↔ 10.0.1.2/30` |
| leaf2 ↔ spine | `10.0.2.1/30 ↔ 10.0.2.2/30` |

## VNI mapping

| Tenant | VNI | leaf1 host | leaf2 host |
|---|---:|---|---|
| red | 100 | `client-red` `10.100.0.11/24` | `server-red` `10.100.0.12/24` |
| green | 101 | `client-green` `10.101.0.11/24` | `server-green` `10.101.0.12/24` |
| blue | 102 | `client-blue` `10.102.0.11/24` | `server-blue` `10.102.0.12/24` |

Hosts in the same VNI are in the same L2 subnet. There is intentionally no default gateway because this first exercise is pure L2 extension.

## Deploy

From this directory:

```bash
containerlab deploy -t evpn-vxlanlab.clab.yml
```

Check the nodes:

```bash
docker ps --filter name=clab-evpn-vxlanlab
```

## First checks

On leaf1:

```bash
docker exec -it clab-evpn-vxlanlab-leaf1 vtysh -c 'show bgp summary'
docker exec -it clab-evpn-vxlanlab-leaf1 vtysh -c 'show bgp l2vpn evpn summary'
docker exec -it clab-evpn-vxlanlab-leaf1 vtysh -c 'show evpn vni'
docker exec -it clab-evpn-vxlanlab-leaf1 vtysh -c 'show evpn mac vni 100'
```

On leaf2, use the corresponding commands.

On the spine/RR:

```bash
docker exec -it clab-evpn-vxlanlab-spine vtysh -c 'show bgp l2vpn evpn summary'
docker exec -it clab-evpn-vxlanlab-spine vtysh -c 'show bgp l2vpn evpn'
```

The spine is only the BGP route reflector here. It is **not a VTEP** and does not need the tenant VXLAN interfaces.

## Test L2 forwarding

Red:

```bash
docker exec -it clab-evpn-vxlanlab-client-red ping -c 3 10.100.0.12
```

Green:

```bash
docker exec -it clab-evpn-vxlanlab-client-green ping -c 3 10.101.0.12
```

Blue:

```bash
docker exec -it clab-evpn-vxlanlab-client-blue ping -c 3 10.102.0.12
```

Before the first ping, inspect the host neighbor table:

```bash
docker exec -it clab-evpn-vxlanlab-client-red ip neigh
```

Then inspect leaf FDB state:

```bash
docker exec -it clab-evpn-vxlanlab-leaf1 bridge fdb show
docker exec -it clab-evpn-vxlanlab-leaf2 bridge fdb show
```

And inspect EVPN's view:

```bash
docker exec -it clab-evpn-vxlanlab-leaf1 vtysh -c 'show evpn mac vni 100 detail'
docker exec -it clab-evpn-vxlanlab-leaf2 vtysh -c 'show evpn mac vni 100 detail'
```

## What to look for

### 1. Underlay

The leafs need reachability to each other's VTEP loopbacks.

The IPv4 BGP table should contain:

- leaf1 → `10.255.0.2/32`
- leaf2 → `10.255.0.1/32`

The RR reflects those IPv4 routes between the leaves.

### 2. EVPN control plane

The leafs establish BGP EVPN sessions to the RR.

The RR reflects EVPN routes between the leafs.

You should see:

- Type-2: MAC/IP Advertisement
- Type-3: Inclusive Multicast Ethernet Tag / IMET

The RR does not need VXLAN interfaces because it is only reflecting the control plane.

### 3. VXLAN dataplane

A cross-leaf packet should look conceptually like:

```text
Inner Ethernet
    ↓
Outer UDP
    dst port 4789
    ↓
VXLAN header
    VNI 100 / 101 / 102
    ↓
Outer IP
    leaf1 VTEP → leaf2 VTEP
```

Capture on the leaf underlay interface if you want to see the actual VXLAN packet.

For example:

```bash
docker exec clab-evpn-vxlanlab-leaf1 tcpdump -ni eth1 -vv 'udp port 4789'
```

If `tcpdump` is not present in the FRR image, install it inside the lab container or use a host-side capture on the corresponding containerlab link.

## Important Linux dataplane detail

Each VNI is represented here by:

```text
host interface
     |
   bridge
     |
 traditional VXLAN interface
     |
  UDP/4789
```

For example, red on leaf1 is conceptually:

```text
eth2 ── br-red ── vxlan-red
                     |
                  VNI 100
```

The VXLAN device is configured with:

- local VTEP IP
- VNI
- UDP destination port 4789
- `nolearning`

The kernel bridge handles local L2 forwarding. FRR provides the EVPN control-plane information used to program the remote MAC/VTEP state.

FRR documents both traditional VXLAN devices and the newer Single VXLAN Device model. This lab deliberately uses the traditional one-VXLAN-device-per-VNI model because it makes the first EVPN lab easier to inspect. citeturn1view0

## Troubleshooting order

If a host-to-host ping fails, don't jump straight to packet capture.

Check in this order:

1. **Host link is up**
2. **Host has the expected IP**
3. **Leaf bridge exists**
4. **VXLAN interface exists and is up**
5. **Leaf ↔ RR IPv4 BGP is established**
6. **Leafs have routes to each other's VTEP loopbacks**
7. **Leaf ↔ RR EVPN AF is established**
8. **RR is reflecting EVPN routes**
9. **EVPN Type-2 MAC/IP route exists**
10. **Remote MAC/VTEP appears in the Linux/FRR dataplane**
11. **UDP/4789 packets appear between VTEPs**

This separation is important:

**BGP EVPN = control plane**

**VXLAN = overlay dataplane**

**Linux bridge/FDB = local Ethernet forwarding**

## What comes next

Once this L2 lab works, the next lab should add:

1. VLAN-aware bridges
2. SVIs
3. L3VNI / IP-VRF
4. symmetric IRB
5. EVPN Type-5 prefix routes
6. IPv6/ND
7. optional anycast gateway
8. packet captures showing the full VXLAN + inner Ethernet/IP flow

Do not add those pieces until the L2 EVPN control plane and VXLAN dataplane are understood independently.
