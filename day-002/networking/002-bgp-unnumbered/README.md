# BGP Unnumbered Lab — Revision Notes

## 1. Lab purpose

This lab focuses on:

- BGP unnumbered peering
- IPv6 link-local addresses as BGP transport / next hops
- IPv4 NLRI carried over IPv6 next hops
- eBGP between leaf and spine
- BGP best-path selection and ECMP
- IPv6 Neighbor Discovery in an unnumbered fabric
- BGP OPEN capabilities relevant to unnumbered / MP-BGP
- `MP_REACH_NLRI` and `MP_UNREACH_NLRI`
- route withdrawal and failover
- the relationship between the BGP overlay information and the underlay used to reach the BGP next hop

---

# 2. BGP unnumbered

In the lab, the routed links do not have IPv4 addresses assigned.

Instead, Linux automatically creates IPv6 link-local addresses on the interfaces.

Example:

```text
spine1
eth1  fe80::...
eth2  fe80::...
```

These link-local addresses are sufficient for establishing BGP sessions.

The important idea is:

> The BGP session is identified by the interface / link-local neighbor rather than by an IPv4 address assigned to the physical link.

FRR supports configuration such as:

```text
neighbor eth1 interface remote-as 65101
```

The BGP neighbor is therefore the interface itself.

---

# 3. IPv6 ND provides the L2 information

Because the interfaces have IPv6 link-local addresses, IPv6 Neighbor Discovery is involved.

The neighbor cache showed entries such as:

```text
fe80::a8c1:abff:fe53:3fdc dev eth1 lladdr aa:c1:ab:53:3f:dc router STALE
```

This tells Linux:

```text
IPv6 neighbor
    ↓
link-local IPv6 address
    ↓
destination MAC address
```

So the BGP session can use the neighbor's IPv6 link-local address while the kernel knows which MAC address to put into the Ethernet frame.

The neighbor cache entries are learned through IPv6 ND (NS/NA).

For the unnumbered BGP link, there is no IPv4 ARP exchange because there is no IPv4 address on the physical link.

---

# 4. What the kernel sees

The link-local address appears in Linux's local routing table:

```text
local fe80::... dev eth1 proto kernel scope link
```

Linux creates these addresses automatically for IPv6-capable interfaces.

The `proto kernel` part means the kernel created the route as a consequence of the interface/address configuration.

FRR does not necessarily display every entry from Linux's `table local` as an FRR `L` route.

In this lab, FRR displayed:

```text
C fe80::/64 is directly connected, eth1
```

while Linux's local table contained the exact interface link-local `/128`.

The important distinction is:

- Linux owns the complete kernel/local routing information.
- FRR imports relevant kernel routing information and presents it through its own RIB view.
- FRR's displayed route categories are not a literal one-to-one dump of every Linux routing-table entry.

---

# 5. BGP OPEN message

The BGP OPEN message still follows the normal BGP structure:

```text
Version
My AS
Hold Time
BGP Identifier
Optional Parameters
```

The unnumbered / MP-BGP behavior is enabled through BGP capabilities.

In the captured OPEN we saw:

```text
Multiprotocol extensions capability
Extended Next Hop Encoding
Route Refresh capability
Enhanced Route Refresh capability
4-octet AS capability
BGP-Extended Message
Additional Paths
PATHS-LIMIT
FQDN
Graceful Restart
Long-Lived Graceful Restart
```

The particularly interesting capability for this lab was:

```text
Extended Next Hop Encoding

AFI: IPv4
SAFI: Unicast
Next hop AFI: IPv6
```

This tells the peer that IPv4 routes can use an IPv6 next-hop representation.

That is the key mechanism behind the lab's:

```text
IPv4 prefix
+
IPv6 link-local next hop
```

combination.

---

# 6. Important distinction: Extended Next Hop vs Link-Local Next Hop Capability

Do not confuse these.

## Extended Next Hop Encoding

This is what the capture showed:

```text
AFI IPv4
SAFI Unicast
Next Hop AFI IPv6
```

It allows an IPv4 NLRI to use an IPv6 next hop.

That is exactly what we observed in the UPDATE messages.

## Link-Local Next Hop Capability

FRR can also expose a capability concerning use of IPv6 link-local next hops.

The neighbor output showed:

```text
Link-Local Next Hop Capability: not advertised not received
```

That does not mean the lab cannot use IPv6 link-local next hops.

The actual capture demonstrated the link-local next hop inside `MP_REACH_NLRI`.

For interview purposes, keep the concepts separate:

> Extended Next Hop Encoding describes the address-family relationship between the NLRI and next hop.

> Link-local next-hop support concerns the ability to use IPv6 link-local addresses as next hops.

---

# 7. Normal IPv4 BGP UPDATE vs MP-BGP UPDATE

This is one of the most important packet-capture differences from the lab.

## Traditional IPv4 unicast UPDATE

The normal IPv4 UPDATE looked conceptually like:

```text
UPDATE
├── Withdrawn Routes Length
├── Total Path Attribute Length
├── Path Attributes
│   ├── ORIGIN
│   ├── AS_PATH
│   ├── NEXT_HOP
│   └── ...
└── NLRI
```

