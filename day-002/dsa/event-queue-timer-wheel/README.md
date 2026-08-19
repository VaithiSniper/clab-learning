## Event Queue / Timer Wheel

Build a small event scheduler for networking-style events.

Events might be:

```text
BGP keepalive
BGP hold-time expiry
neighbor aging
route refresh
ARP/ND retry
```

### Version 1

Use:

```text
priority_queue<Event>
```

ordered by deadline.

Operations:

```text
schedule(event, deadline)
cancel(event)
run_due_events(now)
```

Target:

- insert: O(log n)
- pop next event: O(log n)

### Version 2

Explore a timer wheel.

The point is to understand why high-performance systems sometimes avoid a heap when they have huge numbers of timers with bounded time ranges.
