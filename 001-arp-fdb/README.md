# ARP Lab Notes --- Day 1

> Revision notes from the Containerlab ARP/FDB lab on 8 August 2026.
>
> **Packet snapshots below are reconstructed from the Wireshark packet
> rows and observations captured during the lab. They are not raw packet
> exports.**

------------------------------------------------------------------------

## 1. What ARP is for

**ARP (Address Resolution Protocol)** solves the Layer-2/Layer-3
boundary problem in IPv4.

A host may know the destination **IPv4 address**, but Ethernet
forwarding requires a **destination MAC address**.

For a directly connected destination:

``` text
IPv4 destination
      |
      v
     ARP
      |
      v
Destination MAC
      |
      v
Ethernet frame
      |
      v
Switch / FDB
      |
      v
Egress port
```

ARP therefore provides the mapping:

``` text
IPv4 address -> MAC address
```

The switch's FDB provides a different mapping:

``` text
MAC address -> port
```

Together, for a directly connected host:

``` text
IP -> MAC -> port
```

### Remote destination

If the destination is on another subnet, the host does **not** ARP for
the remote host's MAC.

Instead:

1.  The host performs a routing decision.
2.  It determines that the destination is remote.
3.  It sends the packet to its default gateway / next hop.
4.  It ARPs for the **gateway's MAC**.
5.  The IP destination remains the original remote destination.

So:

``` text
IP destination = remote host
Ethernet destination = local gateway
```

At the router, the Layer-2 header is removed, a routing lookup is
performed, and a new Layer-2 header is constructed for the next hop.

------------------------------------------------------------------------

# 2. Normal ARP resolution

## Problem

Host H1 knows:

``` text
H1:
  IP  = 10.0.0.1
  MAC = aa:c1:ab:ea:89:27

H2:
  IP  = 10.0.0.2
  MAC = aa:c1:ab:bb:e4:22
```

H1 wants to send to `10.0.0.2`, but does not currently have a
neighbor-cache entry for it.

It needs:

``` text
10.0.0.2 -> aa:c1:ab:bb:e4:22
```

## ARP Request

The request is broadcast because H1 does not yet know H2's MAC.

### Wireshark snapshot from the lab

``` text
aa:c1:ab:ea:89:27 -> ff:ff:ff:ff:ff:ff
ARP
Who has 10.0.0.2? Tell 10.0.0.1
```

### Header-level interpretation

``` text
Ethernet:
  src MAC = aa:c1:ab:ea:89:27       # H1
  dst MAC = ff:ff:ff:ff:ff:ff       # broadcast

ARP:
  sender IP  = 10.0.0.1
  sender MAC = aa:c1:ab:ea:89:27
  target IP  = 10.0.0.2
  target MAC = 00:00:00:00:00:00    # unknown
```

The zero target MAC in the ARP header is expected: **that is the value
being discovered**.

The Ethernet frame itself must use broadcast because the destination MAC
is not known.

## ARP Reply

H2 knows its own IP and MAC, and it also learned H1's source information
from the request.

### Wireshark snapshot from the lab

``` text
aa:c1:ab:bb:e4:22 -> aa:c1:ab:ea:89:27
ARP
10.0.0.2 is at aa:c1:ab:bb:e4:22
```

This reply can be unicast because H2 now knows H1's MAC.

### Header-level interpretation

``` text
Ethernet:
  src MAC = aa:c1:ab:bb:e4:22
  dst MAC = aa:c1:ab:ea:89:27

ARP:
  sender IP  = 10.0.0.2
  sender MAC = aa:c1:ab:bb:e4:22
  target IP  = 10.0.0.1
  target MAC = aa:c1:ab:ea:89:27
```

------------------------------------------------------------------------

# 3. What the switch learns during ARP

The switch/Linux bridge learns from the **source MAC of received
Ethernet frames**.

When H1's ARP request arrives:

``` text
source MAC = H1 MAC
ingress    = eth1
```

the bridge can learn:

``` text
H1 MAC -> eth1
```

When H2's reply arrives:

``` text
source MAC = H2 MAC
ingress    = eth2
```

the bridge can learn:

``` text
H2 MAC -> eth2
```

Important:

> **FDB learning is independent of ARP.**

ARP traffic can cause FDB learning, but the switch does not need to
understand ARP to learn the source MAC. Any Ethernet frame can teach the
bridge where a source MAC currently appears.

