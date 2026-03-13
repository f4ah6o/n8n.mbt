// ── Regression tests for bugs #4-6 ──

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
