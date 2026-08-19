# BGP-LU + MPLS L3VPN Lab

This lab demonstrates BGP Labeled-Unicast (BGP-LU) for labeled transport and IPv4 VPN (VPNv4) for MPLS L3VPN route exchange.

## Topology

- PE1: `1.1.1.1`
- RR1: `2.2.2.2`
- PE2: `4.4.4.4`
- iBGP-LU provides labeled transport reachability.
- PE1 and PE2 exchange VPNv4 routes directly.
- VRFs: `red`, `green`, `blue`.

## Key findings

### BGP-LU

Use:

```text
show bgp ipv4 labeled-unicast
show bgp ipv4 labeled-unicast summary
show bgp labelpool summary
show bgp labelpool requests
show bgp labelpool inuse
show mpls table
ip -f mpls route show
```

A `network` statement did not behave as expected in the initial setup, while `redistribute connected` successfully originated connected prefixes into BGP-LU.

Example:

```text
address-family ipv4 labeled-unicast
  network 1.1.1.1/32
  neighbor 192.0.2.2 activate
exit-address-family
```

or, when originating connected routes:

```text
address-family ipv4 labeled-unicast
  redistribute connected
exit-address-family
```

### VPNv4

VPNv4 is separate from BGP-LU. BGP-LU carries the transport FEC/label information; VPNv4 carries VRF prefixes with an RD, RT and VPN label.

The RR does not need to be a VPNv4 peer in this topology. The PE-to-PE VPNv4 session is direct.

### RD vs RT

RD and RT are independent:

- RD makes VPN routes unique.
- RT controls VPN import/export policy.

Example intended PE2 configuration:

```text
rd vpn export 65000:200
rt vpn import 65000:100
rt vpn export 65000:200
export vpn
import vpn
```

The resulting route should have:

```text
Route Distinguisher: 65000:200
Route Target:       65000:100
```

We hit an FRR `bgpd` edge case where the VPN export RT could be overwritten by an RD-derived value when both were configured. The relevant upstream fix is:

```text
9cbdc0b9b0d6c977b76bf30c81adf44a4236a49e
```

described as:

```text
bgpd: prevent rt vpn export from being overwritten by rd value
```

The lab workaround is:

```text
./scripts/patch-rt-pe2.sh
```

### VPN labels

VRFs use:

```text
label vpn export auto
```

Label-pool state is useful for diagnosing missing VPN routes:

```text
show bgp labelpool summary
show bgp labelpool requests
show bgp labelpool inuse
```

### MPLS dataplane

BGP UPDATE messages themselves are normal TCP control-plane packets; they are not automatically MPLS-encapsulated just because their NLRI contains labels.

Actual customer traffic is MPLS-forwarded according to the FEC/label forwarding state.

Useful commands:

```text
show mpls table
ip -f mpls route show
ip route show
```

The dataplane can perform:

```text
label push -> label swap -> label pop/PHP
```

### PHP

Penultimate Hop Popping was observed in the lab. An MPLS table entry can show:

```text
Outbound Label implicit-null
```

The penultimate router then removes the transport label before the packet reaches the egress.

Packet captures confirmed label push, swap, PHP/pop, followed by the ICMP request/reply chain.

## Packet capture

Capture the PE transport interfaces for the MPLS dataplane, e.g.:

```text
PE1 eth1
PE2 eth2
```

The VRF-facing interfaces show customer-side traffic but not the complete provider MPLS label stack.

Use:

```text
./scripts/ping-and-capture-vrf-mpls-traffic.sh
```

The script starts tcpdump, generates VRF traffic, waits for successful ping, stops captures, copies the pcaps out, and merges them with `mergecap`.

If captures are also desired on Alpine client/server containers, install `tcpdump` there too.

## Wireshark

For BGP-LU, look for:

```text
AFI IPv4
SAFI Labeled Unicast (4)
MP_REACH_NLRI
Label Stack
```

For VPNv4, look for:

```text
AFI IPv4
SAFI Labeled VPN Unicast (128)
MP_REACH_NLRI
Route Distinguisher
Label Stack
EXTENDED_COMMUNITIES
Route Target
```

For MPLS dataplane traffic, correlate the observed labels with:

```text
show mpls table
ip -f mpls route show
```

Empty `MP_UNREACH_NLRI` UPDATEs can occur during AF initialization/EOR signaling; they should not automatically be interpreted as customer-route withdrawals.

## Scripts

From the repository root:

```text
./scripts/fix-bgp-lu.sh
./scripts/patch-rt-pe2.sh
./scripts/ping-and-capture-vrf-mpls-traffic.sh
```

- `fix-bgp-lu.sh` — BGP-LU bringup workaround.
- `patch-rt-pe2.sh` — PE2 RD/RT export workaround.
- `ping-and-capture-vrf-mpls-traffic.sh` — end-to-end VRF traffic generation and MPLS/BGP capture.

## Quick validation

```text
show bgp summary
show bgp ipv4 labeled-unicast summary
show bgp ipv4 vpn summary
show bgp ipv4 labeled-unicast
show bgp ipv4 vpn
show ip route vrf all
show mpls table
show bgp labelpool summary
```

Then test:

```text
client-red -> server-red
client-green -> server-green
client-blue -> server-blue
```

and run:

```text
./scripts/ping-and-capture-vrf-mpls-traffic.sh
```
