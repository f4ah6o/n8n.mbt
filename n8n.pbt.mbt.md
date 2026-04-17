<!-- aletheia:begin -->
# Property-Based Test Targets for n8n

> MoonBit PBT documentation (Aletheia-style)

## Overview

- **Source**: `n8n`
- **Generated**: 2026-04-18
- **Patterns Detected**: 6 (Round-Trip, Idempotent, Invariant, Identity, Trichotomy, Producer-Consumer)

## Round-Trip Targets

- `Item::set` / `Item::get` - key/value round trip
- `If`-split then `Merge(Append)` - multiset recovery of partitioned items
- `Switch` fan-out then `Merge(Append)` - multiset recovery across ports

## Idempotent Targets

- `NoOp` - applying twice yields the same output

## Invariant Targets

- `If` partition - `true_count + false_count == input_count`
- `If` partition - concatenation is multiset-equal to input
- `Switch` partition - concatenation across all ports is multiset-equal to input
- `Set` - output length equals input length
- `Set` - every output item contains the assigned field
- `Merge(Append)` - output length equals sum of inputs
- `Merge(MergeByPosition)` - output length equals max of inputs

## Identity Targets

- `Item::merge` with `Item::empty()` - left and right identity
- `Merge(Append)` with empty left/right input - identity for the non-empty side
- `Merge(KeepInput0)` - projects to input0
- `Merge(KeepInput1)` - projects to input1

## Trichotomy / Comparison Targets

- `json_compare` reflexivity - `x == x`, `x >= x`, `x <= x` all true; `x > x`, `x < x` both false
- `json_compare` antisymmetry - `a > b` implies `not(b > a)`
- `json_compare` trichotomy - exactly one of `<`, `==`, `>` for numeric pairs
- Non-numeric ordering - string ordering routes to false branch (incomparable)

## Producer-Consumer (Workflow) Targets

- `Start -> NoOp*n` chain preserves the single empty item regardless of depth
- Diamond DAG (`Start -> Set(a) / Start -> Set(b)` into `Merge(Append) -> NoOp`) yields both fields
- `Start -> Set -> If(Exists) -> t/f` fan-out routes correctly based on field presence
- `Code -> If -> Merge(Append)` reunites split items into the original multiset
- Multiple `Start` nodes all contribute items to a downstream `Merge(Append)`
- Input index ordering: items from input 0 precede items from input 1 for non-Merge consumers
- `Workflow::topo_sort` returns all nodes in a linear chain

## Notes

- Tests are implemented in `src/pbt_test.mbt` using `moonbitlang/quickcheck` generators.
- Generators live alongside the properties: `gen_json`, `gen_key`, `gen_item`, `gen_items`, `gen_item_pair`, `gen_item_with_key`, `gen_unique_pair_array`.
- Multiset equality is checked via `items_multiset_eq`, comparing `Item::to_json().stringify()` keys.
- `max_success` is 200 for scalar item properties and 100 for workflow-level properties.
<!-- aletheia:end -->

---

# Property-Based Tests for n8n

This document catalogues the property-based tests that verify algebraic and
operational invariants of the n8n workflow engine. All tests live in
[`src/pbt_test.mbt`](src/pbt_test.mbt) and use `moonbitlang/quickcheck`.

## Test Coverage

### Item (`src/item.mbt`)

| Test | Property |
|------|----------|
| `pbt/item: set-get round trip` | Round-Trip: `item.set(k, v).get(k) == Some(v)` |
| `pbt/item: merge with empty (right identity)` | Identity: `item.merge(empty) == item` |
| `pbt/item: merge with empty (left identity)` | Identity: `empty.merge(item) == item` |
| `pbt/item: of creates single-field item` | Construction: `Item::of(k, v).get(k) == Some(v)` |

### Node execution (`src/node.mbt`, `src/execution.mbt`)

