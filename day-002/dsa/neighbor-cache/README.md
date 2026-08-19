## Linux Neighbor Table — A Data-Structure Exercise

### Problem

Model a simplified Linux neighbor table.

A neighbor entry maps:

```text
(protocol, interface, neighbor-address) -> link-layer address + state
```

For IPv6, for example:

```text
eth1 + fe80::a8c1:abff:fe24:98e0
    ->
MAC aa:c1:ab:24:98:e0
state STALE
```

Support:

- insert/update a neighbor
- lookup a neighbor
- delete a neighbor
- change neighbor state
- list neighbors by interface
- expire stale entries

### Questions to think through

1. What should be the primary key?
2. Should lookup be O(1), O(log n), or something else?
3. Would a hash table be enough?
4. If we need efficient listing by interface, do we need a second index?
5. How would you avoid keeping duplicate state in two indexes?
6. How would you handle expiration without scanning the entire table?

### Suggested design

Start with:

```text
unordered_map<NeighborKey, NeighborEntry>
```

Then add a second structure only if the requirements justify it.

For expiration, investigate:

```text
min-heap / priority queue
```

where the heap is ordered by expiry time.

This gives a nice systems lesson:

> One data structure can optimize lookup while another optimizes time-based eviction.
