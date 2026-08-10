# 003 --- Topology

## Logical topology

``` text
                    R1
             +---------------+
             |               |
             |  2001:db8:1::1/64
             |  2001:db8:2::1/64
             +-------+-------+
                     |
          +----------+----------+
          |                     |
         H1                     H2
  2001:db8:1::/64       2001:db8:2::/64
```

Containerlab links:

``` text
h1:eth1 <----> r1:eth1
r1:eth2 <----> h2:eth1
```

## Converting an L2 bridge-style node into a router

Three things matter:

### 1. Layer-3 addresses on routed interfaces

``` text
R1 eth1 → 2001:db8:1::1/64
R1 eth2 → 2001:db8:2::1/64
```

### 2. Enable IPv6 forwarding

``` bash
sysctl -w net.ipv6.conf.all.forwarding=1
```

The kernel must be allowed to forward packets between interfaces.

### 3. Routing information

Connected routes appear automatically from the interface addresses:

``` text
2001:db8:1::/64 dev eth1
2001:db8:2::/64 dev eth2
```

Remote networks require additional routes or dynamically learned routes.

## RA configuration

R1 advertises each connected prefix:

``` text
interface eth1
 ipv6 nd prefix 2001:db8:1::/64
 no ipv6 nd suppress-ra

interface eth2
 ipv6 nd prefix 2001:db8:2::/64
 no ipv6 nd suppress-ra
```

Hosts learn their prefix, SLAAC address, and R1 as a default router.

## L2/L3 forwarding model

``` text
IPv6 packet:
2001:db8:1:<H1> → 2001:db8:2:<H2>

Ethernet frame on H1–R1:
H1 MAC → R1 MAC

Ethernet frame on R1–H2:
R1 MAC → H2 MAC
```

The IPv6 destination stays the same while the Ethernet frame is rebuilt
for the next link.

## Containerlab networking

A direct Containerlab link is built from a Linux veth pair:

``` text
H1 namespace
    |
  eth1
    |
  veth pair
    |
  R1 eth1
    |
R1 namespace
```

This differs from a Docker management network, where container
interfaces attach to a Docker bridge.

## Scope

This topology is limited to:

-   IPv6 ND
-   Router Advertisements
-   SLAAC
-   IPv6 forwarding
-   router preference
-   default-router learning

Static routing and multi-router forwarding are introduced in lab 004.
