///|
/// All edges are reachable through the public builder. NoOp accepts incoming
/// edges, including self-loops, parallel edges and cycles (rejected by sort).
/// Floyd-Warshall reachability is independent of the production Kahn queue.
fn graph_contract(n : Int, edges : Array[(Int, Int, Int)]) -> Bool {
  let empty = @n8n.Workflow::new("graph-contract")
  let mut wf = empty
  for i in 0..<n {
    wf = wf.add_node(
      @n8n.NodeDef::new(@n8n.NodeId("v\{i}"), "v\{i}", @n8n.NoOp),
    )
  }
  let unconnected = wf
  let reach = Array::makei(n, _ => Array::make(n, false))
  for (from, to, input) in edges {
    wf = wf.connect_to_input(
      @n8n.NodeId("v\{from}"),
      @n8n.PortIndex(0),
      @n8n.NodeId("v\{to}"),
      input,
    )
    reach[from][to] = true
  }
  guard empty.nodes.length() == 0 && unconnected.connections.length() == 0 else {
    return false
  }
  guard wf.connections.length() == edges.length() else { return false }
  // Check concrete edge values/order independently of the connection constructor.
  for i in 0..<edges.length() {
    let (from, to, input) = edges[i]
    let c = wf.connections[i]
    guard c.from.node == @n8n.NodeId("v\{from}") &&
      c.from.index == @n8n.PortIndex(0) &&
      c.to == @n8n.NodeId("v\{to}") &&
      c.to_input == input else {
      return false
    }
  }
  let roots = wf.start_nodes()
  for i in 0..<n {
    let id = @n8n.NodeId("v\{i}")
    let expected_in = edges.filter(e => e.1 == i).length()
    let expected_out = edges.filter(e => e.0 == i).length()
    guard wf.incoming(id).length() == expected_in &&
      wf.outgoing(id, @n8n.PortIndex(0)).length() == expected_out &&
      wf.outgoing(id, @n8n.PortIndex(1)).is_empty() else {
      return false
    }
    guard roots.filter(x => x == id).length() ==
      (if expected_in == 0 { 1 } else { 0 }) else {
      return false
    }
  }
  for k in 0..<n {
    for i in 0..<n {
      for j in 0..<n {
        reach[i][j] = reach[i][j] || (reach[i][k] && reach[k][j])
      }
    }
  }
  let mut cyclic = false
  for i in 0..<n {
    cyclic = cyclic || reach[i][i]
  }
  let order = wf.topo_sort() catch { _ => return cyclic }
  guard !cyclic && order.length() == n else { return false }
  let positions : Map[@n8n.NodeId, Int] = Map([])
  for i in 0..<order.length() {
    guard wf.nodes.contains(order[i]) && !positions.contains(order[i]) else {
      return false
    }
    positions[order[i]] = i
  }
  edges.all(e => {
    positions[@n8n.NodeId("v\{e.0}")] < positions[@n8n.NodeId("v\{e.1}")]
  })
}

///|
test "core quickcheck: graph reachability, ordering, adjacency and persistence" {
  @coreqc.check(
    (sample : (Byte, Array[(Byte, Byte, Byte)])) => {
      let n = sample.0.to_int() % 7
      let edges = if n == 0 {
        []
      } else {
        sample.1.map(e => (e.0.to_int() % n, e.1.to_int() % n, e.2.to_int() % 4))
      }
      graph_contract(n, edges)
    },
    count=1000,
    max_size=40,
    max_shrinks=1000,
    seed=20261013,
  )
}

///|
test "graph contract reachable boundaries" {
  assert_true(graph_contract(0, []))
  assert_true(graph_contract(1, []))
  assert_true(graph_contract(1, [(0, 0, 0)]))
  assert_true(graph_contract(2, [(0, 1, 0), (0, 1, 3)]))
  assert_true(graph_contract(2, [(0, 1, 0), (1, 0, 0)]))
  assert_true(graph_contract(6, []))
  assert_true(graph_contract(6, [(0, 1, 0), (0, 2, 1), (1, 3, 0), (2, 3, 1)]))
  assert_true(
    graph_contract(6, [(0, 1, 0), (1, 2, 0), (2, 3, 0), (3, 4, 0), (4, 5, 0)]),
  )
}

///|
test "core quickcheck: error output connects to arbitrary input slot" {
  @coreqc.check(
    (raw : Byte) => {
      let input = raw.to_int()
      let base = @n8n.Workflow::new("error-edge")
        .add_node(
          @n8n.NodeDef::with_options(
            @n8n.NodeId("a"),
            "a",
            @n8n.NoOp,
            on_error=@n8n.ContinueErrorOutput,
          ),
        )
        .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "b", @n8n.NoOp))
      let linked = base.connect_to_input(
        @n8n.NodeId("a"),
        @n8n.PortIndex(1),
        @n8n.NodeId("b"),
        input,
      )
      linked.connections.length() == 1 &&
      linked.connections[0].to_input == input &&
      linked.outgoing(@n8n.NodeId("a"), @n8n.PortIndex(1)).length() == 1 &&
      base.connections.is_empty()
    },
    count=256,
    max_shrinks=1000,
    seed=20261014,
  )
}