------------------------------------------------------------------------

# 4. Neighbor cache vs FDB

These two tables should not be confused.

### Host neighbor cache

``` text
IP address -> MAC + neighbor state
```

Example:

``` text
10.0.0.2 -> aa:c1:ab:bb:e4:22
```

### Switch FDB

``` text
MAC address -> bridge port
```

Example:

``` text
aa:c1:ab:bb:e4:22 -> eth2
```

Combined:

``` text
10.0.0.2
    |
    | neighbor cache
    v
aa:c1:ab:bb:e4:22
    |
    | FDB
    v
eth2
```

This is the path from an IPv4 destination to a Layer-2 egress port.

------------------------------------------------------------------------

# 5. Neighbor cache states / NUD

Linux's neighbor table is not just a permanent `IP -> MAC` dictionary.

It also tracks **Neighbor Unreachability Detection (NUD)** state.

Important states:

  -----------------------------------------------------------------------
  State                               Meaning
  ----------------------------------- -----------------------------------
  `INCOMPLETE`                        Resolution is in progress; no
                                      usable MAC is known yet.

  `REACHABLE`                         Reachability has recently been
                                      confirmed.

  `STALE`                             A usable mapping exists, but
                                      reachability has not recently been
                                      confirmed.

  `DELAY`                             Traffic needs the neighbor, but
                                      Linux briefly waits for normal
                                      traffic to provide reachability
                                      confirmation before actively
                                      probing.

  `PROBE`                             Linux is actively probing the
                                      neighbor.

  `FAILED`                            Neighbor resolution/reachability
                                      failed.

  `NOARP`                             Neighbor does not require ARP/ND
                                      resolution.

  `PERMANENT`                         Static/permanent neighbor entry.
  -----------------------------------------------------------------------

### Important distinction

`STALE` does **not** mean:

> "The MAC is known to be wrong."

It means:

> "I have a mapping, but I haven't recently confirmed that the neighbor
> is reachable."

During the lab, a stale entry changed to `DELAY` when traffic was sent
to the neighbor. This demonstrated that Linux's neighbor state machine
is actively managing reachability rather than simply storing a MAC
forever.

------------------------------------------------------------------------

# 6. Fresh resolution vs existing stale entry

We observed two qualitatively different behaviors.

## Cold / missing entry

If H1 has no neighbor entry for H2:

``` text
No entry
   |
   v
ARP request
   |
   v
ARP reply
   |
   v
IP -> MAC learned
```

The request is broadcast.

## Existing stale entry

If H1 already has:

``` text
10.0.0.2 -> H2 MAC
```

but the entry is `STALE`, Linux can still use the known MAC.

It does not need to perform a fresh broadcast lookup merely to obtain a
MAC it already has.

The neighbor state machine can then perform reachability confirmation /
probing as appropriate.

During the lab, a packet capture showed an ARP exchange associated with
this behavior. The key lesson is:

> **A stale neighbor entry is still a usable mapping; stale means
> reachability needs confirmation, not that the MAC has been
> discarded.**

------------------------------------------------------------------------

# 7. Gratuitous ARP (GARP)

GARP is an **unsolicited ARP announcement**.

The purpose is not necessarily to answer an ARP question. A host can
proactively announce:

> "This IP is associated with this MAC."

A common conceptual GARP is:

``` text
Ethernet:
  src MAC = my MAC
  dst MAC = ff:ff:ff:ff:ff:ff

ARP:
  sender IP  = my IP
  sender MAC = my MAC
  target IP  = my IP
```

This can be useful for:

-   updating peers' ARP caches,
-   IP/MAC failover,
-   rapid convergence after an IP moves,
-   announcing ownership of an address.

### GARP and FDB learning

A GARP can also indirectly help a switch update its FDB because the
switch sees an Ethernet frame whose **source MAC** arrived on a
particular port.

However:

> GARP is not a special "update the FDB" protocol.

The switch does not need to understand the ARP payload. It learns the
source MAC from the Ethernet frame.

------------------------------------------------------------------------

# 8. Duplicate-address detection with an ARP probe

This is different from GARP.

The question is:

> "I want to use this IP. Is somebody already using it?"

During the lab, H2 probed for `10.0.0.1`, which was already owned by H1.

### ARP probe observed in Wireshark

``` text
aa:c1:ab:bb:e4:22 -> Broadcast
ARP
Who has 10.0.0.1? (ARP Probe)
```

