///|
// Tests for new node types: Filter, Limit, RemoveFields, RenameFields

///|
test "Filter: keeps matching items, drops others" {
  let items = [
    @n8n.Item::of("x", Json::number(10)),
    @n8n.Item::of("x", Json::number(20)),
    @n8n.Item::of("y", Json::number(5)),
  ]
  let result = @n8n.execute_node(
    @n8n.Filter({ field: "x", op: @n8n.Exists, value: Json::null() }),
    items,
  )
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out.length(), content="2")
  inspect(out[0].get("x"), content="Some(Number(10))")
  inspect(out[1].get("x"), content="Some(Number(20))")
}

///|
test "Filter: empty input yields empty output" {
  let result = @n8n.execute_node(
    @n8n.Filter({ field: "x", op: @n8n.Exists, value: Json::null() }),
    [],
  )
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out.length(), content="0")
}

///|
test "Limit: keeps only first N items" {
  let items = [
    @n8n.Item::of("i", Json::number(1)),
    @n8n.Item::of("i", Json::number(2)),
    @n8n.Item::of("i", Json::number(3)),
    @n8n.Item::of("i", Json::number(4)),
    @n8n.Item::of("i", Json::number(5)),
  ]
  let result = @n8n.execute_node(@n8n.Limit(3), items)
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out.length(), content="3")
  inspect(out[2].get("i"), content="Some(Number(3))")
}

///|
test "Limit: N larger than input returns all" {
  let items = [@n8n.Item::of("x", Json::number(1))]
  let result = @n8n.execute_node(@n8n.Limit(100), items)
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out.length(), content="1")
}

///|
test "Limit: zero returns empty" {
  let items = [@n8n.Item::of("x", Json::number(1))]
  let result = @n8n.execute_node(@n8n.Limit(0), items)
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out.length(), content="0")
}

///|
test "RemoveFields: removes specified fields" {
  let item = @n8n.Item::from_pairs([
    ("a", Json::number(1)),
    ("b", Json::number(2)),
    ("c", Json::number(3)),
  ])
  let result = @n8n.execute_node(@n8n.RemoveFields(["a", "c"]), [item])
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out.length(), content="1")
  inspect(out[0].get("a"), content="None")
  inspect(out[0].get("b"), content="Some(Number(2))")
  inspect(out[0].get("c"), content="None")
}

///|
test "RemoveFields: removing non-existent field is a no-op" {
  let item = @n8n.Item::of("x", Json::number(1))
  let result = @n8n.execute_node(@n8n.RemoveFields(["z"]), [item])
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out[0].get("x"), content="Some(Number(1))")
}

///|
test "RenameFields: renames specified fields" {
  let item = @n8n.Item::from_pairs([
    ("old_name", Json::string("hello")),
    ("keep", Json::number(42)),
  ])
  let result = @n8n.execute_node(
    @n8n.RenameFields([("old_name", "new_name")]),
    [item],
  )
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out[0].get("old_name"), content="None")
  inspect(
    out[0].get("new_name"),
    content=(
      #|Some(String(hello))
    ),
  )
  inspect(out[0].get("keep"), content="Some(Number(42))")
}

///|
test "RenameFields: renaming non-existent field is a no-op" {
  let item = @n8n.Item::of("x", Json::number(1))
  let result = @n8n.execute_node(@n8n.RenameFields([("missing", "new")]), [item])
  let out = result.get(@n8n.default_port).unwrap_or([])
  inspect(out[0].get("x"), content="Some(Number(1))")
  inspect(out[0].get("missing"), content="None")
  inspect(out[0].get("new"), content="None")
}