| Test | Property |
|------|----------|
| `pbt/noop: identity` | Invariant: `NoOp` passes items through unchanged |
| `pbt/noop: idempotent` | Idempotent: `NoOp(NoOp(xs)) == NoOp(xs)` |
| `pbt/if: partition preserves count` | Invariant: `true + false == input` |
| `pbt/if: multiset partition integrity` | Round-Trip: `true ++ false` is multiset-equal to input |
| `pbt/if: correct branch placement for Exists` | Semantic: items with field go true, without go false |
| `pbt/set: preserves item count` | Invariant: `Set` preserves cardinality |
| `pbt/set: all outputs contain assigned field` | Invariant: every output carries the assigned key/value |
| `pbt/merge/append: output length is sum of inputs` | Invariant: `|a ++ b| == |a| + |b|` |
| `pbt/merge/keep_input0: output is input0` | Projection: `KeepInput0(a, b) == a` |
| `pbt/merge/keep_input1: output is input1` | Projection: `KeepInput1(a, b) == b` |
| `pbt/merge/by_position: output length is max of inputs` | Invariant: `|by_position(a, b)| == max(|a|, |b|)` |
| `pbt/merge/append: empty left identity` | Identity: `Append([], xs) == xs` |
| `pbt/merge/append: empty right identity` | Identity: `Append(xs, []) == xs` |
| `pbt/switch: multiset partition integrity` | Round-Trip: concatenating all ports recovers the input |

### Comparison (`src/node.mbt::json_compare`)

| Test | Property |
|------|----------|
| `pbt/json_compare: reflexivity (all comparison ops)` | Reflexivity: `x == x`, `x >= x`, `x <= x`; `x > x`, `x < x` false |
| `pbt/json_compare: antisymmetry (a > b implies !(b > a))` | Antisymmetry of `>` |
| `pbt/json_compare: trichotomy for numbers` | Trichotomy: exactly one of `<`, `==`, `>` |
| `pbt/json_compare: non-numeric comparison is false` | Boundary: string ordering routes to false branch |

### Workflow execution (`src/workflow.mbt`, `src/engine.mbt`)

| Test | Property |
|------|----------|
| `pbt/workflow: start-noop chain preserves single empty item` | Producer-Consumer: chain depth does not alter the single empty item |
| `pbt/workflow: diamond DAG with merge` | Producer-Consumer: fan-out + merge preserves both branch fields |
| `pbt/workflow: fan-out via If branching` | Routing: `Set` guarantees field, item takes true branch |
| `pbt/workflow: if-split then merge-append recovers all items` | Round-Trip: If-split + Merge(Append) recovers the multiset |
| `pbt/workflow: multiple start nodes merge` | Producer-Consumer: `n` start nodes produce `n` items at merge |
| `pbt/workflow: input index ordering for non-Merge nodes` | Invariant: input 0 precedes input 1 for flattened consumers |
| `pbt/workflow: switch fan-out then merge recovers items` | Round-Trip: Switch + Merge(Append) recovers the multiset |
| `pbt/workflow: topo_sort returns all nodes` | Invariant: `topo_sort` is total over DAG nodes |

## Generators

Shared quickcheck generators used by the properties above:

| Generator | Produces |
|-----------|----------|
| `gen_json` | Random `Json` (number, string, bool, null) |
| `gen_key` | Alphanumeric field keys with low collision |
| `gen_item` | `Item` with 0-5 unique-keyed fields |
| `gen_item_with_key` | `Item` guaranteed to contain a given key |
| `gen_items` | Non-empty `Array[Item]` of length 1-10 |
| `gen_item_pair` | `(Array[Item], Array[Item])` for merge testing |
| `gen_unique_pair_array` | `Array[(String, Json)]` with unique keys |

## Running Tests

```bash
moon test
```

Run only the PBT file:

```bash
moon test -f pbt_test.mbt
```

## Properties Summary

1. **Round-Trip** - `set`/`get`, If-split/Merge-append, Switch/Merge-append
2. **Idempotent** - `NoOp` under repeated application
3. **Invariant** - cardinality and multiset integrity across nodes
4. **Identity** - `Item::merge(empty)`, `Merge(Append, [], xs)`, `KeepInput{0,1}`
5. **Trichotomy** - `json_compare` numeric ordering laws
6. **Producer-Consumer** - end-to-end workflow execution over DAGs
