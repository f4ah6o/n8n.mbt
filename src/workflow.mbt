///|
/// A Workflow is a directed acyclic graph of nodes connected by edges.
/// This is the MoonBit equivalent of n8n's IWorkflowBase.
pub(all) struct Workflow {
  name : String
  nodes : Map[NodeId, NodeDef]
  connections : Array[Connection]
} derive(Show)

///|
pub fn Workflow::new(name : String) -> Workflow {
  { name, nodes: {}, connections: [] }
}

///|
/// Add a node to the workflow.
pub fn Workflow::add_node(self : Workflow, node : NodeDef) -> Workflow {
  guard not(self.nodes.contains(node.id)) else {
    abort("add_node: node \{node.id} already exists in workflow")
  }
  let nodes : Map[NodeId, NodeDef] = {}
  for k, v in self.nodes {
    nodes[k] = v
  }
  nodes[node.id] = node
  { ..self, nodes, }
}

///|
/// Connect source node's output port to a target node.
pub fn Workflow::connect(
  self : Workflow,
  from : NodeId,
  port : PortIndex,
  to : NodeId,
) -> Workflow {
  guard self.nodes.get(from) is Some(from_def) else {
    abort("connect: source node \{from} does not exist in workflow")
  }
  guard self.nodes.get(to) is Some(to_def) else {
    abort("connect: target node \{to} does not exist in workflow")
  }
  let PortIndex(port_idx) = port
  let max_ports = from_def.kind.output_count()
  let has_error_port = from_def.on_error is ContinueErrorOutput
  let limit = if has_error_port { max_ports + 1 } else { max_ports }
  guard port_idx >= 0 && port_idx < limit else {
    abort(
      "connect: port \{port} is out of range for node \{from} (output_count=\{max_ports})",
    )
  }
  guard not(to_def.kind is Start) else {
    abort("connect: cannot connect to Start node \{to} (Start ignores input)")
  }
  let conn = Connection::new(from, port, to)
  let connections = self.connections.copy()
  connections.push(conn)
  { ..self, connections, }
}

///|
/// Connect source node's default output (port 0) to target node.
pub fn Workflow::connect_default(
  self : Workflow,
  from : NodeId,
  to : NodeId,
) -> Workflow {
  self.connect(from, default_port, to)
}

///|
/// Connect source node's output port to a specific input index of the target node.
/// Use this for Merge nodes to distinguish input 0 from input 1.
pub fn Workflow::connect_to_input(
  self : Workflow,
  from : NodeId,
  port : PortIndex,
  to : NodeId,
  to_input : Int,
) -> Workflow {
  guard self.nodes.get(from) is Some(from_def) else {
    abort("connect_to_input: source node \{from} does not exist in workflow")
  }
  guard self.nodes.get(to) is Some(to_def) else {
    abort("connect_to_input: target node \{to} does not exist in workflow")
  }
  let PortIndex(port_idx) = port
  let max_ports = from_def.kind.output_count()
  let has_error_port = from_def.on_error is ContinueErrorOutput
  let limit = if has_error_port { max_ports + 1 } else { max_ports }
  guard port_idx >= 0 && port_idx < limit else {
    abort(
      "connect_to_input: port \{port} is out of range for node \{from} (output_count=\{max_ports})",
    )
  }
  guard not(to_def.kind is Start) else {
    abort(
      "connect_to_input: cannot connect to Start node \{to} (Start ignores input)",
    )
  }
  guard to_input >= 0 else {
    abort("connect_to_input: to_input must be non-negative, got \{to_input}")
  }
  let conn = Connection::with_input(from, port, to, to_input)
  let connections = self.connections.copy()
  connections.push(conn)
  { ..self, connections, }
}

///|
/// Find all start nodes (nodes with no incoming connections).
pub fn Workflow::start_nodes(self : Workflow) -> Array[NodeId] {
  let has_incoming : Map[NodeId, Bool] = {}
  for conn in self.connections {
    has_incoming[conn.to] = true
  }
  let result : Array[NodeId] = []
  for id, _ in self.nodes {
    if not(has_incoming.contains(id)) {
      result.push(id)
    }
  }
  result
}

///|
/// Find all connections going into the given node.
pub fn Workflow::incoming(
  self : Workflow,
  node_id : NodeId,
) -> Array[Connection] {
  self.connections.filter(fn(c) { c.to == node_id })
}

///|
/// Find all connections coming out of the given node at a specific port.
pub fn Workflow::outgoing(
  self : Workflow,
  node_id : NodeId,
  port : PortIndex,
) -> Array[Connection] {
  self.connections.filter(fn(c) {
    c.from.node == node_id && c.from.index == port
  })
}

///|
/// Compute topological order of node IDs for execution.
/// Returns an error string if the graph has a cycle.
pub fn Workflow::topo_sort(self : Workflow) -> Array[NodeId] raise {
  // Kahn's algorithm
  let in_degree : Map[NodeId, Int] = {}
  for id, _ in self.nodes {
    in_degree[id] = 0
  }
  for conn in self.connections {
    in_degree[conn.to] = in_degree.get(conn.to).unwrap_or(0) + 1
  }
  let queue : Array[NodeId] = []
  for id, deg in in_degree {
    if deg == 0 {
      queue.push(id)
    }
  }
  let sorted : Array[NodeId] = []
  for idx = 0; idx < queue.length(); {
    let node_id = queue[idx]
    sorted.push(node_id)
    // Decrease in-degree of downstream nodes
    for conn in self.connections {
      if conn.from.node == node_id {
        let new_deg = in_degree.get(conn.to).unwrap_or(0) - 1
        in_degree[conn.to] = new_deg
        if new_deg == 0 {
          queue.push(conn.to)
        }
      }
    }
    continue idx + 1
  }
  if sorted.length() != self.nodes.length() {
    fail("workflow contains a cycle")
  }
  sorted
}
