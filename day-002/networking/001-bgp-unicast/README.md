# BGP Unicast — iBGP Route Reflector + eBGP

## Purpose

This lab covers the BGP unicast behavior we investigated:

- eBGP between CE and PE routers
- iBGP between PE routers and an RR
- Route reflection
- BGP next-hop behavior
- `next-hop-self`
- recursive next-hop resolution
- underlay vs overlay
- BGP path attributes
- BGP `ORIGIN`
- AS_PATH preservation
- LOCAL_PREF
- ORIGINATOR_ID
- CLUSTER_LIST
- BGP UPDATE / OPEN / NOTIFICATION messages
- BGP connection collision resolution
- BGP policy / route-maps
- BGP route installation into the RIB/FIB
- Linux kernel routes vs FRR route views
- connected vs local routes
- relevant netlink concepts

---

# 1. Lab Topology

There are five routers:

- CE1 — AS 65100
- PE1 — AS 65000
- RR1 — AS 65000
- PE2 — AS 65000
- CE2 — AS 65200

The BGP relationships are:

```text
CE1 ---- eBGP ---- PE1 ---- iBGP ---- RR1 ---- iBGP ---- PE2 ---- eBGP ---- CE2
```

RR1 is a route reflector.

PE1 and PE2 are RR clients.

The important distinction is that the BGP topology and the forwarding topology do not necessarily have to be identical.

---

# 2. eBGP

CE1 and PE1 are in different ASes.

Example:

```text
CE1 AS 65100
     |
     | eBGP
     |
PE1 AS 65000
```

CE1 advertises its loopback:

```text
10.1.1.1/32
```

The UPDATE observed from CE1 contained:

```text
ORIGIN: IGP
AS_PATH: 65100
NEXT_HOP: 10.0.10.1
MED: 0
NLRI: 10.1.1.1/32
```

The important point is that `ORIGIN: IGP` does **not** mean that the route was learned through OSPF or iBGP.

It means that the route was originated into BGP using the BGP `network` mechanism (or otherwise has BGP origin code IGP).

For example:

```text
router bgp 65100
 address-family ipv4 unicast
  network 10.1.1.1/32
```

So:

```text
ORIGIN = IGP
```

is a BGP path attribute and is not a statement about which routing protocol physically carried the packet.

---

# 3. BGP `network` Does Not Mean Redistribution

This:

```text
network 10.1.1.1/32
```

does not mean:

> redistribute everything from the kernel.

It means:

> originate this exact prefix into BGP, provided the required route exists in the local routing table.

That is different from:

```text
redistribute connected
redistribute kernel
redistribute static
redistribute ospf
```

Those commands import routes from another routing source into BGP.

---

# 4. Why the CE Had a BGP Policy Indication

The BGP summary showed:

```text
(Policy) (Policy)
```

for the neighbor.

That means FRR has policy processing associated with the session / address family.

BGP policy is deliberately explicit in many configurations.

A route-map can control what is accepted inbound or advertised outbound.

Example:

```text
neighbor 10.0.10.1 route-map CE1-LO-RM-IN in
```

This controls inbound routes from that neighbor.

A route-map can contain:

```text
route-map NAME permit 10
```

The `10` is the sequence number of that route-map entry.

For example:

```text
route-map TEST permit 10
 match ip address prefix-list LOOPBACKS

route-map TEST permit 20
 ...
```

FRR evaluates route-map entries in sequence order.

The `permit` means that a route matching that entry is permitted by that policy entry.

The sequence number is not an AD, metric, or BGP preference value. It is simply the ordering of policy statements.

---

# 5. iBGP

PE1, RR1 and PE2 are all in:

```text
AS 65000
```

Therefore their BGP sessions are iBGP.

Example:

```text
PE1 ---- iBGP ---- RR1 ---- iBGP ---- PE2
```

Normally, an iBGP speaker does not advertise an iBGP-learned route to another iBGP peer.

That is the classic iBGP full-mesh problem.

A route reflector solves this.

---

# 6. Route Reflection

RR1 is configured with PE1 and PE2 as route-reflector clients.

Conceptually:

