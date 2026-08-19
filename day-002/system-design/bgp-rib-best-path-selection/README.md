# BGP Best-Path Selector — FRR-Focused Interview Exercise

## Goal

Study **how FRRouting actually structures best-path selection**, then implement a tiny version of the same idea.

Scope ONLY:

- compare two candidate paths
- apply the decision criteria in a strict order
- return which path wins
- keep the implementation easy to extend and test

Do **not** build a RIB, BGP protocol engine, event loop, policy engine, or route advertisement system.

---

# How FRR Does It

FRR's main comparison function is:

```c
bgp_path_info_cmp(...)
```

in:

```text
bgpd/bgp_route.c
```

The important architectural point is:

> FRR does NOT use a generic dispatch table of function pointers for every best-path criterion.

Instead, it uses a **single ordered comparison function**, with clearly separated blocks for each criterion.

The code is essentially:

```text
compare(new, existing):

    special validity / feature checks

    criterion 1
        if decisive -> return

    criterion 2
        if decisive -> return

    criterion 3
        if decisive -> return

    ...

    final tie breakers

    return winner
```

That is a very reasonable design for BGP because **the ordering itself is part of the protocol's semantics**.

The ordering is therefore visible directly in the source rather than hidden in a table.

FRR also factors complicated pieces into helper functions when useful—for example, administrative-distance comparison and attribute-specific calculations.

Source: `bgp_path_info_cmp()` starts in `bgpd/bgp_route.c`; the function explicitly labels its decision stages with comments such as Weight, Local Preference, AS path, Origin, MED, Peer type, IGP metric, Router-ID, Cluster length, and Neighbor address. citeturn6view0turn4view0turn5view0

---

# The Key Design Pattern

For our small implementation, use:

```c
int compare_paths(const struct bgp_path *new,
                  const struct bgp_path *exist)
{
    if (new->local_pref != exist->local_pref)
        return new->local_pref > exist->local_pref;

    if (new->as_path_len != exist->as_path_len)
        return new->as_path_len < exist->as_path_len;

    if (new->origin != exist->origin)
        return new->origin < exist->origin;

    if (new->med != exist->med)
        return new->med < exist->med;

    if (new->router_id != exist->router_id)
        return new->router_id < exist->router_id;

    return 0;
}
```

The exact attributes can be kept tiny for the exercise.

The important part is the **shape**:

```text
ordered criteria
      ↓
compare
      ↓
if decisive → return
      ↓
otherwise continue
```

This is essentially the FRR approach.

---

# Why This Is Better Than a Generic Dispatch Table Here

A dispatch table sounds elegant:

```c
rules[] = {
    compare_local_pref,
    compare_as_path,
    compare_origin,
    ...
};
```

But for BGP, the decision process is not merely:

> "run a bunch of independent comparisons."

There are many conditional interactions.

FRR has examples where later comparisons depend on configuration or path properties.

For example:

- MED comparison is conditional.
- eBGP vs iBGP handling can interact with multipath-relax behavior.
- IGP metric and peer-type results can be combined.
- imported paths can require selecting which path's attributes are used.
- VPN/EVPN address families can insert additional logic.
- feature flags alter the decision process.

FRR therefore keeps the **decision procedure explicit**, while factoring reusable calculations into helpers.

That is the useful interview lesson.

---

# FRR's Real Structure

Think of it as:

```text
                  bgp_path_info_cmp()
                         |
        +----------------+----------------+
        |                |                |
     validation       decision          helpers
                        order
                         |
          +--------------+--------------+
          |
          +-- weight
          +-- local preference
          +-- local route handling
          +-- AIGP (when enabled)
          +-- AS_PATH
          +-- ORIGIN
          +-- MED
          +-- peer type
          +-- IGP metric
          +-- cluster length
          +-- multipath handling
          +-- oldest external path
          +-- router ID
          +-- cluster length
          +-- neighbor address
          +-- final tie
```

This is **not literally the complete FRR algorithm**—it is the mental model for the architecture.

The real implementation also contains AFI/SAFI-specific and feature-specific branches.

---

# A Very Important FRR Detail

FRR records **why** a path won.

The comparator takes:

```c
enum bgp_path_selection_reason *reason
```

and assigns values such as:

```text
bgp_path_selection_local_pref
bgp_path_selection_as_path
bgp_path_selection_origin
bgp_path_selection_med
bgp_path_selection_peer
bgp_path_selection_igp_metric
bgp_path_selection_router_id
...
```

That is a nice design detail for observability/debugging:

```text
path A won
reason = LOCAL_PREF
```

instead of merely:

```text
path A won
```

Source: the FRR comparator sets `*reason` at each decisive comparison. citeturn4view0turn4view1turn5view0

---

# Another Important Detail: Best-Path Selection Is Not Just One Sort

FRR's path information is stored per destination, and paths are processed as candidates for that destination.

When a path is added, FRR marks it unsorted and schedules processing rather than trying to make the entire RIB a permanently sorted structure. citeturn6view0

The conceptual flow is:

```text
receive / create path
        ↓
store candidate path
        ↓
schedule processing
        ↓
compare candidates
        ↓
mark selected best path
        ↓
react to change
```

For this interview exercise, ignore everything except the comparison step.

---

# Tiny Exercise

Implement:

```c
struct bgp_path {
    int local_pref;
    int as_path_len;
    int origin;
    int med;
    int router_id;
};
```

Then:

```c
int compare_paths(const struct bgp_path *new,
                  const struct bgp_path *exist);
```

Return:

```text
1 → new wins
0 → existing wins
```

Implement only:

1. LOCAL_PREF — higher wins
2. AS_PATH length — shorter wins
3. ORIGIN — lower wins
4. MED — lower wins
5. Router ID — lower wins

Stop there.

---

# What To Say In An Interview

If asked:

**"How would you design a scalable BGP best-path selector?"**

A strong answer:

> "I would keep the decision ordering explicit, similar to FRR's `bgp_path_info_cmp()`, rather than hiding the protocol semantics behind a generic dispatch table. Each criterion is a clearly isolated comparison block, and complicated comparisons can be factored into helpers. The comparator returns immediately when a criterion is decisive, and it can also return a selection-reason enum for observability."

Then add:

> "The important thing is separating the ordered decision policy from the surrounding RIB processing. I would not over-engineer this into a heap or sorting framework because BGP's comparison order is small, deterministic, and has conditional feature-specific behavior."

That is the design discussion this exercise is targeting.

---

# FRR Source To Read

Main implementation:

urlFRR `bgpd/bgp_route.c` — `bgp_path_info_cmp()`https://github.com/FRRouting/frr/blob/master/bgpd/bgp_route.c

Path data structures and selection-related definitions:

urlFRR `bgpd/bgp_route.h`https://github.com/FRRouting/frr/blob/master/bgpd/bgp_route.h

Useful source landmarks in the current FRR implementation:

```text
bgp_path_info_cmp()
    ↓
special path / feature checks
    ↓
admin distance
    ↓
weight
    ↓
local preference
    ↓
local route
    ↓
AIGP
    ↓
AS_PATH
    ↓
ORIGIN
    ↓
MED
    ↓
peer type
    ↓
IGP metric
    ↓
cluster / multipath handling
    ↓
oldest external path
    ↓
router ID
    ↓
cluster length
    ↓
neighbor address
    ↓
final tie
```

The exact production implementation is more nuanced than this simplified list, so use the source itself when discussing FRR-specific behavior. citeturn6view0turn4view1turn5view0
