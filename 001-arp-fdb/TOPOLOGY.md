# Day 1 --- ARP/FDB Containerlab Topology

This topology was used for the ARP, neighbor-cache, and FDB experiments
on 8 August 2026.

## Topology

``` mermaid
flowchart LR
    h1["h1<br/>10.0.0.1/24"] <-->|eth1| sw1["sw1<br/>Linux bridge br0"]
    sw1 <-->|eth2| h2["h2<br/>10.0.0.2/24"]
```

## Logical view

``` text
                 Linux bridge
                     br0
                   /     \
                eth1     eth2
                 |         |
                h1        h2
          10.0.0.1/24  10.0.0.2/24
```

## Nodes

  Node    Kind                     Interface        IPv4
  ------- ------------------------ ---------------- ---------------
  `h1`    Alpine Linux container   `eth1`           `10.0.0.1/24`
  `sw1`   Alpine Linux container   `eth1` → `br0`   none
  `sw1`   Alpine Linux container   `eth2` → `br0`   none
  `h2`    Alpine Linux container   `eth1`           `10.0.0.2/24`

The switch container was configured with a Linux bridge:

``` text
eth1 ──┐
       ├── br0
eth2 ──┘
```

## Containerlab topology file

``` yaml
name: arp-fdb

topology:
  nodes:
    h1:
      kind: linux
      image: alpine:latest
      exec:
        - ip addr add 10.0.0.1/24 dev eth1
        - ip link set eth1 up

    sw1:
      kind: linux
      image: alpine:latest
      exec:
        - ip link add br0 type bridge
        - ip link set br0 up
        - ip link set eth1 master br0
        - ip link set eth2 master br0

    h2:
      kind: linux
      image: alpine:latest
      exec:
        - ip addr add 10.0.0.2/24 dev eth1
        - ip link set eth1 up

  links:
    - endpoints: ["h1:eth1", "sw1:eth1"]
    - endpoints: ["sw1:eth2", "h2:eth1"]
```

## Deploy

``` bash
sudo containerlab deploy -t arp-fdb.clab.yml
```

## Inspect

``` bash
sudo containerlab inspect -t arp-fdb.clab.yml
```

## Useful commands

### Enter a node

``` bash
docker exec -it clab-arp-fdb-h1 sh
docker exec -it clab-arp-fdb-sw1 sh
docker exec -it clab-arp-fdb-h2 sh
```

### Check neighbor cache

``` bash
ip neigh show
```

### Delete a neighbor entry

``` bash
arp -d 10.0.0.2 dev eth1
```

### Watch neighbor state transitions

``` bash
watch -n 1 ip neigh show
```

### Inspect bridge FDB

On `sw1`:

``` bash
bridge fdb show
```

Filter for the learned host MACs:

``` bash
bridge fdb show | grep -iE "aa:c1:ab:9c:76:df|aa:c1:ab:6e:fe:f4"
```

### Delete dynamic FDB entries

``` bash
bridge fdb del aa:c1:ab:9c:76:df dev eth1 master
bridge fdb del aa:c1:ab:6e:fe:f4 dev eth2 master
```

### Capture ARP

On an endpoint:

``` bash
tcpdump -nni eth1 arp
```

On the bridge:

``` bash
tcpdump -nni br0 arp
```

## Experiments

### Experiment 1 --- Fresh ARP resolution

Delete H1's neighbor entry:

``` bash
arp -d 10.0.0.2 dev eth1
```

Capture on `br0`, then:

``` bash
ping -c 1 10.0.0.2
```

Expected:

``` text
H1 → broadcast
    ARP request: Who has 10.0.0.2?

H2 → H1
    ARP reply: 10.0.0.2 is-at <H2 MAC>

H1 → H2
    ICMP Echo Request

H2 → H1
    ICMP Echo Reply
```

### Experiment 2 --- Neighbor state

Inspect:

``` bash
ip neigh show
```

Useful states observed during the lab:

``` text
INCOMPLETE
REACHABLE
STALE
DELAY
PROBE
FAILED
```

Watch transitions live:

``` bash
watch -n 1 ip neigh show
```

### Experiment 3 --- GARP / unsolicited ARP

Conceptually:

``` text
Ethernet:
  src = local MAC
  dst = ff:ff:ff:ff:ff:ff

ARP:
  sender IP  = local IP
  sender MAC = local MAC
  target IP  = local IP
```

Purpose:

-   announce an IP/MAC association,
-   update peer caches,
-   assist failover/IP movement,
-   cause normal Ethernet source-MAC learning on switches.

### Experiment 4 --- Duplicate-address detection

On a host that intends to use `10.0.0.1`, generate an ARP probe.

Conceptually:

``` text
Ethernet:
  src = probing host MAC
  dst = ff:ff:ff:ff:ff:ff

ARP:
  sender IP  = 0.0.0.0
  sender MAC = probing host MAC
  target IP  = 10.0.0.1
```

If H1 already owns `10.0.0.1`, it can respond:

``` text
10.0.0.1 is at <H1 MAC>
```

The probing host can then detect an address conflict.

## Layer relationships demonstrated

``` text
IPv4 destination
       |
       v
Neighbor cache
       |
       | IP -> MAC
       v
Destination MAC
       |
       v
Linux bridge FDB
       |
       | MAC -> port
       v
eth1 / eth2
```

The lab deliberately exposes the distinction between:

-   **ARP / neighbor cache:** IP → MAC
-   **FDB:** MAC → port
-   **Ethernet:** actual frame delivery
-   **NUD:** neighbor reachability state