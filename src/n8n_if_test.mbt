///|
/// Ported from n8n IfV2.number.json
/// Tests: Number equals condition routes items correctly
test "n8n/if: number equals routes matching item to true branch" {
  let items = [
    @n8n.Item::of("count", Json::number(1)),
    @n8n.Item::of("count", Json::number(5)),
    @n8n.Item::of("count", Json::number(12)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "count", op: @n8n.Equal, value: Json::number(1) }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="2")
}

///|
/// Ported from n8n IfV2.number.json
/// Tests: Number greaterThan condition
test "n8n/if: number greaterThan routes items above threshold" {
  let items = [
    @n8n.Item::of("count", Json::number(1)),
    @n8n.Item::of("count", Json::number(5)),
    @n8n.Item::of("count", Json::number(12)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "count", op: @n8n.GreaterThan, value: Json::number(10) }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="2")
}

///|
/// Ported from n8n IfV2.number.json
/// Tests: Number lessThan condition
test "n8n/if: number lessThan routes items below threshold" {
  let items = [
    @n8n.Item::of("price", Json::number(5)),
    @n8n.Item::of("price", Json::number(15)),
    @n8n.Item::of("price", Json::number(25)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "price", op: @n8n.LessThan, value: Json::number(10) }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="2")
}

///|
/// Ported from n8n IfV2.string.json
/// Tests: String contains condition routes matching items
test "n8n/if: string contains routes matching items" {
  let items = [
    @n8n.Item::from_pairs([("email", Json::string("shane@yahoo.com"))]),
    @n8n.Item::from_pairs([("email", Json::string("sharon@yahoo.com"))]),
    @n8n.Item::from_pairs([("email", Json::string("sarah@gmail.com"))]),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "email", op: @n8n.Contains, value: Json::string("yahoo") }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="2")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
/// Ported from n8n IfV2.boolean.json
/// Tests: Boolean equality condition
test "n8n/if: boolean equals true routes correctly" {
  let items = [
    @n8n.Item::of("admin", Json::boolean(false)),
    @n8n.Item::of("admin", Json::boolean(true)),
    @n8n.Item::of("admin", Json::boolean(false)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "admin", op: @n8n.Equal, value: Json::boolean(true) }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="2")
}

///|
/// Ported from n8n IfV2.string.json
/// Tests: String equality exact match
test "n8n/if: string equals exact match" {
  let items = [
    @n8n.Item::of("status", Json::string("active")),
    @n8n.Item::of("status", Json::string("pending")),
    @n8n.Item::of("status", Json::string("active")),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "status", op: @n8n.Equal, value: Json::string("active") }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="2")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
/// Ported from n8n IfV2.other.json
/// Tests: NotExists for missing field
test "n8n/if: notExists when field missing" {
  let items = [
    @n8n.Item::from_pairs([
      ("name", Json::string("Apple")),
      ("tags", Json::string("fruit")),
    ]),
    @n8n.Item::from_pairs([("name", Json::string("Orange"))]),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "tags", op: @n8n.NotExists, value: Json::null() }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
/// Tests: NotEqual routes non-matching items
test "n8n/if: notEqual routes non-matching to true" {
  let items = [
    @n8n.Item::of("color", Json::string("red")),
    @n8n.Item::of("color", Json::string("blue")),
    @n8n.Item::of("color", Json::string("red")),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "color", op: @n8n.NotEqual, value: Json::string("red") }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="2")
}

///|
/// Tests: NotContains operator
test "n8n/if: notContains filters out matching strings" {
  let items = [
    @n8n.Item::of("msg", Json::string("hello world")),
    @n8n.Item::of("msg", Json::string("goodbye")),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "msg", op: @n8n.NotContains, value: Json::string("hello") }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
/// Tests: If with empty input array produces empty outputs
test "n8n/if: empty input produces empty outputs" {
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "x", op: @n8n.Equal, value: Json::number(1) }),
    [],
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="0")
}

///|
/// Tests: If with missing field sends item to false branch
test "n8n/if: missing field sends to false branch" {
  let items = [@n8n.Item::of("y", Json::number(1))]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "x", op: @n8n.Equal, value: Json::number(1) }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="0")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
/// Tests: Null value equality
test "n8n/if: null equals null is true" {
  let items = [@n8n.Item::of("x", Json::null())]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "x", op: @n8n.Equal, value: Json::null() }),
    items,
  )
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="1")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="0")
}

///|
/// Tests: Number boundary — exactly equal to threshold
test "n8n/if: greaterEqual on exact boundary" {
  let items = [
    @n8n.Item::of("val", Json::number(70)),
    @n8n.Item::of("val", Json::number(69)),
    @n8n.Item::of("val", Json::number(71)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "val", op: @n8n.GreaterEqual, value: Json::number(70) }),
    items,
  )
  // 70 and 71 pass, 69 fails
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="2")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}

///|
/// Tests: LessEqual on exact boundary
test "n8n/if: lessEqual on exact boundary" {
  let items = [
    @n8n.Item::of("val", Json::number(10)),
    @n8n.Item::of("val", Json::number(11)),
    @n8n.Item::of("val", Json::number(9)),
  ]
  let outputs = @n8n.execute_node(
    @n8n.If({ field: "val", op: @n8n.LessEqual, value: Json::number(10) }),
    items,
  )
  // 10 and 9 pass, 11 fails
  inspect(outputs.get(@n8n.PortIndex(0)).unwrap_or([]).length(), content="2")
  inspect(outputs.get(@n8n.PortIndex(1)).unwrap_or([]).length(), content="1")
}
