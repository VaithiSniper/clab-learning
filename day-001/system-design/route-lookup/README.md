# System Design — Route Lookup Service

## Problem

Design a small network route lookup service.

The service receives a destination IPv6 address:

```text
lookup("2001:db8:1:2::42")
```

and must return the **best matching route**.

The routing table contains:

```text
2001:db8::/32
2001:db8:1::/48
2001:db8:1:2::/64
```

For the destination:

```text
2001:db8:1:2::42
```

all three prefixes match.

The service must return:

```text
2001:db8:1:2::/64
```

because it is the most specific matching prefix.

## Requirements

### Functional

- Add a route/prefix.
- Remove a route/prefix.
- Look up a destination address.
- Return the longest / most-specific matching prefix.

### Core requirement

Implement **longest-prefix match (LPM)**.

For example:

```text
Destination:
2001:db8:1:2::42

Matches:
2001:db8::/32
2001:db8:1::/48
2001:db8:1:2::/64

Winner:
2001:db8:1:2::/64
```

## Design question

How would you store the routes so that lookups are efficient?

Think about a **prefix tree / trie**.

Conceptually:

```text
root
 │
 └── 2001
      │
      └── db8
           │
           ├── /32 route
           │
           └── 1
                │
                ├── /48 route
                │
                └── 2
                     │
                     └── /64 route
```

During lookup, walk the address bits from most significant to least significant while remembering the deepest node that contains a route.

The deepest matching route is the longest-prefix match.

## Discussion points

Be prepared to discuss:

- Why a normal hash map keyed by the entire destination is insufficient.
- Why prefix length matters.
- How IPv4 and IPv6 differ in address width.
- Lookup complexity in terms of address bits.
- Memory usage of a trie.
- Route insertion and deletion.
- What happens when there is no matching route.
- How this differs from a real router's forwarding information base.

## Interview takeaway

The key concept is:

> Routing is not an exact-key lookup. It is a longest-prefix-match problem.

A trie is a natural data structure because prefixes correspond directly to paths through the address bits.
