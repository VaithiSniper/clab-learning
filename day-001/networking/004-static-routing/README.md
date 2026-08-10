# 004 --- IPv6 Static Routing and Multi-Hop Forwarding

## Purpose

This lab introduces a second router and demonstrates:

-   connected versus remote routes
-   next-hop routing
-   per-hop Neighbor Discovery
-   Layer-2 header rewriting
-   routing lookup
-   static-route failure
-   recursive, fully specified, floating, and default static-route
    concepts

## Topology

``` text
H1 ───────── R1 ───────── R2 ───────── H2
    /64             /64             /64

2001:db8:1::/64  2001:db8:12::/64  2001:db8:2::/64
```

Addresses:

  Node   Interface   IPv6
  ------ ----------- ---------------------
  H1     eth1        `2001:db8:1::2/64`
  R1     h1          `2001:db8:1::1/64`
  R1     rtr         `2001:db8:12::1/64`
  R2     rtr         `2001:db8:12::2/64`
  R2     h2          `2001:db8:2::1/64`
  H2     eth1        `2001:db8:2::2/64`

## Static routes

``` text
H1: 2001:db8:2::/64 via 2001:db8:1::1
R1: 2001:db8:2::/64 via 2001:db8:12::2
R2: 2001:db8:1::/64 via 2001:db8:12::1
H2: 2001:db8:1::/64 via 2001:db8:2::1
```

The key route is R1's:

``` text
2001:db8:2::/64 via 2001:db8:12::2
```

R1 needs R2's L2 address on the R1--R2 link; it does not need H2's MAC
at that point.

## Per-hop ND

``` text
H1
 │ ND for R1
 ▼
R1
 │ ND for R2
 ▼
R2
 │ ND for H2
 ▼
H2
```

ND is local to an L2 segment. An NS is not routed end-to-end.

If R1 has a route via `2001:db8:12::2`, it performs ND for
`2001:db8:12::2`.

## Routing lookup

``` bash
ip -6 route
ip -6 route get 2001:db8:2::2
ip -6 neigh
```

R1 should show:

``` text
2001:db8:2::2 via 2001:db8:12::2 dev rtr
```

## Packet capture: L3 stays constant, L2 changes

Useful ping filter:

``` bash
tcpdump -nni <interface> -e   'icmp6 and ((src 2001:db8:1::2 and dst 2001:db8:2::2) or (src 2001:db8:2::2 and dst 2001:db8:1::2))'
```

Across the path:

``` text
IPv6 SRC = 2001:db8:1::2
IPv6 DST = 2001:db8:2::2
```

remain unchanged.

Ethernet changes at each hop:

``` text
H1 → R1: H1 MAC → R1 MAC
R1 → R2: R1 MAC → R2 MAC
R2 → H2: R2 MAC → H2 MAC
```

This is the key L2/L3 distinction.

## Failure game: next-hop address on the wrong interface

A useful failure is to configure R2's `2001:db8:12::2/64` on the wrong
interface.

R1 correctly has:

``` text
2001:db8:2::/64 via 2001:db8:12::2
```

but its ND request goes out the R1--R2 link:

``` text
NS: who has 2001:db8:12::2?
```

If R2 does not own that address on that link, it will not answer.

R1 eventually shows:

``` text
2001:db8:12::2 dev rtr FAILED
```

Lesson:

> An IP address existing somewhere on a router is not enough. The
> next-hop address must be reachable on the local L2 segment where ND is
> performed.

## Static route types --- conceptually

### Direct next-hop static

``` text
destination → next-hop
```

Example:

``` text
ipv6 route 2001:db8:2::/64 2001:db8:12::2
```

### Fully specified static

A route specifies both the next-hop and outgoing interface where the
platform supports it.

### Recursive static

The configured next-hop itself requires another routing lookup:

``` text
destination
    ↓
next-hop A
    ↓
route lookup
    ↓
next-hop B / interface
```

### Floating static

A backup static route is configured with worse preference/administrative
distance than the primary route.

Conceptually:

``` text
primary available   → primary
primary unavailable → backup
primary restored     → primary
```

Exact administrative-distance semantics are platform-specific.

### Default static

A catch-all route:

``` text
::/0
```

used when no more-specific route matches.

## Failure games

After the basic path works:

1.  Remove R1's remote route.
2.  Observe `ip -6 route get`.
3.  Break the R1--R2 link.
4.  Observe ND and neighbor state.
5.  Restore the link.
6.  Add a backup/floating route.
7.  Compare the active route before and after failure.

The goal is to answer:

> What route was selected, what next hop was selected, and can that next
> hop be resolved on the local link?

## Troubleshooting

``` bash
ip -6 route
ip -6 route get <destination>
ip -6 neigh
tcpdump -nni <interface> -e icmp6
```

Break failures into:

``` text
Routing lookup
      ↓
Next-hop selection
      ↓
ND resolution
      ↓
L2 delivery
      ↓
IPv6 forwarding
      ↓
Remote ND
      ↓
Destination host
```

## Key takeaway

A multi-router IPv6 path is not one giant ND domain.

Each router:

1.  performs a routing lookup
2.  chooses a next hop
3.  performs ND for that next hop on its local link
4.  builds a new Ethernet frame
5.  forwards the same IPv6 packet toward the destination

Dynamic routing protocols are intentionally left for later labs.
