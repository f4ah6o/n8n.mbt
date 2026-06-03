///|
test "Workflow::new creates empty workflow" {
  let wf = @n8n.Workflow::new("test")
  inspect(wf.name, content="test")
  inspect(wf.nodes.length(), content="0")
  inspect(wf.connections.length(), content="0")
}

///|
test "Workflow::add_node adds a node" {
  let wf = @n8n.Workflow::new("test").add_node(
    @n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start),
  )
  inspect(wf.nodes.length(), content="1")
}

///|
test "Workflow::connect creates connection" {
  let wf = @n8n.Workflow::new("test")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
    .connect_default(@n8n.NodeId("a"), @n8n.NodeId("b"))
  inspect(wf.connections.length(), content="1")
}

///|
test "Workflow::start_nodes finds nodes with no incoming edges" {
  let wf = @n8n.Workflow::new("test")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
    .connect_default(@n8n.NodeId("a"), @n8n.NodeId("b"))
  let starts = wf.start_nodes()
  inspect(starts.length(), content="1")
  inspect(
    starts[0],
    content=(
      #|NodeId(a)
    ),
  )
}

///|
test "Workflow::topo_sort returns correct order" {
  let wf = @n8n.Workflow::new("test")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("c"), "C", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
    .connect_default(@n8n.NodeId("a"), @n8n.NodeId("b"))
    .connect_default(@n8n.NodeId("b"), @n8n.NodeId("c"))
  let order = wf.topo_sort()
  // a must come before b, b must come before c
  inspect(order.length(), content="3")
  let a_idx = order.search(@n8n.NodeId("a")).unwrap()
  let b_idx = order.search(@n8n.NodeId("b")).unwrap()
  let c_idx = order.search(@n8n.NodeId("c")).unwrap()
  assert_true(a_idx < b_idx)
  assert_true(b_idx < c_idx)
}

///|
test "Workflow::incoming finds incoming connections" {
  let wf = @n8n.Workflow::new("test")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
    .connect_default(@n8n.NodeId("a"), @n8n.NodeId("b"))
  let inc = wf.incoming(@n8n.NodeId("b"))
  inspect(inc.length(), content="1")
}

///|
test "Workflow::outgoing finds outgoing connections" {
  let wf = @n8n.Workflow::new("test")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
    .connect_default(@n8n.NodeId("a"), @n8n.NodeId("b"))
  let out = wf.outgoing(@n8n.NodeId("a"), @n8n.default_port)
  inspect(out.length(), content="1")
}

///|
test "NodeKind::output_count" {
  inspect(@n8n.Start.output_count(), content="1")
  inspect(@n8n.NoOp.output_count(), content="1")
  let cond : @n8n.Condition = {
    field: "x",
    op: @n8n.Equal,
    value: Json::null(),
  }
  inspect(@n8n.If(cond).output_count(), content="2")
}
