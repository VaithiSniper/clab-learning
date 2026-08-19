# System Design — Tiny Event-Driven Routing Dispatcher

**Interview-sized scope.**  
Build a tiny C event dispatcher inspired by the way a routing daemon such as FRR separates I/O from event handling.

The goal is **not** to build BGP, a RIB, or a full routing daemon.

The goal is:

> **Subscribe to events → receive them asynchronously → dispatch callbacks cleanly.**

---

## 1. What we're building

A small C program with:

```text
Linux / test sources
       |
       v
   Event sources
       |
       v
   Event loop
       |
       v
   Dispatcher
       |
       +----> callback A
       +----> callback B
       +----> callback C
```

Example events:

```text
LINK_UP
LINK_DOWN
ROUTE_ADD
ROUTE_DEL
TIMER_EXPIRED
```

For the first version, events can be synthetic. Do **not** start by parsing real netlink.

---

## 2. Core API

Keep the API tiny.

```c
typedef enum {
    EVENT_LINK_UP,
    EVENT_LINK_DOWN,
    EVENT_ROUTE_ADD,
    EVENT_ROUTE_DEL,
    EVENT_TIMER
} event_type_t;

typedef void (*event_cb)(event_type_t type, void *data);

int event_subscribe(event_type_t type, event_cb cb);
int event_publish(event_type_t type, void *data);
void event_loop(void);
```

A subscription means:

```text
EVENT_LINK_DOWN
        |
        +--> link_down_handler()
```

Multiple callbacks may subscribe to the same event.

---

## 3. Dispatcher

Internally, maintain something like:

```text
event_type
    |
    v
list of subscribers
    |
    +--> callback
    +--> callback
    +--> callback
```

A simple data structure is enough:

```c
struct subscriber {
    event_cb cb;
    struct subscriber *next;
};

struct dispatcher {
    struct subscriber *subs[EVENT_MAX];
};
```

This is deliberately simple.

The interesting interview discussion is **why a list is sufficient** and when you would replace it.

---

## 4. Event Loop

Start with a simple loop:

```c
while (running) {
    event = get_next_event();
    dispatch(event);
}
```

Then explain how a real Linux implementation would use:

```text
epoll
  |
  +-- netlink socket
  +-- BGP TCP sockets
  +-- timerfd
```

The important separation is:

```text
I/O readiness
     |
     v
decode input
     |
     v
internal event
     |
     v
dispatcher
     |
     v
callback
```

Callbacks should not need to know about `epoll` or raw socket details.

---

## 5. Netlink — keep it as a future adapter

Do **not** make netlink the core of this exercise.

Later, add:

```text
RTM_NEWLINK  ---> EVENT_LINK_UP
RTM_DELLINK  ---> EVENT_LINK_DOWN
RTM_NEWROUTE ---> EVENT_ROUTE_ADD
RTM_DELROUTE ---> EVENT_ROUTE_DEL
```

So:

```text
Netlink
   |
   v
Netlink adapter
   |
   v
event_publish(...)
   |
   v
dispatcher
```

This keeps Linux-specific parsing separate from generic event handling.

---

## 6. The small C project

Suggested files:

```text
event-dispatcher/
├── Makefile
├── README.md
├── event.h
├── event.c
└── main.c
```

### `event.h`

Public event types and API.

### `event.c`

Dispatcher and subscriber lists.

### `main.c`

Demo:

```text
subscribe
subscribe
publish
dispatch
```

---

## 7. Minimal exercise

Implement this flow:

```text
main()
  |
  +--> subscribe(LINK_DOWN, on_link_down)
  +--> subscribe(ROUTE_ADD, on_route_add)
  |
  +--> publish(LINK_DOWN, ...)
  +--> publish(ROUTE_ADD, ...)
  |
  +--> verify callbacks ran
```

Then add:

1. multiple subscribers for one event
2. unsubscribe
3. event data
4. a simple event queue
5. a loop that drains the queue

Stop there.

---

## 8. Interview discussion points

### Why event-driven?

Avoid:

```text
one thread per socket
one thread per timer
one thread per peer
```

Instead:

```text
one event loop
many event sources
callbacks/state machines
```

This reduces thread-management overhead and makes ownership easier to reason about.

### Why an internal event type?

Because protocol/kernel details should not leak everywhere.

```text
raw input
   |
   v
adapter
   |
   v
generic event
   |
   v
dispatcher
```

### Why a queue?

It decouples producers from consumers.

A burst of events can be queued and processed sequentially.

### What about backpressure?

For this tiny project:

```text
bounded queue
+
drop/coalesce policy
```

is enough to discuss.

You don't need to implement sophisticated backpressure.

---

## 9. Tiny extension: real Linux event source

Once the basic dispatcher works, replace the synthetic producer with:

```text
AF_NETLINK / NETLINK_ROUTE
```

Register the netlink FD with:

```text
epoll
```

When readable:

```text
recv()
  |
  v
parse nlmsg_type
  |
  +--> RTM_NEWLINK
  +--> RTM_DELLINK
  +--> RTM_NEWROUTE
  +--> RTM_DELROUTE
  |
  v
event_publish()
```

That is enough to demonstrate the core routing-daemon pattern.

---

## 10. Mental model

Remember this:

```text
          +----------------+
          | event sources  |
          | netlink/timer  |
          | sockets/tests  |
          +-------+--------+
                  |
                  v
             event loop
                  |
                  v
             dispatcher
                  |
          +-------+-------+
          |       |       |
          v       v       v
        cb A    cb B    cb C
```

**The event loop waits.  
Adapters translate input.  
The dispatcher routes events.  
Callbacks own the actual behavior.**

That's the entire exercise.

---

## Interview one-liner

> "I'd use a single event loop around epoll, translate kernel/protocol input into internal events, and dispatch those events to registered callbacks. This keeps I/O concerns separate from routing state machines and avoids a thread-per-event-source design."
