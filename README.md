# Networking Labs & Concepts

A hands-on networking study repository built around small, reproducible **Containerlab + Linux** experiments.

The goal is to understand networking from the packet and system level:

```text
concept
  ↓
mental model
  ↓
Linux / Containerlab lab
  ↓
packet capture
  ↓
observations
  ↓
revision notes
```

Each numbered directory represents a **concept area**, not necessarily a calendar day.

---

## Concept Roadmap

| # | Concept | What we'll cover |
|---|---|---|
| 001 | **ARP & L2 Forwarding** | Ethernet frames, MAC addresses, ARP, ARP cache, switch FDB, MAC learning, flooding, unicast forwarding, GARP, ARP probes, duplicate IPs, neighbor/cache states |
| 002 | **IPv6 Neighbor Discovery** | IPv6 addressing/notation, link-local addresses, solicited-node multicast, NS, NA, ND options, NUD, neighbor cache, DAD, Router Solicitation |
| 003 | **IPv6 RA & Routing** | Router Solicitation/Advertisement, prefix information, default routers, SLAAC, IPv6 forwarding, L3 boundaries, routing between IPv6 networks |
| 004 | **VLANs & 802.1Q** | VLANs, broadcast domains, access ports, trunk ports, VLAN tagging, native VLAN, inter-switch links, VLAN isolation |
| 005 | **STP / L2 Loops** | Layer-2 loops, broadcast storms, STP fundamentals, root bridge, port roles/states, convergence, RSTP |
| 006 | **Ethernet & Switching Deep Dive** | Ethernet frame structure, MAC learning, FDB behavior, flooding/unknown unicast, multicast, broadcast, aging, bridge behavior |
| 007 | **IPv4 Routing** | Routing tables, connected/static routes, longest-prefix match, default routes, next hops, ARP vs routing, forwarding decisions |
| 008 | **IPv6 Routing Deep Dive** | IPv6 routing table, next-hop behavior, link-local next hops, forwarding, router behavior, IPv6-specific routing considerations |
| 009 | **ICMP / ICMPv6** | Error messages, control-plane signaling, echo, TTL/hop-limit behavior, PMTUD-related messages, ICMPv6's role in ND |
| 010 | **Routing Protocol Foundations** | Control plane vs data plane, route exchange, convergence, metrics, administrative concepts, protocol state machines |
| 011 | **RIP / RIPng** | Distance-vector routing, hop count, periodic updates, convergence, split horizon, route timers, IPv4/IPv6 differences |
| 012 | **OSPF / OSPFv3** | Link-state routing, LSAs, areas, SPF, neighbors/adjacencies, DR/BDR, costs, route installation |
| 013 | **BGP Fundamentals** | Path-vector model, eBGP/iBGP, ASes, attributes, route selection, advertisements, policy |
| 014 | **Linux Networking Internals** | Network namespaces, veth pairs, bridges, interfaces, routes, neighbor tables, FDBs, sysctl, packet paths |
| 015 | **Linux Packet Processing** | Interface ingress/egress, bridge vs routing decisions, netfilter/nftables concepts, forwarding, queues, packet capture |
| 016 | **Containers & Container Networking** | Container namespaces, veth pairs, bridges, Docker networking, Containerlab wiring, management vs data-plane interfaces |
| 017 | **TCP/IP Fundamentals** | Sockets, ports, TCP state, connection establishment, retransmission, flow/congestion control, UDP |
| 018 | **Systems / Linux Internals** | Processes, memory, filesystems, system calls, scheduling, IPC, namespaces/cgroups, debugging |
| 019 | **Networking Programming** | C networking primitives, sockets, packet structures, Python networking, automation and protocol experimentation |
| 020 | **Data Structures & Problem Solving** | Core data structures, algorithms, complexity, implementation patterns, networking-oriented problem solving |
| 021 | **Network/System Design** | Designing L2/L3 networks, failure domains, redundancy, scaling, control/data plane separation, trade-offs |
| 022 | **Debugging & Packet Analysis** | tcpdump, Wireshark, Linux observability, reproducing failures, tracing packets through the stack |

The ordering is intentionally flexible. Some topics will be pulled forward when they naturally explain something we're already seeing in a lab.

---

# Layer 2

The L2 section builds the foundation for understanding how Ethernet actually moves frames.

Topics include:

- Ethernet frames
- MAC addresses
- Switches and bridges
- FDB/MAC tables
- MAC learning
- Unknown-unicast flooding
- Broadcast and multicast
- ARP
- Gratuitous ARP
- ARP probes
- Duplicate-address detection
- VLANs
- Access ports
- Trunk ports
- 802.1Q tags
- Broadcast domains
- STP and L2 loops

