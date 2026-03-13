# n8n.mbt

A workflow automation engine inspired by [n8n](https://n8n.io), implemented in MoonBit.

Ports the core concepts — nodes, connections, workflows, and a topological execution engine — to idiomatic MoonBit.

## Features

- DAG-based workflow execution
- Built-in node types: Start, Set, If, Merge, Code, NoOp, Switch
- JSON-based data items flowing between nodes
- Multiple output ports for conditional routing
- Type-safe workflow builder API
