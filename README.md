# n8n.mbt

A workflow automation engine inspired by [n8n](https://n8n.io), implemented in MoonBit.

Ports the core concepts — nodes, connections, workflows, and a topological execution engine — to idiomatic MoonBit.

The test package also keeps a private `dslx.mbt` contract using `@dslx.n8nx()`.
That contract checks a small workflow DSL example through the `dslx` project API;
it is a dependency contract and does not replace the workflow engine.

## Features

- DAG-based workflow execution
- Built-in node types: Start, Set, If, Merge, Code, NoOp, Switch
- JSON-based data items flowing between nodes
- Multiple output ports for conditional routing
- Type-safe workflow builder API

## Bounded workflow quality pilot

`src/workflow_properties_test.mbt` uses official `moonbitlang/core/quickcheck`
with fixed seeds 20261013/20261014 and up to 1,000 shrinking attempts. The graph
property checks up to six nodes and generated directed multigraphs against a
Floyd-Warshall cycle oracle, then checks topological permutation/edge ordering,
adjacency counts, input slots and builder persistence. Explicit cases cover
empty graphs, isolated nodes, self-cycles, two-node cycles, parallel edges,
branching and chains. A second property covers the reachable extra error port
of `ContinueErrorOutput` with `connect_to_input`.

Run `moon test src/workflow_properties_test.mbt`, `moon check`, and `moon test`.
The pilot also passes checks and tests on wasm-gc, JS and native with MoonBit
0.10.14. Existing external `moonbitlang/quickcheck` tests/dependency remain;
this is incremental core adoption, not a full legacy-suite migration.

`turtles.toml` restricts turtles 0.4.6 to `src/workflow.mbt` and comparison,
boolean, arithmetic and condition operators. Run `turtles --list`, then
`turtles --timeout 20 --json mutation.json`. This scope does not measure all
operators, the execution engine, or integrations, and makes no real n8n calls.
Keep timeout and unviable outcomes separate from kills. Compare stable mutant
IDs and unchanged production fingerprints when measuring test improvements.
The repository has pre-existing formatter/manifest-migration differences under
this toolchain; this pilot preserves production files and does not suppress
warnings or weaken gates.