The next hop is a normal BGP `NEXT_HOP` path attribute.

The IPv4 NLRI is carried in the UPDATE's NLRI field.

Example:

```text
NEXT_HOP: 10.0.10.1

NLRI:
10.1.1.1/32
```

---

# 8. MP_REACH_NLRI

With multiprotocol BGP, reachability is carried by:

```text
MP_REACH_NLRI
```

In the capture we saw:

```text
Path Attribute - MP_REACH_NLRI

AFI: IPv4
SAFI: Unicast

Next hop:
fe80::...

NLRI:
10.255.0.2/32
```

So conceptually:

```text
MP_REACH_NLRI
├── AFI
├── SAFI
├── Next Hop
└── NLRI
```

This is different from classic IPv4 UPDATE processing.

The AFI/SAFI identify what kind of address-family route is being advertised.

For this lab:

```text
AFI  = IPv4
SAFI = Unicast
```

while the next hop itself is IPv6.

That is the interesting combination:

```text
IPv4 route
        ↓
MP_REACH_NLRI
        ↓
IPv6 link-local next hop
```

---

# 9. MP_UNREACH_NLRI

Route withdrawals for MP-BGP use:

```text
MP_UNREACH_NLRI
```

rather than the classic IPv4 Withdrawn Routes field.

The capture showed:

```text
Withdrawn Routes Length: 0
Total Path Attribute Length: 12

MP_UNREACH_NLRI
    AFI: IPv4
    SAFI: Unicast

    Withdrawn:
        10.255.1.1/32
```

This is worth remembering:

### Classic IPv4 withdrawal

```text
Withdrawn Routes
```

### MP-BGP withdrawal

```text
MP_UNREACH_NLRI
```

In the observed MP-BGP withdrawal:

```text
Withdrawn Routes Length = 0
```

because the withdrawal was carried by the `MP_UNREACH_NLRI` path attribute.

---

# 10. BGP best-path and ECMP in the lab

Leaf1 had two paths to the same prefix:

```text
10.255.1.2/32

Path 1:
65000 65102
next hop = spine1's link-local

Path 2:
65000 65102
next hop = spine2's link-local
```

FRR showed:

```text
valid, external, multipath, best (Router ID)
```

for the selected path.

The two paths were otherwise equivalent enough for multipath.

Therefore the router could install/use both paths.

The final tie-breaking stage selected one path as the displayed best path, with:

```text
best (Router ID)
```

while the other remained:

```text
valid, external, multipath
```

This is an important distinction:

> "Best path" and "multipath/ECMP eligible" are not contradictory.

One path can be the BGP best path while multiple equal paths are installed/used for forwarding.

---

# 11. BGP advertisements observed on spine1

Spine1 learned:

```text
10.255.1.1/32
    from leaf1

10.255.1.2/32
    from leaf2
```

and advertised three prefixes toward each neighbor:

```text
10.255.0.1/32
10.255.1.1/32
10.255.1.2/32
```

The spine therefore acts as a normal eBGP router:

```text
leaf1 ----\
           spine
leaf2 ----/
```

It learns routes from one eBGP peer and can advertise them to another eBGP peer.

---

# 12. What happens when a link fails

When one BGP path disappears:

```text
leaf1
  |
  | path 1
  X
```

the BGP session/path is removed.

The corresponding prefix withdrawal is propagated.

The receiving router then has only the remaining valid path:

```text
leaf1
  |
  | path 2
  v
spine2
```

In the lab, after the first path disappeared:

```text
Paths: (1 available, best #1)
```

and the remaining path became:

```text
valid, external, best
```

This is the basic BGP failover mechanism.

---

# 13. Why the BGP next hop can be link-local

The BGP UPDATE can advertise:

```text
10.255.1.1/32
next hop = fe80::...
```

The next hop is not itself the destination prefix.

It says:

> To reach this IPv4 prefix, forward toward this BGP next hop.

The IPv6 link-local next hop is directly associated with the interface/link.

Linux then uses IPv6 ND / neighbor information to resolve:

```text
IPv6 link-local
        ↓
MAC address
```

and Ethernet forwarding uses that MAC.

So the packet's IP destination can remain IPv4 while the BGP control-plane next hop is IPv6.

---

# 14. Underlay vs BGP information

A useful mental model from the lab:

```text
BGP
    advertises
        ↓
destination prefix + next hop
        ↓
routing system resolves next hop
        ↓
underlay / connected link / recursive route
        ↓
neighbor resolution
        ↓
MAC
        ↓
Ethernet forwarding
```

BGP does not need to know how every packet physically traverses the network.

Its job is primarily to exchange reachability and path attributes.

The forwarding system must be able to resolve the BGP next hop.

In an unnumbered fabric, the next hop may be an IPv6 link-local address.

---

# 15. Important packet-level distinction

Keep these three things separate:

### BGP NLRI

The prefix being advertised:

```text
10.255.1.1/32
```

### BGP next hop

