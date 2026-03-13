///|
/// Ported from n8n workflow.append.json
/// Tests: Append merge with 3+3 items produces 6 items
test "n8n/merge: append 3+3 items" {
  let input0 = [
    @n8n.Item::of("id", Json::number(1)),
    @n8n.Item::of("id", Json::number(2)),
    @n8n.Item::of("id", Json::number(3)),
  ]
  let input1 = [
    @n8n.Item::of("id", Json::number(4)),
    @n8n.Item::of("id", Json::number(5)),
    @n8n.Item::of("id", Json::number(6)),
  ]
  let outputs = @n8n.execute_merge(@n8n.Append, input0, input1)
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="6")
  // Verify order: input0 first, then input1
  inspect(items[0].get("id"), content="Some(Number(1))")
  inspect(items[3].get("id"), content="Some(Number(4))")
  inspect(items[5].get("id"), content="Some(Number(6))")
}

///|
/// Ported from n8n workflow.combine.mergeByPosition.json
/// Tests: MergeByPosition with unequal lengths (2 vs 3)
test "n8n/merge: mergeByPosition with unequal lengths" {
  let input0 = [
    @n8n.Item::from_pairs([("id", Json::number(1)), ("data", Json::string("a"))]),
    @n8n.Item::from_pairs([("id", Json::number(2)), ("data", Json::string("b"))]),
  ]
  let input1 = [
    @n8n.Item::from_pairs([
      ("id", Json::number(10)),
      ("data", Json::string("c")),
    ]),
    @n8n.Item::from_pairs([
      ("id", Json::number(20)),
      ("data", Json::string("d")),
    ]),
    @n8n.Item::from_pairs([
      ("id", Json::number(30)),
      ("data", Json::string("e")),
    ]),
  ]
  let outputs = @n8n.execute_merge(@n8n.MergeByPosition, input0, input1)
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  // Max length is 3: 2 merged + 1 from input1 only
  inspect(items.length(), content="3")
  // Position 0: merged (input1 overrides common fields)
  inspect(items[0].get("id"), content="Some(Number(10))")
  inspect(
    items[0].get("data"),
    content=(
      #|Some(String("c"))
    ),
  )
  // Position 1: merged
  inspect(items[1].get("id"), content="Some(Number(20))")
  // Position 2: only input1 (input0 shorter)
  inspect(items[2].get("id"), content="Some(Number(30))")
  inspect(
    items[2].get("data"),
    content=(
      #|Some(String("e"))
    ),
  )
}

///|
/// Ported from n8n workflow.combine.mergeByPosition.json — preferInput1
/// Tests: MergeByPosition with overlapping keys (input1 overrides)
test "n8n/merge: mergeByPosition overlapping keys" {
  let input0 = [
    @n8n.Item::from_pairs([
      ("id", Json::number(1)),
      ("value", Json::string("old")),
    ]),
  ]
  let input1 = [
    @n8n.Item::from_pairs([
      ("id", Json::number(1)),
      ("value", Json::string("new")),
      ("extra", Json::boolean(true)),
    ]),
  ]
  let outputs = @n8n.execute_merge(@n8n.MergeByPosition, input0, input1)
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="1")
  // input1's value overrides input0's
  inspect(
    items[0].get("value"),
    content=(
      #|Some(String("new"))
    ),
  )
  // input1's extra field is included
  inspect(items[0].get("extra"), content="Some(True)")
}

///|
/// Ported from n8n workflow.chooseBranch.json (output=input1)
/// Tests: KeepInput0 with 3+3 items keeps only input0
test "n8n/merge: keepInput0 with 3+3 items" {
  let input0 = [
    @n8n.Item::of("id", Json::number(1)),
    @n8n.Item::of("id", Json::number(2)),
    @n8n.Item::of("id", Json::number(3)),
  ]
  let input1 = [
    @n8n.Item::of("id", Json::number(4)),
    @n8n.Item::of("id", Json::number(5)),
    @n8n.Item::of("id", Json::number(6)),
  ]
  let outputs = @n8n.execute_merge(@n8n.KeepInput0, input0, input1)
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="3")
  inspect(items[0].get("id"), content="Some(Number(1))")
  inspect(items[2].get("id"), content="Some(Number(3))")
}

///|
/// Ported from n8n workflow.chooseBranch.json (output=input2)
/// Tests: KeepInput1 with 3+3 items keeps only input1
test "n8n/merge: keepInput1 with 3+3 items" {
  let input0 = [
    @n8n.Item::of("id", Json::number(1)),
    @n8n.Item::of("id", Json::number(2)),
    @n8n.Item::of("id", Json::number(3)),
  ]
  let input1 = [
    @n8n.Item::of("id", Json::number(4)),
    @n8n.Item::of("id", Json::number(5)),
    @n8n.Item::of("id", Json::number(6)),
  ]
  let outputs = @n8n.execute_merge(@n8n.KeepInput1, input0, input1)
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="3")
  inspect(items[0].get("id"), content="Some(Number(4))")
  inspect(items[2].get("id"), content="Some(Number(6))")
}

///|
/// Tests: Append with empty input0
test "n8n/merge: append with empty input0" {
  let input1 = [
    @n8n.Item::of("id", Json::number(1)),
    @n8n.Item::of("id", Json::number(2)),
  ]
  let outputs = @n8n.execute_merge(@n8n.Append, [], input1)
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="2")
}

///|
/// Tests: Append with empty input1
test "n8n/merge: append with empty input1" {
  let input0 = [@n8n.Item::of("id", Json::number(1))]
  let outputs = @n8n.execute_merge(@n8n.Append, input0, [])
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="1")
}

///|
/// Tests: MergeByPosition with empty input1 passes through input0
test "n8n/merge: mergeByPosition with empty input1" {
  let input0 = [
    @n8n.Item::of("x", Json::number(1)),
    @n8n.Item::of("x", Json::number(2)),
  ]
  let outputs = @n8n.execute_merge(@n8n.MergeByPosition, input0, [])
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="2")
  inspect(items[0].get("x"), content="Some(Number(1))")
}

///|
/// Tests: Both inputs empty
test "n8n/merge: append with both inputs empty" {
  let outputs = @n8n.execute_merge(@n8n.Append, [], [])
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="0")
}

///|
/// Tests: MergeByPosition with disjoint fields
test "n8n/merge: mergeByPosition with disjoint fields" {
  let input0 = [
    @n8n.Item::of("name", Json::string("Alice")),
    @n8n.Item::of("name", Json::string("Bob")),
  ]
  let input1 = [
    @n8n.Item::of("score", Json::number(90)),
    @n8n.Item::of("score", Json::number(75)),
  ]
  let outputs = @n8n.execute_merge(@n8n.MergeByPosition, input0, input1)
  let items = outputs.get(@n8n.default_port).unwrap_or([])
  inspect(items.length(), content="2")
  inspect(
    items[0].get("name"),
    content=(
      #|Some(String("Alice"))
    ),
  )
  inspect(items[0].get("score"), content="Some(Number(90))")
  inspect(
    items[1].get("name"),
    content=(
      #|Some(String("Bob"))
    ),
  )
  inspect(items[1].get("score"), content="Some(Number(75))")
}