The important header detail was:

``` text
Ethernet:
  src MAC = aa:c1:ab:bb:e4:22
  dst MAC = ff:ff:ff:ff:ff:ff

ARP:
  sender IP  = 0.0.0.0
  sender MAC = aa:c1:ab:bb:e4:22
  target IP  = 10.0.0.1
  target MAC = 00:00:00:00:00:00
```

### Why `0.0.0.0`?

Because H2 is **not yet claiming ownership** of `10.0.0.1`.

It is asking whether someone else already owns it.

That gives us a very useful distinction:

``` text
Normal ARP:
  "I need the MAC for this IP."

ARP probe:
  "Is somebody already using this IP?"

GARP:
  "I am using this IP -> this MAC."
```

### Conflict response observed

H1 responded:

``` text
aa:c1:ab:ea:89:27 -> aa:c1:ab:bb:e4:22
ARP
10.0.0.1 is at aa:c1:ab:ea:89:27
```

H2 can therefore detect:

``` text
10.0.0.1 is already in use.
```

------------------------------------------------------------------------

# 9. One subtle lab lesson: `ip addr add` did not probe

We attempted:

``` bash
ip addr add 10.0.0.1/24 dev eth1
```

on H2 while H1 already owned the address.

Alpine allowed the address to be added as a secondary address:

``` text
inet 10.0.0.1/24 scope global secondary eth1
```

and no ARP probe was observed on `br0`.

Therefore:

> **Do not assume that `ip addr add` on every Linux/container image
> automatically performs duplicate-address probing.**

For the controlled DAD experiment, we explicitly generated an ARP probe
and observed the expected wire behavior.

This is a useful systems lesson: protocol behavior can depend on the
specific kernel/userspace/network-stack configuration, so packet capture
beats assumptions.

------------------------------------------------------------------------

# 10. Lab commands used

### Neighbor table

``` bash
ip neigh show
```

### Delete a neighbor entry

``` bash
ip neigh del 10.0.0.2 dev eth1
```

### Watch neighbor state changes

``` bash
ip monitor neigh
```

### Inspect Linux bridge FDB

``` bash
bridge fdb show
```

### Delete a learned bridge entry

``` bash
bridge fdb del <MAC> dev <PORT> master
```

### Capture ARP

``` bash
tcpdump -nni eth1 arp
```

or on the bridge:

``` bash
tcpdump -nni br0 arp
```

------------------------------------------------------------------------

# 11. Core mental model

Keep this picture:

``` text
                 Host
                   |
          +--------+--------+
          |                 |
     Neighbor cache        Ethernet
       IP -> MAC             |
          |                  v
          |               Switch
          |                  |
          |                FDB
          |              MAC -> port
          |                  |
          +------------------+
```

Or, for a packet:

``` text
Destination IP
      |
      | route lookup
      v
Next-hop IP
      |
      | ARP
      v
Next-hop MAC
      |
      | FDB
      v
Egress port
```

------------------------------------------------------------------------

# 12. Interview-ready summary

If asked **"What is ARP?"**:

> ARP resolves an IPv4 next-hop address to a MAC address so an IP packet
> can be carried in an Ethernet frame. For a directly connected
> destination, the destination IP is resolved directly. For a remote
> destination, the host resolves the MAC of its local next hop,
> typically the default gateway.

If asked **"Why is the ARP request broadcast?"**:

> Because the sender knows the target IP but doesn't yet know the target
> MAC, so it cannot address the Ethernet frame to a specific destination
> MAC.

If asked **"Why is the ARP reply usually unicast?"**:

> The target learned the requester's MAC from the request, so it can
> address the reply directly.

If asked **"What's the difference between ARP and FDB?"**:

> ARP/neighbor discovery maps IP to MAC at the host. The FDB maps MAC to
> a switch/bridge port. Together they allow an IP destination to be
> translated into an Ethernet forwarding decision.

If asked **"What's GARP for?"**:

> It's an unsolicited ARP announcement used to inform peers of an
> IP-to-MAC association, commonly useful for cache updates and
> failover/IP movement. The switch can also relearn the source MAC from
> the Ethernet frame.

If asked **"What's an ARP probe?"**:

> It's a duplicate-address detection mechanism. A host probes an address
> it intends to use, typically using `0.0.0.0` as the sender IP, to
> determine whether another host is already using the target address.
