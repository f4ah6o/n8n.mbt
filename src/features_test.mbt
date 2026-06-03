///|
// Tests for disabled nodes, error handling, and execution metadata.

///|
test "disabled node: passes input through without executing" {
  let wf = @n8n.Workflow::new("disabled-test")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::with_options(
        @n8n.NodeId("set"),
        "Set",
        @n8n.Set([{ key: "added", value: Json::string("yes") }]),
        disabled=true,
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("end"), "End", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("end"))
  let result = try! @n8n.execute(wf)
  let end_items = result.final_outputs.get(@n8n.NodeId("end")).unwrap_or([])
  // Start emits empty item, disabled Set should pass it through unchanged.
  inspect(end_items.length(), content="1")
  // The "added" field should NOT be present (Set was skipped).
  inspect(end_items[0].get("added"), content="None")
}

///|
test "disabled node: status is Skipped" {
  let wf = @n8n.Workflow::new("disabled-status")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::with_options(
        @n8n.NodeId("noop"),
        "NoOp",
        @n8n.NoOp,
        disabled=true,
      ),
    )
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("noop"))
  let result = try! @n8n.execute(wf)
  // Find the disabled node's result.
  let mut found = false
  for nr in result.node_results {
    if nr.node_id == @n8n.NodeId("noop") {
      inspect(nr.status, content="Skipped")
      found = true
    }
  }
  inspect(found, content="true")
}

///|
test "execution result: overall status is Success when no errors" {
  let wf = @n8n.Workflow::new("status-ok")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("n"), "NoOp", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("n"))
  let result = try! @n8n.execute(wf)
  inspect(result.status, content="Success")
  inspect(result.errors.length(), content="0")
}

///|
test "execution result: node results have Success status" {
  let wf = @n8n.Workflow::new("node-status").add_node(
    @n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start),
  )
  let result = try! @n8n.execute(wf)
  inspect(result.node_results[0].status, content="Success")
  inspect(result.node_results[0].error, content="None")
}

///|
test "error handling: ContinueRegularOutput passes input through" {
  let wf = @n8n.Workflow::new("continue-regular")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::with_options(
        @n8n.NodeId("bad"),
        "Bad",
        @n8n.Code(fn(_items) raise { fail("boom") }),
        on_error=@n8n.ContinueRegularOutput,
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("end"), "End", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("bad"))
    .connect_default(@n8n.NodeId("bad"), @n8n.NodeId("end"))
  let result = try! @n8n.execute(wf)
  // Execution should succeed overall (with errors collected).
  inspect(result.status, content="Error")
  inspect(result.errors.length(), content="1")
  // End node should still receive the input item (passed through).
  let end_items = result.final_outputs.get(@n8n.NodeId("end")).unwrap_or([])
  inspect(end_items.length(), content="1")
}

///|
test "error handling: ContinueErrorOutput routes error item" {
  let wf = @n8n.Workflow::new("continue-error-out")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::with_options(
        @n8n.NodeId("bad"),
        "Bad",
        // NoOp has output_count=1, so error port = PortIndex(1)
        @n8n.Code(fn(_items) raise { fail("fail!") }),
        on_error=@n8n.ContinueErrorOutput,
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("ok"), "Ok", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("err"), "Err", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("bad"))
    // Regular output port 0 → ok
    .connect(@n8n.NodeId("bad"), @n8n.PortIndex(0), @n8n.NodeId("ok"))
    // Error port (output_count for Code = 1, so error port = 1)
    .connect(@n8n.NodeId("bad"), @n8n.PortIndex(1), @n8n.NodeId("err"))
  let result = try! @n8n.execute(wf)
  inspect(result.errors.length(), content="1")
  // Ok should get nothing (error cleared regular outputs).
  let ok_items = result.final_outputs.get(@n8n.NodeId("ok")).unwrap_or([])
  inspect(ok_items.length(), content="0")
  // Err should get the error item.
  let err_items = result.final_outputs.get(@n8n.NodeId("err")).unwrap_or([])
  inspect(err_items.length(), content="1")
  // Error item should have an "error" field.
  inspect(not(err_items[0].get("error") is None), content="true")
}

///|
test "error handling: StopWorkflow propagates error" {
  let wf = @n8n.Workflow::new("stop-wf")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::with_options(
        @n8n.NodeId("bad"),
        "Bad",
        @n8n.Code(fn(_items) raise { fail("fatal") }),
        on_error=@n8n.StopWorkflow,
      ),
    )
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("bad"))
  let r : Result[_, _] = try? @n8n.execute(wf)
  inspect(r is Err(_), content="true")
}

