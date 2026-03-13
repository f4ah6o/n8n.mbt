///|
test "Item::empty creates item with no fields" {
  let item = @n8n.Item::empty()
  inspect(item.json.length(), content="0")
}

///|
test "Item::of creates single-field item" {
  let item = @n8n.Item::of("name", Json::string("alice"))
  inspect(
    item.get("name"),
    content=(
      #|Some(String("alice"))
    ),
  )
}

///|
test "Item::from_pairs creates multi-field item" {
  let item = @n8n.Item::from_pairs([
    ("x", Json::number(1)),
    ("y", Json::number(2)),
  ])
  inspect(item.get("x"), content="Some(Number(1))")
  inspect(item.get("y"), content="Some(Number(2))")
}

///|
test "Item::set returns new item with added field" {
  let item = @n8n.Item::of("a", Json::number(1))
  let updated = item.set("b", Json::number(2))
  inspect(updated.get("a"), content="Some(Number(1))")
  inspect(updated.get("b"), content="Some(Number(2))")
  // Original is unchanged
  inspect(item.get("b"), content="None")
}

///|
test "Item::merge combines fields from two items" {
  let a = @n8n.Item::from_pairs([("x", Json::number(1)), ("y", Json::number(2))])
  let b = @n8n.Item::from_pairs([
    ("y", Json::number(99)),
    ("z", Json::number(3)),
  ])
  let merged = a.merge(b)
  inspect(merged.get("x"), content="Some(Number(1))")
  inspect(merged.get("y"), content="Some(Number(99))") // b takes priority
  inspect(merged.get("z"), content="Some(Number(3))")
}