Where BGP says the prefix is reachable:

```text
fe80::...
```

### Ethernet destination MAC

Where the current Ethernet frame is actually sent:

```text
aa:bb:cc:...
```

The MAC is not carried as the BGP next hop.

It is resolved locally through neighbor discovery.

---

# 16. Route advertisement lifecycle

A useful sequence to remember:

```text
Interface comes up
    ↓
IPv6 link-local address exists
    ↓
ND resolves neighbor
    ↓
BGP TCP session can establish
    ↓
OPEN
    ↓
Capabilities exchanged
    ↓
KEEPALIVEs / UPDATEs
    ↓
MP_REACH_NLRI advertises routes
    ↓
BGP selects best path
    ↓
Route installed / made forwarding eligible
    ↓
Packets use resolved next hop
```

On failure:

```text
Link/session failure
    ↓
BGP path disappears
    ↓
MP_UNREACH_NLRI / withdrawal
    ↓
BGP recalculates available paths
    ↓
alternate path becomes best
    ↓
forwarding moves to alternate next hop
```

---

# 17. BGP message types observed

## OPEN

Used to establish BGP capabilities and session parameters.

Contains:

- version
- AS
- hold time
- BGP identifier
- capabilities

## UPDATE

Used for:

- route advertisements
- route withdrawals
- path attributes

## KEEPALIVE

Maintains the BGP session.

## NOTIFICATION

Used to signal errors / terminate a session.

We also observed a:

```text
Cease
Connection Collision Resolution
```

notification during session establishment.

This happened because BGP/TCP connection establishment can involve simultaneous connection attempts. BGP must resolve which TCP connection survives.

---

# 18. Why there can be two TCP connection attempts

When BGP peers start simultaneously, both sides may attempt:

```text
R1 → TCP connect → R2
R2 → TCP connect → R1
```

This can temporarily produce two TCP connections.

BGP performs connection collision resolution and keeps the appropriate connection.

The losing connection can be terminated with:

```text
NOTIFICATION
Cease
Connection Collision Resolution
```

Seeing this during startup is therefore not necessarily a broken BGP configuration.

---

# 19. Interview takeaways

If asked "what is BGP unnumbered?", a strong concise answer is:

> BGP unnumbered allows BGP peering over interfaces without assigning IPv4 addresses to the point-to-point links. The peers use IPv6 link-local addresses, with IPv6 Neighbor Discovery providing neighbor/MAC resolution. With MP-BGP / Extended Next Hop Encoding, IPv4 NLRI can be advertised with IPv6 next hops, including link-local next hops.

If asked "why do you need ND?", answer:

> The BGP control plane can identify the neighbor using its IPv6 link-local address, but actual Ethernet forwarding still needs a destination MAC. IPv6 Neighbor Discovery resolves the link-local IPv6 neighbor to that MAC.

If asked "what is MP_REACH_NLRI?", answer:

> It is the multiprotocol BGP attribute used to advertise reachability for an AFI/SAFI, including the next hop and NLRI. Unlike classic IPv4 UPDATEs, the next hop and NLRI are carried together inside MP_REACH_NLRI.

If asked "what is MP_UNREACH_NLRI?", answer:

> It is the multiprotocol BGP attribute used to withdraw NLRI for an AFI/SAFI.

If asked "does BGP know the actual physical path?", answer:

> BGP selects a next hop and path based on its control-plane information. The forwarding plane must resolve that next hop through the routing table / recursive resolution and neighbor resolution. The actual packet forwarding then happens according to the resulting FIB.

---

# 20. Commands worth remembering

### BGP overview

```text
show bgp summary
show bgp ipv4 unicast
show bgp ipv4 unicast <prefix>
```

### Neighbor details

```text
show bgp ipv4 neighbors <neighbor>
show bgp ipv4 unicast neighbors <neighbor> routes
show bgp ipv4 unicast neighbors <neighbor> advertised-routes
```

### Linux interface / neighbor state

```text
ip -br a
ip -6 addr
ip neigh show
ip -6 neigh show
```

### Linux routing

```text
ip route
ip -6 route
ip -6 route show table local
```

### Packet capture

```text
tcpdump -ni any tcp port 179
```

For this lab, Wireshark is particularly useful for inspecting:

```text
OPEN
UPDATE
MP_REACH_NLRI
MP_UNREACH_NLRI
NOTIFICATION
```

---

# 21. Mental model

The most useful compact model from this lab is:

```text
             BGP CONTROL PLANE
                    |
                    | IPv4 NLRI
                    | +
                    | IPv6 next hop
                    v
             MP_REACH_NLRI
                    |
                    v
             BGP route selection
                    |
                    v
             next-hop resolution
                    |
                    v
             IPv6 ND / neighbor cache
                    |
                    v
                 MAC addr
                    |
                    v
             Ethernet forwarding
```

And on failure:

```text
BGP path disappears
        ↓
MP_UNREACH_NLRI
        ↓
alternate BGP path
        ↓
new next hop
        ↓
new neighbor/MAC resolution
        ↓
forwarding continues
```
