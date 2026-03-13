///|
/// Tests: Switch routes each item to first matching rule
test "n8n/switch: routes to first matching rule only" {
  let items = [
    @n8n.Item::of("type", Json::string("A")),
    @n8n.Item::of("type", Json::string("B")),
    @n8n.Item::of("type", Json::string("C")),
    @n8n.Item::of("type", Json::string("D")),
  ]
  let outputs = @n8n.execute_node(
    @n8n.Switch(
      [
        {
          condition: { field: "type", op: @n8n.Equal, value: Json::string("A") },
          output: @n8n.PortIndex(0),
        },
        {
          condition: { field: "type", op: @n8n.Equal, value: Json::string("B") },
          output: @n8n.PortIndex(1),
        },
        {
          condition: { field: "type", op: @n8n.Equal, value: Json::string("C") },
          output: @n8n.PortIndex(2),
        },
      ],
      fallback=@n8n.PortIndex(3),
    ),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(2)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(3)).unwrap_or([]).length(), content="1")
}

///|
/// Tests: Switch fallback receives all unmatched items
test "n8n/switch: all unmatched go to fallback" {
  let items = [
    @n8n.Item::of("val", Json::number(100)),
    @n8n.Item::of("val", Json::number(200)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.Switch(
      [
        {
          condition: { field: "val", op: @n8n.Equal, value: Json::number(1) },
          output: @n8n.PortIndex(0),
        },
      ],
      fallback=@n8n.PortIndex(1),
    ),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="2")
}

///|
/// Tests: Switch with empty input
test "n8n/switch: empty input produces empty outputs" {
  let outputs = @n8n.execute_node(
    @n8n.Switch(
      [
        {
          condition: { field: "x", op: @n8n.Equal, value: Json::number(1) },
          output: @n8n.PortIndex(0),
        },
      ],
      fallback=@n8n.PortIndex(1),
    ),
    [],
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="0")
}

///|
/// Tests: Switch first rule wins when multiple could match
test "n8n/switch: first matching rule wins" {
  let items = [
    @n8n.Item::from_pairs([("x", Json::number(5)), ("y", Json::number(10))]),
  ]
  let outputs = @n8n.execute_node(
    @n8n.Switch(
      [
        {
          condition: { field: "x", op: @n8n.Equal, value: Json::number(5) },
          output: @n8n.PortIndex(0),
        },
        {
          condition: { field: "y", op: @n8n.Equal, value: Json::number(10) },
          output: @n8n.PortIndex(1),
        },
      ],
      fallback=@n8n.PortIndex(2),
    ),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(2)).unwrap_or([]).length(), content="0")
}

///|
/// Tests: Switch with numeric range conditions
test "n8n/switch: numeric range routing" {
  let items = [
    @n8n.Item::of("score", Json::number(95)),
    @n8n.Item::of("score", Json::number(75)),
    @n8n.Item::of("score", Json::number(45)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.Switch(
      [
        {
          condition: {
            field: "score",
            op: @n8n.GreaterThan,
            value: Json::number(90),
          },
          output: @n8n.PortIndex(0),
        },
        {
          condition: {
            field: "score",
            op: @n8n.GreaterThan,
            value: Json::number(60),
          },
          output: @n8n.PortIndex(1),
        },
      ],
      fallback=@n8n.PortIndex(2),
    ),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(2)).unwrap_or([]).length(), content="1")
}

///|
/// Tests: Switch in full workflow with downstream nodes
test "n8n/switch: workflow with 3-way priority routing" {
  let wf = @n8n.Workflow::new("switch-routing")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("code"),
        "Data",
        @n8n.Code(fn(_items) {
          [
            @n8n.Item::of("priority", Json::string("high")),
            @n8n.Item::of("priority", Json::string("medium")),
            @n8n.Item::of("priority", Json::string("low")),
            @n8n.Item::of("priority", Json::string("unknown")),
          ]
        }),
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
                field: "priority",
                op: @n8n.Equal,
                value: Json::string("high"),
              },
              output: @n8n.PortIndex(0),
            },
            {
              condition: {
                field: "priority",
                op: @n8n.Equal,
                value: Json::string("medium"),
              },
              output: @n8n.PortIndex(1),
            },
            {
              condition: {
                field: "priority",
                op: @n8n.Equal,
                value: Json::string("low"),
              },
              output: @n8n.PortIndex(2),
            },
          ],
          fallback=@n8n.PortIndex(3),
        ),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("high"),
        "High",
        @n8n.Set([{ key: "handled", value: Json::string("urgent") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("medium"),
        "Medium",
        @n8n.Set([{ key: "handled", value: Json::string("normal") }]),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("low"), "Low", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("other"), "Other", @n8n.NoOp))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("code"))
    .connect_default(@n8n.NodeId("code"), @n8n.NodeId("switch"))
    .connect(@n8n.NodeId("switch"), @n8n.PortIndex(0), @n8n.NodeId("high"))
    .connect(@n8n.NodeId("switch"), @n8n.PortIndex(1), @n8n.NodeId("medium"))
    .connect(@n8n.NodeId("switch"), @n8n.PortIndex(2), @n8n.NodeId("low"))
    .connect(@n8n.NodeId("switch"), @n8n.PortIndex(3), @n8n.NodeId("other"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("high")) is Some(high_items) else {
    fail("expected high output")
  }
  inspect(high_items.length(), content="1")
  inspect(
    high_items[0].get("handled"),
    content=(
      #|Some(String("urgent"))
    ),
  )
  guard result.final_outputs.get(@n8n.NodeId("medium")) is Some(med_items) else {
    fail("expected medium output")
  }
  inspect(med_items.length(), content="1")
  inspect(
    med_items[0].get("handled"),
    content=(
      #|Some(String("normal"))
    ),
  )
  guard result.final_outputs.get(@n8n.NodeId("low")) is Some(low_items) else {
    fail("expected low output")
  }
  inspect(low_items.length(), content="1")
  guard result.final_outputs.get(@n8n.NodeId("other")) is Some(other_items) else {
    fail("expected other output")
  }
  inspect(other_items.length(), content="1")
}

///|
/// Tests: Switch with Contains operator for string matching
test "n8n/switch: string contains routing" {
  let items = [
    @n8n.Item::of("url", Json::string("https://api.example.com/users")),
    @n8n.Item::of("url", Json::string("https://api.example.com/orders")),
    @n8n.Item::of("url", Json::string("https://other.com/data")),
  ]
  let outputs = @n8n.execute_node(
    @n8n.Switch(
      [
        {
          condition: {
            field: "url",
            op: @n8n.Contains,
            value: Json::string("/users"),
          },
          output: @n8n.PortIndex(0),
        },
        {
          condition: {
            field: "url",
            op: @n8n.Contains,
            value: Json::string("/orders"),
          },
          output: @n8n.PortIndex(1),
        },
      ],
      fallback=@n8n.PortIndex(2),
    ),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(2)).unwrap_or([]).length(), content="1")
}
