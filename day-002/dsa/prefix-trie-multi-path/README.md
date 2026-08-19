## Prefix Trie — Extension of Route Lookup

You already have a route manager based on LPM.

Do not redo the basic implementation.

Instead, extend it with:

### Multiple routes per prefix

```text
10.0.0.0/24
    |
    +-- path A
    +-- path B
    +-- path C
```

Then separate:

```text
prefix lookup
```

from:

```text
best-path selection
```

This mirrors the architecture of real routing software.

The trie answers:

> Which prefix matches this destination?

The path-selection layer answers:

> Which candidate route should we use?