```text
             RR1
            /   \
          PE1   PE2
          client client
```

PE2 advertises a route to RR1.

RR1 can reflect that route to PE1.

The reflected route does not automatically mean:

> RR1 is now the forwarding next hop.

The BGP NEXT_HOP attribute can remain the original next hop unless something changes it.

This is why the PE receiving a reflected route may see something like:

```text
10.0.0.22/32
    next-hop 10.0.1.3
```

even though the BGP UPDATE arrived from RR1.

The BGP peer that sent the UPDATE and the NEXT_HOP carried inside that UPDATE are separate concepts.

---

# 7. ORIGINATOR_ID and CLUSTER_LIST

When RR1 reflects a route, it adds route-reflection attributes.

For a route originated by PE2, we observed:

```text
ORIGINATOR_ID: 10.0.0.22
CLUSTER_LIST: 10.0.0.1
```

These attributes help prevent routing loops in route-reflector topologies.

`ORIGINATOR_ID` identifies the original BGP speaker that originated the route.

`CLUSTER_LIST` records the route-reflector cluster IDs through which the route has passed.

A route reflector receiving a route containing its own cluster ID can reject it to prevent a reflection loop.

The receiving router can also detect an originator loop.

---

# 8. NEXT_HOP and `next-hop-self`

This was one of the most important observations in the lab.

Suppose:

```text
CE1 ---- PE1 ---- RR1 ---- PE2
```

CE1 advertises:

```text
10.1.1.1/32
NEXT_HOP = 10.0.10.1
```

PE1 learns that route through eBGP.

When PE1 advertises the route into iBGP, its next-hop behavior matters.

With:

```text
neighbor 10.0.1.0 next-hop-self
```

PE1 advertises itself as the BGP next hop to RR1.

So RR1 can receive:

```text
10.1.1.1/32
NEXT_HOP = PE1
AS_PATH = 65100
```

The AS_PATH is preserved when crossing iBGP.

---

# 9. Is `next-hop-self` Required Everywhere?

No.

It depends on the desired forwarding architecture and whether the receiving router can resolve the advertised next hop.

Without `next-hop-self`, an iBGP router can preserve a next hop learned from an external peer.

That can be perfectly valid if every router that needs to forward traffic can reach that next hop through the underlay.

With `next-hop-self`, the advertising router deliberately changes the next hop to itself.

This is common when you want a predictable hop-by-hop forwarding relationship or when the original next hop is not reachable from the receiving router.

It is especially common on PE routers at an eBGP/ iBGP boundary.

But it is not a universal rule that every iBGP hop must rewrite NEXT_HOP.

---

# 10. Recursive Next-Hop Resolution

This was another major lab observation.

PE1 received:

```text
10.0.0.22/32
NEXT_HOP = 10.0.1.3
```

FRR showed:

```text
B 10.0.0.22/32
  via 10.0.1.3 (recursive)
```

That means BGP's next hop is not necessarily the directly connected destination of the final packet.

The router asks its normal routing table:

> How do I reach 10.0.1.3?

In the lab, the answer came from an underlay route.

Once that resolution succeeds, the forwarding path can use the resolved interface / adjacency.

So:

```text
BGP route
    |
    +-- destination prefix
    |
    +-- BGP next hop
             |
             v
        normal RIB lookup
             |
             v
       resolved interface
             |
             v
          forwarding
```

---

# 11. Overlay vs Underlay

A useful way to think about this:

### Overlay

The BGP route says:

```text
10.0.0.22/32 via 10.0.1.3
```

BGP is providing the route and next-hop information.

### Underlay

The normal routing system answers:

```text
How do I reach 10.0.1.3?
```

That may be provided by:

- connected routes
- static routes
- OSPF
- IS-IS
- BGP
- BGP labeled-unicast
- another routing mechanism

The underlay is responsible for making the BGP next hop recursively reachable.

BGP does not need to own the entire forwarding path to the next hop.

This separation is a major reason overlay architectures scale well.

---

# 12. Example of Recursive Resolution

Suppose PE1 has:

```text
10.0.0.22/32 via 10.0.1.3
```

but PE1 does not have:

```text
10.0.1.3/32
```