The key mental model:

```text
Ethernet frame
     ↓
destination MAC
     ↓
switch / bridge
     ↓
FDB lookup
     ↓
forward / flood
```

---

# IPv6

IPv6 gets its own progression because several concepts interact:

```text
IPv6 addressing
      ↓
link-local addresses
      ↓
multicast
      ↓
Neighbor Discovery
      ↓
neighbor cache + NUD
      ↓
Router Advertisement
      ↓
SLAAC
      ↓
IPv6 routing
```

We'll repeatedly inspect these mechanisms using actual packet captures.

---

# Layer 3 & Routing

We'll build from the basic forwarding decision toward routing protocols.

Core concepts:

- Subnets
- Prefixes
- Connected routes
- Static routes
- Default routes
- Next hops
- Longest-prefix match
- Routing tables
- Layer-3 boundaries
- Forwarding
- Control plane vs data plane
- Route installation
- Route convergence

Then we'll move into routing protocols:

```text
Distance vector
    ↓
RIP / RIPng

Link state
    ↓
OSPF / OSPFv3

Path vector
    ↓
BGP
```

---

# Linux Networking

Linux is the laboratory underneath many of the experiments.

We'll use it to understand:

- Interfaces
- Network namespaces
- veth pairs
- Linux bridges
- FDBs
- Neighbor tables
- Routing tables
- IPv4/IPv6 sysctls
- Forwarding
- Packet capture
- Network configuration
- Container networking

A recurring theme will be connecting the Linux representation to the protocol behavior:

```text
Linux object
    ↕
kernel networking behavior
    ↕
wire packet
```

---

# Containerlab

Containerlab is the reproducible environment for the labs.

The repository will progressively use it to build:

- Hosts
- Linux bridges
- Routers
- Multi-L2-domain topologies
- VLANs
- Routed links
- Routing-protocol labs
- Packet-capture experiments

Each concept should ideally have:

```text
topology
+
configuration
+
commands
+
packet captures
+
README
```

so it can be rebuilt rather than merely read.

---

# Packet Analysis

Wireshark and tcpdump are part of the learning process rather than an afterthought.

For important protocols we'll follow:

```text
Application / control action
          ↓
kernel decision
          ↓
protocol message
          ↓
Ethernet frame
          ↓
switch / router
          ↓
destination
```

And compare:

```text
what we expected
       vs
what actually appeared on the wire
```

---

# Systems & Programming

The networking work will also connect back to systems fundamentals.

### Linux / systems

- Processes and threads
- Scheduling
- Memory
- Filesystems
- System calls
- IPC
- Namespaces
- cgroups
- Kernel/user-space boundaries
- Debugging

### Programming

- C
- Python
- Sockets
- Network byte order
- Packet/header structures
- Parsing
- Automation
- Small protocol experiments

### Data structures / problem solving

- Arrays and strings
- Linked lists
- Stacks and queues
- Hash tables
- Trees
- Graphs
- Heaps
- Sorting/searching
- Complexity
- Graph problems relevant to networking

---

# Design & Debugging

Eventually the individual protocol concepts should converge into larger engineering skills.

We'll practice:

- Designing networks from requirements
- Choosing L2 vs L3 boundaries
- Failure-domain analysis
- Redundancy
- Scaling
- Control-plane/data-plane separation
- Debugging from symptoms
- Forming hypotheses
- Capturing evidence
- Tracing packets
- Finding where behavior diverges from expectations

---

# Repository Structure

Concept directories are numbered by topic:

```text
.
├── README.md
│
├── 001-arp-fdb/
│   ├── clab.yaml
│   ├── README.md
│   ├── TOPOLOGY.md
│   └── pcaps/
│
├── 002-nd-ipv6/
│   ├── clab.yaml
│   ├── README.md
│   ├── TOPOLOGY.md
│   └── pcaps/
│
├── 003-ra-ipv6-routing/
│   ├── clab.yaml
│   ├── README.md
│   ├── TOPOLOGY.md
│   └── pcaps/
│
└── ...
```

The numbered directories represent **concepts**, not dates.

---

# Learning Pattern

For each important topic, the preferred workflow is:

1. Understand the problem the protocol solves.
2. Build the smallest useful topology.
3. Configure it manually.
4. Observe the Linux state.
5. Generate traffic.
6. Capture packets.
7. Inspect the packet fields.
8. Compare packet behavior with kernel state.
9. Break something deliberately.
10. Debug it.
11. Record the resulting mental model.

The goal is not just to know what a protocol is.

The goal is to be able to answer:

> **"What exactly happens from the moment this packet is generated until it reaches the other side?"**
