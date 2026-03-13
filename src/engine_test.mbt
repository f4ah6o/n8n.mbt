///|
/// Helper: create a simple linear workflow: Start → Set → end
fn make_linear_workflow() -> @n8n.Workflow {
  @n8n.Workflow::new("linear")
  .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
  .add_node(
    @n8n.NodeDef::new(
      @n8n.NodeId("set1"),
      "Set Name",
      @n8n.Set([{ key: "name", value: Json::string("alice") }]),
    ),
  )
  .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set1"))
}

///|
test "linear workflow: Start → Set" {
  let wf = make_linear_workflow()
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("set1")) is Some(items) else {
    fail("expected final output from set1")
  }
  inspect(items.length(), content="1")
  inspect(
    items[0].get("name"),
    content=(
      #|Some(String("alice"))
    ),
  )
}

///|
test "branching workflow: Start → If → true/false paths" {
  let wf = @n8n.Workflow::new("branching")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set_score"),
        "Set Score",
        @n8n.Set([{ key: "score", value: Json::number(85) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("check"),
        "Check Score",
        @n8n.If({
          field: "score",
          op: @n8n.GreaterEqual,
          value: Json::number(70),
        }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("pass"),
        "Pass",
        @n8n.Set([{ key: "result", value: Json::string("pass") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("fail_node"),
        "Fail",
        @n8n.Set([{ key: "result", value: Json::string("fail") }]),
      ),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set_score"))
    .connect_default(@n8n.NodeId("set_score"), @n8n.NodeId("check"))
    .connect(@n8n.NodeId("check"), @n8n.PortIndex(0), @n8n.NodeId("pass"))
    .connect(@n8n.NodeId("check"), @n8n.PortIndex(1), @n8n.NodeId("fail_node"))
  let result = @n8n.execute(wf)
  // score=85 >= 70, so item goes to "pass" (port 0)
  guard result.final_outputs.get(@n8n.NodeId("pass")) is Some(pass_items) else {
    fail("expected output from pass node")
  }
  inspect(pass_items.length(), content="1")
  inspect(
    pass_items[0].get("result"),
    content=(
      #|Some(String("pass"))
    ),
  )
  inspect(pass_items[0].get("score"), content="Some(Number(85))")
  // fail_node should get 0 items
  guard result.final_outputs.get(@n8n.NodeId("fail_node")) is Some(fail_items) else {
    fail("expected output from fail_node")
  }
  inspect(fail_items.length(), content="0")
}

///|
test "Code node transforms items" {
  let wf = @n8n.Workflow::new("code")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set"),
        "Set Value",
        @n8n.Set([{ key: "x", value: Json::number(10) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("code"),
        "Double",
        @n8n.Code(fn(items) {
          items.map(fn(item) {
            match item.get("x") {
              Some(Number(n, ..)) => item.set("x", Json::number(n * 2))
              _ => item
            }
          })
        }),
      ),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("code"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("code")) is Some(items) else {
    fail("expected output from code node")
  }
  inspect(items.length(), content="1")
  inspect(items[0].get("x"), content="Some(Number(20))")
}

///|
test "Merge Append combines items from two branches" {
  let wf = @n8n.Workflow::new("merge")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "Start1", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "Start2", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set_a"),
        "Set A",
        @n8n.Set([{ key: "a", value: Json::number(1) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set_b"),
        "Set B",
        @n8n.Set([{ key: "b", value: Json::number(2) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(@n8n.NodeId("merge"), "Merge", @n8n.Merge(@n8n.Append)),
    )
    .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("set_a"))
    .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("set_b"))
    .connect_to_input(
      @n8n.NodeId("set_a"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      0,
    )
    .connect_to_input(
      @n8n.NodeId("set_b"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      1,
    )
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("merge")) is Some(items) else {
    fail("expected output from merge node")
  }
  // Append: both items present
  inspect(items.length(), content="2")
}

///|
test "NoOp passes items through" {
  let wf = @n8n.Workflow::new("noop")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set"),
        "Set",
        @n8n.Set([{ key: "v", value: Json::number(42) }]),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("noop"), "NoOp", @n8n.NoOp))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("noop"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("noop")) is Some(items) else {
    fail("expected output from noop")
  }
  inspect(items.length(), content="1")
  inspect(items[0].get("v"), content="Some(Number(42))")
}

///|
test "Switch node routes to correct output" {
  let wf = @n8n.Workflow::new("switch")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set"),
        "Set Status",
        @n8n.Set([{ key: "status", value: Json::string("active") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("switch"),
        "Route",
        @n8n.Switch(
          [
            {
              condition: {
                field: "status",
                op: @n8n.Equal,
                value: Json::string("active"),
              },
              output: @n8n.PortIndex(0),
            },
            {
              condition: {
                field: "status",
                op: @n8n.Equal,
                value: Json::string("pending"),
              },
              output: @n8n.PortIndex(1),
            },
          ],
          fallback=@n8n.PortIndex(2),
        ),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("active_handler"),
        "Active",
        @n8n.Set([{ key: "handled", value: Json::boolean(true) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("pending_handler"),
        "Pending",
        @n8n.Set([{ key: "handled", value: Json::boolean(true) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(@n8n.NodeId("default_handler"), "Default", @n8n.NoOp),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("switch"))
    .connect(
      @n8n.NodeId("switch"),
      @n8n.PortIndex(0),
      @n8n.NodeId("active_handler"),
    )
    .connect(
      @n8n.NodeId("switch"),
      @n8n.PortIndex(1),
      @n8n.NodeId("pending_handler"),
    )
    .connect(
      @n8n.NodeId("switch"),
      @n8n.PortIndex(2),
      @n8n.NodeId("default_handler"),
    )
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("active_handler"))
    is Some(active_items) else {
    fail("expected output from active_handler")
  }
  inspect(active_items.length(), content="1")
  inspect(
    active_items[0].get("status"),
    content=(
      #|Some(String("active"))
    ),
  )
  inspect(active_items[0].get("handled"), content="Some(True)")
}

///|
test "execute returns node_results in order" {
  let wf = make_linear_workflow()
  let result = @n8n.execute(wf)
  inspect(result.node_results.length(), content="2")
  inspect(
    result.node_results[0].node_id,
    content=(
      #|NodeId("start")
    ),
  )
  inspect(
    result.node_results[1].node_id,
    content=(
      #|NodeId("set1")
    ),
  )
}

///|
test "condition: Contains operator" {
  let items = [@n8n.Item::of("msg", Json::string("hello world"))]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "msg", op: @n8n.Contains, value: Json::string("world") }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="0")
}

///|
test "condition: Exists / NotExists" {
  let items = [@n8n.Item::of("a", Json::number(1)), @n8n.Item::empty()]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "a", op: @n8n.Exists, value: Json::null() }),
    items,
  )
  // First item has "a" → true (port 0), second doesn't → false (port 1)
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

// ── MergeMode tests ──

///|
/// Helper: build a two-branch merge workflow with the given mode.
fn make_merge_workflow(mode : @n8n.MergeMode) -> @n8n.Workflow {
  @n8n.Workflow::new("merge-test")
  .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "Start1", @n8n.Start))
  .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "Start2", @n8n.Start))
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
  .add_node(@n8n.NodeDef::new(@n8n.NodeId("merge"), "Merge", @n8n.Merge(mode)))
  .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("set0"))
  .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("set1"))
  .connect_to_input(
    @n8n.NodeId("set0"),
    @n8n.default_port,
    @n8n.NodeId("merge"),
    0,
  )
  .connect_to_input(
    @n8n.NodeId("set1"),
    @n8n.default_port,
    @n8n.NodeId("merge"),
    1,
  )
}

///|
test "Merge KeepInput0 keeps only input 0 items" {
  let wf = make_merge_workflow(@n8n.KeepInput0)
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("merge")) is Some(items) else {
    fail("expected output from merge node")
  }
  inspect(items.length(), content="1")
  inspect(
    items[0].get("src"),
    content=(
      #|Some(String("input0"))
    ),
  )
}

///|
test "Merge KeepInput1 keeps only input 1 items" {
  let wf = make_merge_workflow(@n8n.KeepInput1)
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("merge")) is Some(items) else {
    fail("expected output from merge node")
  }
  inspect(items.length(), content="1")
  inspect(
    items[0].get("src"),
    content=(
      #|Some(String("input1"))
    ),
  )
}

///|
test "Merge MergeByPosition zips items by index" {
  // Build a workflow where each branch produces one item, then merge by position.
  let wf = make_merge_workflow(@n8n.MergeByPosition)
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("merge")) is Some(items) else {
    fail("expected output from merge node")
  }
  // 1 item from each input at position 0 → merged into 1 item
  inspect(items.length(), content="1")
  // Merged item has fields from both (input1 overrides "src" from input0)
  inspect(
    items[0].get("src"),
    content=(
      #|Some(String("input1"))
    ),
  )
}

///|
test "Merge Append includes all items from both inputs" {
  let wf = make_merge_workflow(@n8n.Append)
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("merge")) is Some(items) else {
    fail("expected output from merge node")
  }
  inspect(items.length(), content="2")
}

// ── Non-numeric comparison tests ──

///|
test "GreaterEqual on non-numeric returns false" {
  // String vs String should not satisfy GreaterEqual (incomparable via json_compare)
  let items = [@n8n.Item::of("name", Json::string("alice"))]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "name", op: @n8n.GreaterEqual, value: Json::string("bob") }),
    items,
  )
  // false branch (port 1) should get the item
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
test "LessEqual on type-mismatched values returns false" {
  // Number vs String should be incomparable
  let items = [@n8n.Item::of("x", Json::number(42))]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "x", op: @n8n.LessEqual, value: Json::string("hello") }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
test "GreaterThan on booleans returns false" {
  let items = [@n8n.Item::of("flag", Json::boolean(true))]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "flag", op: @n8n.GreaterThan, value: Json::boolean(false) }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

// ── Switch::output_count with fallback ──

///|
test "Switch output_count includes fallback port" {
  // Rules only use port 0, but fallback is port 5 → output_count should be 6
  let kind = @n8n.Switch(
    [
      {
        condition: { field: "x", op: @n8n.Equal, value: Json::number(1) },
        output: @n8n.PortIndex(0),
      },
    ],
    fallback=@n8n.PortIndex(5),
  )
  inspect(kind.output_count(), content="6")
}

///|
test "Switch output_count when rules exceed fallback" {
  // Rule uses port 3, fallback is port 1 → output_count should be 4
  let kind = @n8n.Switch(
    [
      {
        condition: { field: "x", op: @n8n.Equal, value: Json::number(1) },
        output: @n8n.PortIndex(3),
      },
    ],
    fallback=@n8n.PortIndex(1),
  )
  inspect(kind.output_count(), content="4")
}
