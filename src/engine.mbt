///|
/// Result of executing a single node.
pub(all) struct NodeResult {
  node_id : NodeId
  outputs : Map[PortIndex, Array[Item]]
  /// Execution status of this node.
  status : ExecutionStatus
  /// Error info if the node failed (and continued).
  error : NodeError?
} derive(Show)

///|
/// Result of executing the entire workflow.
pub(all) struct ExecutionResult {
  /// Results for each node, in execution order.
  node_results : Array[NodeResult]
  /// Final output items from terminal nodes (nodes with no outgoing connections).
  final_outputs : Map[NodeId, Array[Item]]
  /// Overall execution status.
  status : ExecutionStatus
  /// Errors collected during execution (for nodes with continueOnFail).
  errors : Array[NodeError]
} derive(Show)

///|
/// Execute a workflow. Runs nodes in topological order, passing items along
/// connections between nodes. This is the MoonBit equivalent of n8n's
/// WorkflowExecute.
pub fn execute(workflow : Workflow) -> ExecutionResult raise {
  let order = workflow.topo_sort()

  // Accumulate items arriving at each node, grouped by input index.
  let node_inputs : Map[NodeId, Map[Int, Array[Item]]] = {}
  let node_results : Array[NodeResult] = []
  let errors : Array[NodeError] = []

  // Track all outputs per node for routing.
  let all_outputs : Map[NodeId, Map[PortIndex, Array[Item]]] = {}

  for node_id in order {
    guard workflow.nodes.get(node_id) is Some(node_def) else {
      fail("node not found: \{node_id}")
    }

    let grouped = node_inputs.get(node_id).unwrap_or({})

    // Handle disabled nodes: pass through input[0] items unchanged.
    if node_def.disabled {
      let pass_through : Array[Item] = grouped.get(0).unwrap_or([])
      let outputs : Map[PortIndex, Array[Item]] = {}
      outputs[default_port] = pass_through
      node_results.push({ node_id, outputs, status: Skipped, error: None, })
      all_outputs[node_id] = outputs
      route_outputs(workflow, node_id, outputs, node_inputs)
      continue
    }

    // Execute the node, with error handling.
    let (outputs, node_error) = try_execute_node(node_def, grouped, node_id)

    match node_error {
      Some(err) =>
        match node_def.on_error {
          StopWorkflow => fail(err.message)
          ContinueRegularOutput => {
            // Pass input items through on regular output.
            let pass_through : Array[Item] = grouped.get(0).unwrap_or([])
            let fallback_outputs : Map[PortIndex, Array[Item]] = {}
            fallback_outputs[default_port] = pass_through
            errors.push(err)
            node_results.push({
              node_id,
              outputs: fallback_outputs,
              status: Error,
              error: Some(err),
            })
            all_outputs[node_id] = fallback_outputs
            route_outputs(workflow, node_id, fallback_outputs, node_inputs)
          }
          ContinueErrorOutput => {
            // Route an error item to the last output port (error port).
            let error_port = PortIndex(node_def.kind.output_count())
            let error_item = Item::of("error", Json::string(err.message)).set(
              "node",
              Json::string(node_id.0),
            )
            let error_outputs : Map[PortIndex, Array[Item]] = {}
            // Pass regular outputs through (empty for each port).
            let port_count = node_def.kind.output_count()
            for i in 0..<port_count {
              error_outputs[PortIndex(i)] = []
            }
            error_outputs[error_port] = [error_item]
            errors.push(err)
            node_results.push({
              node_id,
              outputs: error_outputs,
              status: Error,
              error: Some(err),
            })
            all_outputs[node_id] = error_outputs
            route_outputs(workflow, node_id, error_outputs, node_inputs)
          }
        }
      None => {
        node_results.push({ node_id, outputs, status: Success, error: None, })
        all_outputs[node_id] = outputs
        route_outputs(workflow, node_id, outputs, node_inputs)
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

  let status = if errors.length() > 0 { Error } else { Success }
  { node_results, final_outputs, status, errors, }
}

///|
/// Try to execute a node, catching aborts/failures for error handling.
fn try_execute_node(
  node_def : NodeDef,
  grouped : Map[Int, Array[Item]],
  node_id : NodeId,
) -> (Map[PortIndex, Array[Item]], NodeError?) raise {
  // If on_error is StopWorkflow, just execute directly (errors propagate).
  if node_def.on_error is StopWorkflow {
    let outputs = execute_node_grouped(node_def.kind, grouped, node_id)
    return (outputs, None)
  }
  // For continue modes, try execution and catch errors.
  let result : Result[Map[PortIndex, Array[Item]], _] = Ok(
    execute_node_grouped(node_def.kind, grouped, node_id),
  ) catch {
    error => Err(error)
  }
  match result {
    Ok(outputs) => (outputs, None)
    Err(e) => {
      let empty : Map[PortIndex, Array[Item]] = {}
      (empty, Some({ message: e.to_string(), node_id, }))
    }
  }
}

///|
/// Execute a node given its kind and grouped inputs.
fn execute_node_grouped(
  kind : NodeKind,
  grouped : Map[Int, Array[Item]],
  node_id : NodeId,
) -> Map[PortIndex, Array[Item]] raise {
  match kind {
    Merge(mode) => {
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
      execute_node(kind, flat)
    }
  }
}

///|
/// Route output items from a node to downstream nodes via connections.
fn route_outputs(
  workflow : Workflow,
  node_id : NodeId,
  outputs : Map[PortIndex, Array[Item]],
  node_inputs : Map[NodeId, Map[Int, Array[Item]]],
) -> Unit {
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
