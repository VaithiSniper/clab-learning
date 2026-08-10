# 003 --- IPv6 Router Advertisements, SLAAC, and Routing

## Purpose

This lab demonstrates IPv6 Router Advertisements (RA), Neighbor
Discovery (ND), SLAAC, IPv6 forwarding, and router preference.

### Topology

``` text
                 R1
        2001:db8:1::1/64
          eth1      eth2
             |      |
             |      |
            H1      H2
```

Networks:

-   H1--R1: `2001:db8:1::/64`
-   R1--H2: `2001:db8:2::/64`

## Concepts covered

### Router Advertisement

R1 periodically sends ICMPv6 Router Advertisements to `ff02::1` (all
IPv6 nodes).

An RA can communicate:

-   that the sender is a router
-   prefix information
-   on-link status
-   autonomous address configuration
-   default-router information
-   router preference

### SLAAC

H1 and H2 autonomously configure global IPv6 addresses from the prefixes
advertised by R1.

### RA-derived default route

Hosts learn R1 as a default router using R1's link-local address:

``` text
default via fe80::... dev eth1 proto ra
```

The router's link-local address is sufficient because the next hop is
directly reachable on that L2 link.

### Router preference

R1 advertises:

``` text
ipv6 nd router-preference high
```

This lets the RA-learned router win against an equal-metric
lower-preference default router.

The lab demonstrated:

``` text
default via Docker-GW       metric 1024  pref medium
default via R1 link-local   metric 1024  pref high
```

and:

``` bash
ip -6 route get 2001:db8:2::2
```

selected R1.

### ND versus RA

``` text
RA:
"Here is a router and information about this IPv6 prefix."

ND:
"Who has this IPv6 address on this local link?"
```

Periodic RAs do not require a response; hosts process them and refresh
local state.

## Packet observations

An RA looked like:

``` text
fe80::R1 -> ff02::1
ICMPv6 Router Advertisement
```

with Ethernet destination:

``` text
33:33:00:00:00:01
```

The Ethernet multicast address is derived from the IPv6 multicast
destination.

## Debugging lesson

At one point the BusyBox `ip` output showed RA-derived route information
with `expires 0sec`, even though R1 was continuously transmitting RAs.

Packet capture on H1 proved the RA packets were arriving. Installing
`iproute2` also changed the route-display behavior.

The useful lesson is:

> Verify kernel behavior with independent observations. Do not assume a
> single userspace tool's display is the complete truth.

## Useful commands

``` bash
ip -6 addr
ip -6 route
ip -6 neigh
ip -6 route get <destination>
tcpdump -nni eth1 -e 'icmp6 and ip6[40] == 134'
```

On R1:

``` bash
vtysh -c 'show running-config'
vtysh -c 'show ipv6 nd ra-interfaces'
```

## Key takeaway

``` text
RA
 ↓
SLAAC address
 ↓
RA-derived default router
 ↓
ND resolves local neighbor/router MAC
 ↓
IPv6 packet forwarding
```

This lab intentionally stops before multi-router static routing.