///|
test "disabled node in the middle of a chain" {
  let wf = @n8n.Workflow::new("disabled-chain")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set1"),
        "Set1",
        @n8n.Set([{ key: "a", value: Json::number(1) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::with_options(
        @n8n.NodeId("set2"),
        "Set2",
        @n8n.Set([{ key: "b", value: Json::number(2) }]),
        disabled=true,
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set3"),
        "Set3",
        @n8n.Set([{ key: "c", value: Json::number(3) }]),
      ),
    )
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("set1"))
    .connect_default(@n8n.NodeId("set1"), @n8n.NodeId("set2"))
    .connect_default(@n8n.NodeId("set2"), @n8n.NodeId("set3"))
  let result = try! @n8n.execute(wf)
  let items = result.final_outputs.get(@n8n.NodeId("set3")).unwrap_or([])
  inspect(items.length(), content="1")
  // "a" should be set (set1 ran), "b" should NOT (set2 disabled), "c" should be set
  inspect(items[0].get("a"), content="Some(Number(1))")
  inspect(items[0].get("b"), content="None")
  inspect(items[0].get("c"), content="Some(Number(3))")
}

///|
test "Filter in workflow: Start → Filter → End" {
  let wf = @n8n.Workflow::new("filter-wf")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set"),
        "Set",
        @n8n.Set([{ key: "x", value: Json::number(1) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("filter"),
        "Filter",
        @n8n.Filter({ field: "missing", op: @n8n.Exists, value: Json::null() }),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("end"), "End", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("filter"))
    .connect_default(@n8n.NodeId("filter"), @n8n.NodeId("end"))
  let result = try! @n8n.execute(wf)
  // Item has "x" but not "missing", so Filter drops it.
  let items = result.final_outputs.get(@n8n.NodeId("end")).unwrap_or([])
  inspect(items.length(), content="0")
}

///|
test "Limit in workflow: limits items flowing through" {
  let wf = @n8n.Workflow::new("limit-wf")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("code"),
        "Code",
        @n8n.Code(fn(_items) {
          [
            @n8n.Item::of("i", Json::number(1)),
            @n8n.Item::of("i", Json::number(2)),
            @n8n.Item::of("i", Json::number(3)),
          ]
        }),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("limit"), "Limit", @n8n.Limit(2)))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("end"), "End", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("code"))
    .connect_default(@n8n.NodeId("code"), @n8n.NodeId("limit"))
    .connect_default(@n8n.NodeId("limit"), @n8n.NodeId("end"))
  let result = try! @n8n.execute(wf)
  let items = result.final_outputs.get(@n8n.NodeId("end")).unwrap_or([])
  inspect(items.length(), content="2")
}

///|
test "RemoveFields in workflow" {
  let wf = @n8n.Workflow::new("remove-wf")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set"),
        "Set",
        @n8n.Set([
          { key: "keep", value: Json::number(1) },
          { key: "drop", value: Json::number(2) },
        ]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("rm"),
        "Remove",
        @n8n.RemoveFields(["drop"]),
      ),
    )
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("rm"))
  let result = try! @n8n.execute(wf)
  let items = result.final_outputs.get(@n8n.NodeId("rm")).unwrap_or([])
  inspect(items.length(), content="1")
  inspect(items[0].get("keep"), content="Some(Number(1))")
  inspect(items[0].get("drop"), content="None")
}

///|
test "RenameFields in workflow" {
  let wf = @n8n.Workflow::new("rename-wf")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set"),
        "Set",
        @n8n.Set([{ key: "old", value: Json::string("hello") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("ren"),
        "Rename",
        @n8n.RenameFields([("old", "new")]),
      ),
    )
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("ren"))
  let result = try! @n8n.execute(wf)
  let items = result.final_outputs.get(@n8n.NodeId("ren")).unwrap_or([])
  inspect(items.length(), content="1")
  inspect(items[0].get("old"), content="None")
  inspect(
    items[0].get("new"),
    content=(
      #|Some(String(hello))
    ),
  )
}

///|
test "NodeDef::with_options defaults" {
  let node = @n8n.NodeDef::with_options(@n8n.NodeId("x"), "X", @n8n.NoOp)
  inspect(node.disabled, content="false")
  inspect(node.on_error, content="StopWorkflow")
}

///|
test "ContinueRegularOutput with Code that raises" {
  let wf = @n8n.Workflow::new("raise-continue")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::with_options(
        @n8n.NodeId("code"),
        "Code",
        @n8n.Code(fn(_items) raise { fail("code error") }),
        on_error=@n8n.ContinueRegularOutput,
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("end"), "End", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s"), @n8n.NodeId("code"))
    .connect_default(@n8n.NodeId("code"), @n8n.NodeId("end"))
  let result = try! @n8n.execute(wf)
  // Errors collected but execution continues.
  inspect(result.errors.length(), content="1")
  // End still gets the input (passed through from the errored node).
  let end_items = result.final_outputs.get(@n8n.NodeId("end")).unwrap_or([])
  inspect(end_items.length(), content="1")
}