as a directly connected route.

Instead it has:

```text
10.0.1.2/31 via eth1
```

or another route that eventually reaches the next hop.

PE1 recursively resolves the BGP next hop.

The final packet does not use some magical BGP-specific MAC address.

The forwarding plane resolves the next hop through the actual outgoing interface / adjacency.

---

# 13. Packet Forwarding

The IP destination remains the destination of the original packet.

At every routed hop, the Layer-2 header is rewritten.

Conceptually:

```text
Host A
  |
  | Ethernet frame
  v
R1
  |
  | new Ethernet frame
  v
R2
  |
  | new Ethernet frame
  v
Host B
```

The source and destination MAC addresses change at every L3 hop.

The IP destination generally remains unchanged.

For recursive BGP next hops, the forwarding decision ultimately depends on the resolved RIB/FIB entry and the corresponding L2 adjacency.

---

# 14. BGP Attributes Observed

## ORIGIN

Observed:

```text
ORIGIN: IGP
```

This means the BGP origin code is `IGP`.

It does not mean:

> this route was learned through OSPF.

For a `network` statement, FRR normally originates it with ORIGIN IGP.

Other possible origin codes include:

```text
IGP
EGP
INCOMPLETE
```

---

## AS_PATH

CE1 advertised:

```text
AS_PATH = 65100
```

When PE2 later advertised that route into the AS 65000 iBGP fabric, the AS_PATH remained:

```text
65100
```

The iBGP hop does not prepend AS 65000.

AS_PATH is used heavily for:

- loop prevention
- path selection
- policy
- AS path manipulation

---

## LOCAL_PREF

Within an AS, BGP commonly uses:

```text
LOCAL_PREF = 100
```

It is an internal preference attribute.

It is normally carried through iBGP and is used to select preferred exit paths inside the AS.

Higher LOCAL_PREF is preferred.

---

## MED

The lab showed:

```text
MED = 0
```

MED can be used to influence which entry point into an AS is preferred, particularly when comparing paths learned from the same neighboring AS.

---

## NEXT_HOP

This identifies the next-hop address that must be recursively resolved by the receiving router.

It is not necessarily:

> the IP address of the BGP TCP peer.

That distinction is critical.

---

## ORIGINATOR_ID

Added by a route reflector to identify the original route originator.

Example:

```text
ORIGINATOR_ID = 10.0.0.22
```

---

## CLUSTER_LIST

Added / modified by route reflectors.

Example:

```text
CLUSTER_LIST = 10.0.0.1
```

Used to prevent route-reflector loops.

---

# 15. BGP OPEN

When a BGP session comes up, the peers establish TCP first.

Then they exchange BGP OPEN messages.

The OPEN contains information such as:

- BGP version
- ASN
- Hold Time
- BGP Identifier
- optional parameters
- capabilities

Capabilities can advertise things such as:

- IPv4 Unicast
- Route Refresh
- 4-byte AS
- Graceful Restart
- Add-Path
- Extended Message

---

# 16. BGP State Machine

The simplified progression is:

```text
Idle
  |
  v
Connect
  |
  v
Active
  |
  v
OpenSent
  |
  v
OpenConfirm
  |
  v
Established
```

Once the session reaches Established, BGP can exchange UPDATE messages.

The actual protocol has more detail and events, but this is the useful mental model for packet analysis.

---

# 17. BGP UPDATE Messages

An UPDATE can contain:

- withdrawn routes
- path attributes
- NLRI

Example:

```text
ORIGIN
AS_PATH
NEXT_HOP
MED
NLRI
```

An UPDATE does not have to contain a route announcement.

It can be used to withdraw routes.

It can also be an UPDATE with no NLRI/path attributes for protocol signaling purposes.

---

# 18. End-of-RIB / Empty UPDATE

You observed:

```text
Withdrawn Routes Length: 0
Total Path Attribute Length: 0
```

An UPDATE with no withdrawn routes and no path attributes can be used as an End-of-RIB marker.

It tells the peer, conceptually:

> I have finished sending the initial set of routes for this address family.

This is useful for convergence and graceful-restart behavior.

