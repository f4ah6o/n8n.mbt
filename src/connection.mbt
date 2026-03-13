///|
/// A NodeId uniquely identifies a node within a workflow.
pub(all) struct NodeId(String) derive(Eq, Hash, Show, ToJson)

///|
/// A PortIndex identifies an output port of a node.
/// Nodes can have multiple outputs (e.g., If has true=0, false=1).
pub(all) struct PortIndex(Int) derive(Eq, Hash, Show, ToJson)

///|
/// Default output port (index 0).
pub let default_port : PortIndex = PortIndex(0)

///|
/// A Port identifies a specific output of a specific node.
pub(all) struct Port {
  node : NodeId
  index : PortIndex
} derive(Eq, Hash, Show, ToJson)

///|
pub fn Port::new(node : NodeId, index : PortIndex) -> Port {
  { node, index }
}

///|
/// A Connection links an output port of one node to the input of another.
/// In n8n, connections go from source node's output to target node's input.
/// `to_input` identifies which input slot of the target node this feeds into
/// (relevant for Merge nodes that distinguish input 0 vs input 1).
pub(all) struct Connection {
  from : Port
  to : NodeId
  to_input : Int
} derive(Show, ToJson, Eq)

///|
pub fn Connection::new(
  from_node : NodeId,
  from_port : PortIndex,
  to_node : NodeId,
) -> Connection {
  { from: { node: from_node, index: from_port }, to: to_node, to_input: 0 }
}

///|
/// Create a connection with a specific target input index.
pub fn Connection::with_input(
  from_node : NodeId,
  from_port : PortIndex,
  to_node : NodeId,
  to_input : Int,
) -> Connection {
  { from: { node: from_node, index: from_port }, to: to_node, to_input }
}
