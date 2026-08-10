# 004 --- Topology

## Logical topology

``` text
H1 ───────── R1 ───────── R2 ───────── H2
      h1          rtr          h2
```

Detailed addressing:

``` text
H1                         H2
2001:db8:1::2             2001:db8:2::2
      │                          │
      │ 2001:db8:1::/64          │ 2001:db8:2::/64
      │                          │
2001:db8:1::1              2001:db8:2::1
     R1 ─── 2001:db8:12::/64 ─── R2
          ::1                ::2
```

## Containerlab links

``` text
h1:eth1 <----> r1:h1
r1:rtr  <----> r2:rtr
r2:h2   <----> h2:eth1
```

The router-to-router interfaces are named `rtr` to make the topology
obvious in `ip -br link` and FRR configuration.

## Connected versus remote routes

R1 automatically knows:

``` text
2001:db8:1::/64
2001:db8:12::/64
```

R2 automatically knows:

``` text
2001:db8:12::/64
2001:db8:2::/64
```

The remote network is added with a static route.

## Per-link ND

There are three independent L2 segments:

``` text
H1 ↔ R1
R1 ↔ R2
R2 ↔ H2
```

Forward path:

``` text
H1 → ND for R1
R1 → ND for R2
R2 → ND for H2
```

Return path:

``` text
H2 → ND for R2
R2 → ND for R1
R1 → ND for H1
```

ND does not discover a remote endpoint across routers.

## L2/L3 forwarding model

The IPv6 packet keeps:

``` text
SRC = 2001:db8:1::2
DST = 2001:db8:2::2
```

while the Ethernet destination changes:

``` text
H1 → R1: H1 MAC → R1 MAC
R1 → R2: R1 MAC → R2 MAC
R2 → H2: R2 MAC → H2 MAC
```

## Router conversion checklist

To make a Linux node route IPv6:

### 1. Address each routed interface

``` text
R1:h1  → 2001:db8:1::1/64
R1:rtr → 2001:db8:12::1/64

R2:rtr → 2001:db8:12::2/64
R2:h2  → 2001:db8:2::1/64
```

### 2. Enable forwarding

``` bash
sysctl -w net.ipv6.conf.all.forwarding=1
```

### 3. Install or learn routes

Connected routes appear automatically. Remote networks require static or
dynamic routing information.

## Static-route failure scenarios

### Remove a remote route

Remove:

``` text
2001:db8:2::/64 via 2001:db8:12::2
```

Then inspect:

``` bash
ip -6 route get 2001:db8:2::2
```

### Break the inter-router link

The route may remain configured while the next hop becomes unreachable.

Inspect:

``` bash
ip -6 neigh
tcpdump -nni rtr icmp6
```

### Floating static route

A backup path can be configured with worse preference/administrative
distance:

``` text
primary available   → primary
primary unavailable → backup
primary restored     → primary
```

Exact syntax depends on the routing implementation.

## Scope

This topology covers:

-   multi-router IPv6 forwarding
-   connected and static routes
-   next-hop selection
-   ND per L2 segment
-   L2 header rewriting
-   routing lookup
-   static-route failures
-   recursive static routes conceptually
-   fully specified static routes conceptually
-   floating static routes conceptually
-   default routes conceptually

Dynamic routing is intentionally left for later labs.
