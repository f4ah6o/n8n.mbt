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
