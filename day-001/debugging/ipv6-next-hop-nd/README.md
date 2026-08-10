# Debugging Problem — IPv6 Next-Hop ND Failure

## Scenario

You have:

```text
H1 ─── R1 ─── R2 ─── H2
```

R1 has the following route:

```text
2001:db8:2::/64 via 2001:db8:12::2 dev rtr
```

H1 sends a ping toward H2.

On R1:

```bash
ip -6 neigh
```

shows:

```text
2001:db8:12::2 dev rtr FAILED
```

But on R2:

```bash
ip -br a
```

shows:

```text
rtr  UP  2001:db8:12::2/64
```

Assume both interfaces show `UP`.

## Question

Why can R1 still show `FAILED` even though R2 has the configured IPv6 address?

What three commands would you run next to prove exactly where the problem is?

---

## My response

My initial hypotheses were:

1. R1 doesn't actually have `rtr` in the `2001:db8:12::/64` subnet.
2. R1 is not sending a Neighbor Solicitation.

My proposed checks were:

1. Use `tcpdump` to see whether an NS is going out.
2. Run `ip -br a` on R1 to verify that R1 is actually on that subnet on `rtr`.
3. Check the FRR configuration for the IP assignment and whether ND is enabled on the interface.
4. Check whether IPv6 forwarding is enabled.

## Feedback / refinement

The first two instincts were the strongest.

The important clue is:

```text
2001:db8:12::2 dev rtr FAILED
```

This tells us that R1 has already selected `2001:db8:12::2` as its next hop. The immediate problem is therefore likely in **Neighbor Discovery / next-hop resolution**, rather than the initial route lookup.

A tighter troubleshooting sequence is:

```text
1. Is an NS leaving R1?
2. Is R1 actually on 2001:db8:12::/64?
3. Is R2 actually on 2001:db8:12::/64 on the R1–R2 link?
4. Does the NS arrive at R2?
5. Does R2 send an NA?
```

Useful commands:

```bash
tcpdump -nni rtr icmp6
ip -6 addr show dev rtr
ip -6 neigh
```

On R2:

```bash
tcpdump -nni rtr icmp6
ip -6 addr show dev rtr
```

### Important correction

Checking whether IPv6 forwarding is enabled is **not relevant to R1 resolving its immediate next hop**.

Likewise, FRR does not need a special ND configuration merely for the Linux kernel to answer Neighbor Solicitations for an address assigned to its interface.

The strongest debugging approach is to follow the packet/state transition:

```text
routing lookup
      ↓
next-hop selection
      ↓
ND / NS
      ↓
NA
      ↓
neighbor cache
      ↓
L2 forwarding
```

## Interview takeaway

An address existing somewhere on a router is not sufficient.

For R1 to resolve `2001:db8:12::2`, that address must be reachable on the **local L2 segment attached to R1's `rtr` interface**.

ND is link-local; it does not cross routers.