So seeing an apparently empty UPDATE does not necessarily mean:

> somebody accidentally sent an empty packet.

---

# 19. BGP NOTIFICATION — Connection Collision

You captured:

```text
Major error Code: Cease (6)
Minor error Code (Cease): Connection Collision Resolution (7)
```

This happens when both peers have competing TCP connections for the same BGP session.

BGP can end up with two connection attempts:

```text
PE1 -> RR1
RR1 -> PE1
```

Both may temporarily exist.

BGP has connection-collision rules to decide which connection survives.

The losing connection is closed with a Cease / Connection Collision Resolution notification.

So seeing two TCP connection attempts during establishment is not necessarily a broken configuration.

It can be normal BGP behavior.

---

# 20. Hard Reset

When you used:

```text
clear bgp ...
```

FRR tore down the BGP session.

The peer observed a BGP NOTIFICATION / session termination.

Then the TCP session was established again.

After the new TCP connection:

```text
TCP
  -> OPEN
  <- OPEN
  -> UPDATE
  <- UPDATE
  -> KEEPALIVE
  <- KEEPALIVE
```

The exact ordering and number of messages can vary because of capabilities, route processing, route refresh, End-of-RIB, graceful restart, and connection collision behavior.

---

# 21. BGP Does Not Automatically Provide Underlay Reachability

This was an important lab correction.

Suppose BGP says:

```text
10.0.0.22/32 via 10.0.1.3
```

but the router has no route toward:

```text
10.0.1.3
```

Then the BGP route cannot be usefully forwarded.

BGP does not automatically invent a path to its next hop.

The next hop must be recursively resolvable.

You can provide that reachability with:

```text
connected
static
OSPF
IS-IS
BGP
BGP LU
...
```

In the lab we used static / kernel routes to make the underlay reachable.

In production networks, an IGP or another underlay routing system is common.

---

# 22. RIB vs FIB

BGP first determines the best BGP path.

Then the route is considered for installation into the system routing table / RIB.

The forwarding plane ultimately uses the FIB.

Conceptually:

```text
BGP control plane
       |
       v
BGP best path
       |
       v
RIB selection
       |
       v
FIB
       |
       v
packet forwarding
```

BGP's own path-selection process is different from the final selection among competing routing protocols.

For example, if multiple protocols offer the same prefix, administrative distance and related RIB selection rules matter.

---

# 23. FRR `show ip route`: C, L, K

FRR can show different route sources.

Typical entries include:

```text
C  10.0.10.0/31 is directly connected
L  10.0.10.1/32 is directly connected
K  0.0.0.0/0 via ...
```

### Connected — C

A connected route represents the directly attached network.

For:

```text
10.0.10.1/31
```

the network is:

```text
10.0.10.0/31
```

So FRR has:

```text
C 10.0.10.0/31
```

This means destinations in that connected prefix are reachable through that interface.

### Local — L

The local route represents the address assigned to the local machine/interface.

Example:

```text
L 10.0.10.1/32
```

It means:

> 10.0.10.1 is a local address owned by this host.

Traffic destined to that exact address is local delivery, not forwarding through another router.

### Kernel — K

A kernel route is a route that FRR learned from the Linux kernel routing table.

For example:

```text
K 0.0.0.0/0 via 172.20.20.1
```

means the Linux kernel already has that route, and FRR knows about it.

These labels describe where FRR learned / represents the route, not three different kinds of Ethernet forwarding.

---

# 24. Linux `ip route` Local Entry

You observed:

```text
local 10.1.1.1 dev lo proto kernel scope host src 10.1.1.1
```

Breakdown:

### `local`

This is the Linux `local` routing table.

It means the destination address belongs to the local host.

### `10.1.1.1`

The destination.

### `dev lo`

The packet is delivered locally through the loopback device.

### `proto kernel`

The route was automatically installed by the Linux kernel as a consequence of the address configuration.

### `scope host`

The route applies to the local host.

### `src 10.1.1.1`

The preferred source address associated with this route.

The Linux routing system has multiple routing tables, including the local table.

You can inspect them with commands such as:

```bash
ip rule
ip route show table local
ip route show table main
```

