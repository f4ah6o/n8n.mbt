///|
/// Result of executing a single node.
pub(all) struct NodeResult {
  node_id : NodeId
  outputs : Map[PortIndex, Array[Item]]
} derive(Show)

///|
/// Result of executing the entire workflow.
pub(all) struct ExecutionResult {
  /// Results for each node, in execution order.
  node_results : Array[NodeResult]
  /// Final output items from terminal nodes (nodes with no outgoing connections).
  final_outputs : Map[NodeId, Array[Item]]
} derive(Show)

///|
/// Execute a workflow. Runs nodes in topological order, passing items along
/// connections between nodes. This is the MoonBit equivalent of n8n's
/// WorkflowExecute.
pub fn execute(workflow : Workflow) -> ExecutionResult raise {
  let order = workflow.topo_sort()

  // Accumulate items arriving at each node, grouped by input index.
  // Map[NodeId, Map[Int, Array[Item]]] — outer key is node, inner key is input index.
  let node_inputs : Map[NodeId, Map[Int, Array[Item]]] = {}
  let node_results : Array[NodeResult] = []

  // Track all outputs per node for routing.
  let all_outputs : Map[NodeId, Map[PortIndex, Array[Item]]] = {}

  for node_id in order {
    guard workflow.nodes.get(node_id) is Some(node_def) else {
      fail("node not found: \{node_id}")
    }

    let grouped = node_inputs.get(node_id).unwrap_or({})

    // Execute the node.
    let outputs = match node_def.kind {
      Merge(mode) => {
        // Validate that Merge only has input indices 0 and 1.
        for key, _ in grouped {
          guard key == 0 || key == 1 else {
            fail(
              "Merge node \{node_id} received items on input \{key}; only 0 and 1 are valid",
            )
          }
        }
        let input0 = grouped.get(0).unwrap_or([])
        let input1 = grouped.get(1).unwrap_or([])
        execute_merge(mode, input0, input1)
      }
      _ => {
        // Flatten grouped inputs in input-index order for deterministic ordering.
        let keys : Array[Int] = []
        for k, _ in grouped {
          keys.push(k)
        }
        keys.sort()
        let flat : Array[Item] = []
        for k in keys {
          let items = grouped.get(k).unwrap_or([])
          for item in items {
            flat.push(item)
          }
        }
        execute_node(node_def.kind, flat)
      }
    }

    // Record results.
    node_results.push({ node_id, outputs })
    all_outputs[node_id] = outputs

    // Route output items to downstream nodes via connections.
    for port, items in outputs {
      let conns = workflow.outgoing(node_id, port)
      for conn in conns {
        let target_grouped = node_inputs.get(conn.to).unwrap_or({})
        let existing = target_grouped.get(conn.to_input).unwrap_or([])
        for item in items {
          existing.push(item)
        }
        target_grouped[conn.to_input] = existing
        node_inputs[conn.to] = target_grouped
      }
    }
  }

  // Collect final outputs: nodes with no outgoing connections.
  let final_outputs : Map[NodeId, Array[Item]] = {}
  for node_id, _ in workflow.nodes {
    let has_outgoing = workflow.connections
      .iter()
      .any(fn(c) { c.from.node == node_id })
    if not(has_outgoing) {
      let items : Array[Item] = []
      guard all_outputs.get(node_id) is Some(port_outputs) else { continue }
      for _, port_items in port_outputs {
        for item in port_items {
          items.push(item)
        }
      }
      final_outputs[node_id] = items
    }
  }

  { node_results, final_outputs }
}
