# Lab 01 — BGP Unicast + iBGP Route Reflector + eBGP

This lab covers:

- eBGP between PE/CE routers
- iBGP inside AS 65000
- iBGP route reflection
- BGP route advertisement and withdrawal
- BGP best-path selection
- BGP next-hop behavior
- BGP table vs RIB vs forwarding lookup
- Basic BGP convergence and failure observation

## Topology

```text
                         AS 65000
                            RR1
                         10.0.0.1
                        /        \
                     iBGP        iBGP
                      /            \
                    PE1            PE2
                10.0.0.11      10.0.0.22
                    |                |
                  eBGP             eBGP
                    |                |
                   CE1              CE2
                AS 65100          AS 65200
```

## Addressing

### Loopbacks

```text
RR1  10.0.0.1/32
PE1  10.0.0.11/32
PE2  10.0.0.22/32
CE1  10.1.1.1/32
CE2  10.2.2.2/32
```

### Physical links

```text
RR1 <-> PE1

RR1  10.0.1.0/31
PE1  10.0.1.1/31
```

```text
RR1 <-> PE2

RR1  10.0.1.2/31
PE2  10.0.1.3/31
```

```text
PE1 <-> CE1

PE1  10.0.10.0/31
CE1  10.0.10.1/31
```

```text
PE2 <-> CE2

PE2  10.0.20.0/31
CE2  10.0.20.1/31
```

## AS numbers

```text
RR1 = AS 65000
PE1 = AS 65000
PE2 = AS 65000

CE1 = AS 65100
CE2 = AS 65200
```

Therefore:

```text
RR1 <-> PE1 = iBGP
RR1 <-> PE2 = iBGP

PE1 <-> CE1 = eBGP
PE2 <-> CE2 = eBGP
```

## Deploy

The interface addressing and underlay routes are embedded directly in the Containerlab topology using node `exec` commands.

So deployment is simply:

```bash
sudo containerlab deploy -t bgp-unicast-rr.clab.yml
```

There are no post-deployment interface setup scripts.

Check the containers:

```bash
docker ps --format '{{.Names}}'
```

## Initial verification

Check BGP sessions:

```bash
docker exec -it clab-bgp-unicast-rr-rr1   vtysh -c 'show bgp summary'

docker exec -it clab-bgp-unicast-rr-pe1   vtysh -c 'show bgp summary'

docker exec -it clab-bgp-unicast-rr-pe2   vtysh -c 'show bgp summary'

docker exec -it clab-bgp-unicast-rr-ce1   vtysh -c 'show bgp summary'

docker exec -it clab-bgp-unicast-rr-ce2   vtysh -c 'show bgp summary'
```

We expect four BGP sessions:

```text
CE1 <-> PE1       eBGP
PE1 <-> RR1       iBGP
PE2 <-> RR1       iBGP
PE2 <-> CE2       eBGP
```

## Route advertisement

CE1 originates:

```text
10.1.1.1/32
```

Trace it through:

```text
CE1
  |
  | eBGP
  v
PE1
  |
  | iBGP
  v
RR1
  |
  | iBGP reflection
  v
PE2
```

CE2 originates:

```text
10.2.2.2/32
```

Trace the reverse direction:

```text
CE2
  |
  v
PE2
  |
  v
RR1
  |
  v
PE1
```

Inspect a specific route:

```bash
vtysh -c 'show bgp ipv4 unicast 10.1.1.1/32'
```

and:

```bash
vtysh -c 'show bgp ipv4 unicast 10.2.2.2/32'
```

## Observe the route at each layer

For a prefix such as `10.1.1.1/32`, compare:

### BGP table

```bash
vtysh -c 'show bgp ipv4 unicast 10.1.1.1/32'
```

Questions to answer:

```text
Who is the BGP peer?
What is the NEXT_HOP?
What is the AS_PATH?
Is the path selected as best?
```

### RIB

```bash
vtysh -c 'show ip route 10.1.1.1/32'
```

### Linux forwarding lookup

```bash
ip route get 10.1.1.1
```

### Neighbor resolution

```bash
ip neigh
```

### BGP TCP session

```bash
ss -tnp
```

BGP uses:

```text
TCP/179
```

### Capture BGP traffic

```bash
tcpdump -ni any tcp port 179
```

## Failure exercise 1 — withdraw the route

Remove CE1's advertisement for:

```text
10.1.1.1/32
```

Then observe:

```text
CE1
 ↓
withdrawal
 ↓
PE1
 ↓
RR1
 ↓
PE2
```

Compare:

```text
BGP table
RIB
forwarding lookup
```

before and after the withdrawal.

## Failure exercise 2 — break PE1/RR1

Bring down the PE1-RR1 link:

```bash
ip link set eth1 down
```

Observe:

```text
physical link
    ↓
TCP/179
    ↓
BGP session
    ↓
BGP routes
    ↓
RIB
    ↓
FIB
```

Pay attention to which routes disappear and which routes remain.

## Failure exercise 3 — inspect next-hop resolution

For a route learned through BGP:

```bash
vtysh -c 'show bgp ipv4 unicast <prefix>'
```

Find:

```text
NEXT_HOP
```

Then ask:

```text
Can the router reach that next hop?

Which route resolves it?

Which interface does the packet ultimately leave through?
```

This connects the BGP control plane to the recursive next-hop resolution we covered earlier.

## Failure exercise 4 — competing BGP paths

Later, add a second path to the same prefix.

Then manipulate:

```text
LOCAL_PREF
AS_PATH
MED
```

and observe which path becomes the BGP best path.

The goal is to distinguish:

```text
BGP best-path selection
        ↓
RIB selection
        ↓
FIB installation
        ↓
packet forwarding
```

## Important RR observation

RR1 is a control-plane route reflector.

If RR1 reflects:

```text
10.1.1.1/32
```

from PE1 to PE2, that does **not** mean traffic to `10.1.1.1/32` must physically traverse RR1.

Route distribution and packet forwarding are separate concerns.

## Useful commands

```bash
vtysh -c 'show bgp summary'
vtysh -c 'show bgp ipv4 unicast'
vtysh -c 'show bgp ipv4 unicast <prefix>'
vtysh -c 'show bgp neighbors'
vtysh -c 'show ip route'
vtysh -c 'show ip route <prefix>'

ip -br addr
ip -br link
ip route
ip route get <destination>
ip neigh
ss -tnp

tcpdump -ni any tcp port 179
```

## Lab progression

This is the base BGP unicast lab.

After this we will extend the BGP work into:

```text
01  BGP unicast + iBGP RR + eBGP       <- this lab
02  BGP unnumbered
03  BGP labeled-unicast + MPLS
04  BGP VPNv4/VPNv6
05  EVPN/VXLAN
```

The later labs will replace parts of this simple underlay with the mechanisms used in more realistic service-provider/data-center designs.