---

# 25. Netlink and FRR

FRR communicates with the Linux kernel through Netlink.

Your intuition was correct that route and link/address changes are represented by different classes of Netlink messages.

Important families include:

```text
RTM_NEWLINK
RTM_DELLINK
RTM_NEWADDR
RTM_DELADDR
RTM_NEWROUTE
RTM_DELROUTE
```

Conceptually:

### Link events

```text
RTM_NEWLINK
RTM_DELLINK
```

These communicate interface/link state changes and attributes.

### Address events

```text
RTM_NEWADDR
RTM_DELADDR
```

These relate to IP addresses being added to or removed from interfaces.

### Route events

```text
RTM_NEWROUTE
RTM_DELROUTE
```

These relate to routes in the kernel routing tables.

So it is better not to think:

```text
RTM_NEWROUTE = kernel route
RTM_NEWLINK = connected route
```

The relationship is more nuanced.

A connected/local route can be created by Linux as a consequence of an address being assigned to an interface, and FRR can observe the resulting route/address information through Netlink.

FRR maintains its own routing knowledge and synchronizes relevant information with the kernel.

---

# 26. Kernel Route vs Connected Route

This distinction matters.

A route being shown as:

```text
K
```

in FRR means FRR learned it from the kernel.

A route being shown as:

```text
C
```

means FRR considers it a connected route.

The underlying Linux kernel may itself have several corresponding entries/tables.

Therefore the FRR route code should not be interpreted as a literal one-to-one mapping to one Netlink message type.

Think:

```text
Linux kernel
     |
     | Netlink
     v
   FRR
     |
     v
FRR route representation
```

---

# 27. Recursive Resolution and Failure

Suppose:

```text
BGP route:
10.0.0.22/32 via 10.0.1.3
```

and the underlay route to:

```text
10.0.1.3
```

disappears.

The BGP path may still exist in the BGP table, but the next hop becomes unresolved.

The route cannot be installed/used as a forwarding route until its next hop becomes resolvable again.

This is an important distinction:

```text
BGP control-plane path exists
        !=
usable forwarding path exists
```

---

# 28. What We Observed in the Lab

A useful sequence was:

```text
CE1 originates 10.1.1.1/32
        |
        | eBGP
        v
PE1
        |
        | iBGP
        | next-hop-self
        v
RR1
        |
        | route reflection
        v
PE2
```

The original route had:

```text
AS_PATH = 65100
```

The iBGP advertisement retained that AS_PATH.

Route reflection added:

```text
ORIGINATOR_ID
CLUSTER_LIST
```

The next hop depended on the configured `next-hop-self` behavior.

The receiving router then had to recursively resolve that next hop through the underlay.

---

# 29. Commands Worth Remembering

## BGP overview

```bash
show bgp ipv4 unicast
show bgp ipv4 summary
```

## Specific route

```bash
show bgp ipv4 unicast 10.0.0.22/32
show ip route 10.0.0.22/32
```

## Neighbor details

```bash
show bgp ipv4 neighbors <ADDRESS>
```

## Advertisements

```bash
show bgp ipv4 neighbors <ADDRESS> advertised-routes
show bgp ipv4 neighbors <ADDRESS> routes
```

## Linux underlay

```bash
ip route
ip route show table local
ip rule
ip addr
```

## Packet capture

```bash
tcpdump -ni <interface> tcp port 179
```

Then inspect:

```text
OPEN
UPDATE
KEEPALIVE
NOTIFICATION
```

---

# 30. Core Mental Model

The most important mental model from this lab is:

```text
                 BGP CONTROL PLANE
                       |
                       v
              "Reach prefix X
               via next-hop Y"
                       |
                       v
              Recursive lookup
                       |
                       v
              UNDERLAY ROUTING
                       |
                       v
              Interface / adjacency
                       |
                       v
                 FIB FORWARDING
```

BGP can provide the overlay route.

The underlay makes the BGP next hop reachable.

The forwarding plane uses the resolved result.

That separation is the foundation for many larger architectures, including MPLS, VPN overlays, EVPN/VXLAN, BGP-LU, and service-provider designs.
