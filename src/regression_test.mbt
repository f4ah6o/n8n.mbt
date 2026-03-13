// ── Regression tests for bugs #4-8 ──

///|
/// Bug #4: connect_to_input with negative to_input should abort.
test "panic regression/connect_to_input: negative to_input aborts" {
  let wf = @n8n.Workflow::new("bad-connect")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
  ignore(
    wf.connect_to_input(
      @n8n.NodeId("a"),
      @n8n.default_port,
      @n8n.NodeId("b"),
      -1,
    ),
  )
}

///|
/// Bug #4: Merge with input index 2 should fail at execution time.
test "panic regression/merge: invalid input index 2 fails" {
  let wf = @n8n.Workflow::new("bad-merge-input")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "S1", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(@n8n.NodeId("merge"), "Merge", @n8n.Merge(@n8n.Append)),
    )
    .connect_to_input(
      @n8n.NodeId("s1"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      2,
    )
  ignore(@n8n.execute(wf))
}

///|
/// Bug #5: Non-Merge node with multiple inputs preserves index order.
/// Items from input 0 must come before items from input 1.
test "regression/input_order: non-Merge node flattens in input-index order" {
  // Build: two Start nodes feed a Code node via input 0 and input 1.
  // Code node concatenates items — order must be input0 then input1.
  let wf = @n8n.Workflow::new("input-order")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s0"), "S0", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "S1", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set0"),
        "Set0",
        @n8n.Set([{ key: "src", value: Json::string("input0") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set1"),
        "Set1",
        @n8n.Set([{ key: "src", value: Json::string("input1") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("collect"),
        "Collect",
        @n8n.Code(fn(items) { items }),
      ),
    )
    .connect_default(@n8n.NodeId("s0"), @n8n.NodeId("set0"))
    .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("set1"))
    .connect_to_input(
      @n8n.NodeId("set0"),
      @n8n.default_port,
      @n8n.NodeId("collect"),
      0,
    )
    .connect_to_input(
      @n8n.NodeId("set1"),
      @n8n.default_port,
      @n8n.NodeId("collect"),
      1,
    )
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("collect")) is Some(items) else {
    fail("expected output from collect")
  }
  inspect(items.length(), content="2")
  // Input 0 items must come before input 1 items, regardless of Map iteration order.
  inspect(
    items[0].get("src"),
    content=(
      #|Some(String("input0"))
    ),
  )
  inspect(
    items[1].get("src"),
    content=(
      #|Some(String("input1"))
    ),
  )
}

///|
/// Bug #6: execute_node(Merge(...)) should abort, not silently return wrong results.
test "panic regression/execute_node: Merge aborts" {
  ignore(
    @n8n.execute_node(@n8n.Merge(@n8n.KeepInput0), [
      @n8n.Item::of("a", Json::number(1)),
    ]),
  )
}

///|
/// Bug #7: connect to non-existent source node should abort.
test "panic regression/connect: non-existent source node aborts" {
  let wf = @n8n.Workflow::new("bad-src").add_node(
    @n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp),
  )
  ignore(wf.connect_default(@n8n.NodeId("ghost"), @n8n.NodeId("b")))
}

///|
/// Bug #7: connect to non-existent target node should abort.
test "panic regression/connect: non-existent target node aborts" {
  let wf = @n8n.Workflow::new("bad-tgt").add_node(
    @n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start),
  )
  ignore(wf.connect_default(@n8n.NodeId("a"), @n8n.NodeId("ghost")))
}

///|
/// Bug #7: connect_to_input to non-existent target should abort.
test "panic regression/connect_to_input: non-existent target aborts" {
  let wf = @n8n.Workflow::new("bad-tgt2").add_node(
    @n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start),
  )
  ignore(
    wf.connect_to_input(
      @n8n.NodeId("a"),
      @n8n.default_port,
      @n8n.NodeId("ghost"),
      0,
    ),
  )
}

///|
/// Bug #8: Connection::with_input(-1) should abort (bypass Workflow builder).
test "panic regression/Connection::with_input: negative to_input aborts" {
  ignore(
    @n8n.Connection::with_input(
      @n8n.NodeId("a"),
      @n8n.default_port,
      @n8n.NodeId("b"),
      -1,
    ),
  )
}

///|
/// Bug #9: connect with out-of-range output port should abort.
test "panic regression/connect: invalid output port aborts" {
  let wf = @n8n.Workflow::new("bad-port")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
  // Start has output_count=1, so PortIndex(1) is out of range
  ignore(wf.connect(@n8n.NodeId("a"), @n8n.PortIndex(1), @n8n.NodeId("b")))
}

///|
/// Bug #9: connect_to_input with out-of-range output port should abort.
test "panic regression/connect_to_input: invalid output port aborts" {
  let wf = @n8n.Workflow::new("bad-port2")
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("if"),
        "If",
        @n8n.If({ field: "x", op: @n8n.Exists, value: Json::null() }),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("b"), "B", @n8n.NoOp))
  // If has output_count=2, so PortIndex(2) is out of range
  ignore(
    wf.connect_to_input(
      @n8n.NodeId("if"),
      @n8n.PortIndex(2),
      @n8n.NodeId("b"),
      0,
    ),
  )
}

///|
/// Bug #10: connecting to a Start node should abort.
test "panic regression/connect: target Start node aborts" {
  let wf = @n8n.Workflow::new("bad-start")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "S", @n8n.Start))
  ignore(wf.connect_default(@n8n.NodeId("a"), @n8n.NodeId("s")))
}

///|
/// Bug #10: connect_to_input to a Start node should abort.
test "panic regression/connect_to_input: target Start node aborts" {
  let wf = @n8n.Workflow::new("bad-start2")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "S", @n8n.Start))
  ignore(
    wf.connect_to_input(
      @n8n.NodeId("a"),
      @n8n.default_port,
      @n8n.NodeId("s"),
      0,
    ),
  )
}

///|
/// Bug #11: adding a duplicate NodeId should abort.
test "panic regression/add_node: duplicate NodeId aborts" {
  let wf = @n8n.Workflow::new("dup-id").add_node(
    @n8n.NodeDef::new(@n8n.NodeId("a"), "A", @n8n.NoOp),
  )
  ignore(wf.add_node(@n8n.NodeDef::new(@n8n.NodeId("a"), "B", @n8n.Start)))
}
