// ── Execution order tests ported from workflow-execute.test.ts ──

///|
/// Ported from n8n workflow-execute.test.ts
/// Tests: Simple linear chain execution order
test "n8n/exec: linear chain Start → Set1 → Set2 execution order" {
  let wf = @n8n.Workflow::new("linear-chain")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set1"),
        "Set1",
        @n8n.Set([{ key: "step", value: Json::number(1) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set2"),
        "Set2",
        @n8n.Set([{ key: "step", value: Json::number(2) }]),
      ),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set1"))
    .connect_default(@n8n.NodeId("set1"), @n8n.NodeId("set2"))
  let result = @n8n.execute(wf)
  inspect(result.node_results.length(), content="3")
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
  inspect(
    result.node_results[2].node_id,
    content=(
      #|NodeId("set2")
    ),
  )
  guard result.final_outputs.get(@n8n.NodeId("set2")) is Some(items) else {
    fail("expected output from set2")
  }
  inspect(items[0].get("step"), content="Some(Number(2))")
}

///|
/// Ported from n8n workflow-execute.test.ts
/// Tests: Branching execution with If node
test "n8n/exec: branching Start → Set → If → true/false paths" {
  let wf = @n8n.Workflow::new("branching")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set"),
        "Set",
        @n8n.Set([{ key: "val", value: Json::number(50) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("if"),
        "If",
        @n8n.If({ field: "val", op: @n8n.GreaterThan, value: Json::number(25) }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("true_set"),
        "TrueSet",
        @n8n.Set([{ key: "branch", value: Json::string("true") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("false_set"),
        "FalseSet",
        @n8n.Set([{ key: "branch", value: Json::string("false") }]),
      ),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set"))
    .connect_default(@n8n.NodeId("set"), @n8n.NodeId("if"))
    .connect(@n8n.NodeId("if"), @n8n.PortIndex(0), @n8n.NodeId("true_set"))
    .connect(@n8n.NodeId("if"), @n8n.PortIndex(1), @n8n.NodeId("false_set"))
  let result = @n8n.execute(wf)
  inspect(result.node_results.length(), content="5")
  // val=50 > 25 → true branch gets item
  guard result.final_outputs.get(@n8n.NodeId("true_set")) is Some(true_items) else {
    fail("expected output from true_set")
  }
  inspect(true_items.length(), content="1")
  inspect(
    true_items[0].get("branch"),
    content=(
      #|Some(String("true"))
    ),
  )
  guard result.final_outputs.get(@n8n.NodeId("false_set")) is Some(false_items) else {
    fail("expected output from false_set")
  }
  inspect(false_items.length(), content="0")
}

///|
/// Ported from n8n workflow-execute.test.ts
/// Tests: Diamond pattern - branch then merge
test "n8n/exec: diamond Start → If → {High, Low} → Merge" {
  let wf = @n8n.Workflow::new("diamond")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set_val"),
        "SetVal",
        @n8n.Set([{ key: "val", value: Json::number(100) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("if"),
        "If",
        @n8n.If({ field: "val", op: @n8n.GreaterThan, value: Json::number(50) }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("high"),
        "High",
        @n8n.Set([{ key: "label", value: Json::string("high") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("low"),
        "Low",
        @n8n.Set([{ key: "label", value: Json::string("low") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(@n8n.NodeId("merge"), "Merge", @n8n.Merge(@n8n.Append)),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set_val"))
    .connect_default(@n8n.NodeId("set_val"), @n8n.NodeId("if"))
    .connect(@n8n.NodeId("if"), @n8n.PortIndex(0), @n8n.NodeId("high"))
    .connect(@n8n.NodeId("if"), @n8n.PortIndex(1), @n8n.NodeId("low"))
    .connect_to_input(
      @n8n.NodeId("high"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      0,
    )
    .connect_to_input(
      @n8n.NodeId("low"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      1,
    )
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("merge")) is Some(items) else {
    fail("expected output from merge")
  }
  // val=100 > 50 → high branch; low gets 0 items
  inspect(items.length(), content="1")
  inspect(
    items[0].get("label"),
    content=(
      #|Some(String("high"))
    ),
  )
}

///|
/// Ported from n8n workflow-execute.test.ts
/// Tests: Fan-out pattern
test "n8n/exec: fan-out Start → {NoOp1, NoOp2, NoOp3}" {
  let wf = @n8n.Workflow::new("fan-out")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("noop1"), "NoOp1", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("noop2"), "NoOp2", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("noop3"), "NoOp3", @n8n.NoOp))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("noop1"))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("noop2"))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("noop3"))
  let result = @n8n.execute(wf)
  inspect(result.node_results.length(), content="4")
  for name in ["noop1", "noop2", "noop3"] {
    guard result.final_outputs.get(@n8n.NodeId(name)) is Some(items) else {
      fail("expected output from \{name}")
    }
    inspect(items.length(), content="1")
  }
}

///|
/// Ported from n8n workflow-execute.test.ts
/// Tests: Multiple start nodes converge via merge
test "n8n/exec: multiple start nodes converge via merge" {
  let wf = @n8n.Workflow::new("multi-start")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "Start1", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "Start2", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set1"),
        "Set1",
        @n8n.Set([{ key: "src", value: Json::string("branch1") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set2"),
        "Set2",
        @n8n.Set([{ key: "src", value: Json::string("branch2") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(@n8n.NodeId("merge"), "Merge", @n8n.Merge(@n8n.Append)),
    )
    .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("set1"))
    .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("set2"))
    .connect_to_input(
      @n8n.NodeId("set1"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      0,
    )
    .connect_to_input(
      @n8n.NodeId("set2"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      1,
    )
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("merge")) is Some(items) else {
    fail("expected output from merge")
  }
  inspect(items.length(), content="2")
}

///|
/// Tests: Long chain preserves accumulated data
test "n8n/exec: long chain preserves data through 5 nodes" {
  let wf = @n8n.Workflow::new("long-chain")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("s1"),
        "S1",
        @n8n.Set([{ key: "a", value: Json::number(1) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("s2"),
        "S2",
        @n8n.Set([{ key: "b", value: Json::number(2) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("s3"),
        "S3",
        @n8n.Set([{ key: "c", value: Json::number(3) }]),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("noop"), "End", @n8n.NoOp))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("s1"))
    .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("s2"))
    .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("s3"))
    .connect_default(@n8n.NodeId("s3"), @n8n.NodeId("noop"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("noop")) is Some(items) else {
    fail("expected output from end")
  }
  inspect(items.length(), content="1")
  inspect(items[0].get("a"), content="Some(Number(1))")
  inspect(items[0].get("b"), content="Some(Number(2))")
  inspect(items[0].get("c"), content="Some(Number(3))")
}

///|
/// Ported from n8n: Code generates items, If splits them
test "n8n/exec: Code generates items, If routes them" {
  let wf = @n8n.Workflow::new("code-if-split")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("code"),
        "Generate",
        @n8n.Code(fn(_items) {
          [
            @n8n.Item::from_pairs([
              ("name", Json::string("Alice")),
              ("score", Json::number(90)),
            ]),
            @n8n.Item::from_pairs([
              ("name", Json::string("Bob")),
              ("score", Json::number(40)),
            ]),
            @n8n.Item::from_pairs([
              ("name", Json::string("Carol")),
              ("score", Json::number(75)),
            ]),
          ]
        }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("if"),
        "CheckPass",
        @n8n.If({
          field: "score",
          op: @n8n.GreaterEqual,
          value: Json::number(70),
        }),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("pass"), "Pass", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("fail_node"), "Fail", @n8n.NoOp))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("code"))
    .connect_default(@n8n.NodeId("code"), @n8n.NodeId("if"))
    .connect(@n8n.NodeId("if"), @n8n.PortIndex(0), @n8n.NodeId("pass"))
    .connect(@n8n.NodeId("if"), @n8n.PortIndex(1), @n8n.NodeId("fail_node"))
  let result = @n8n.execute(wf)
  // Alice(90) and Carol(75) pass; Bob(40) fails
  guard result.final_outputs.get(@n8n.NodeId("pass")) is Some(pass_items) else {
    fail("expected output from pass")
  }
  inspect(pass_items.length(), content="2")
  guard result.final_outputs.get(@n8n.NodeId("fail_node")) is Some(fail_items) else {
    fail("expected output from fail_node")
  }
  inspect(fail_items.length(), content="1")
}

// ── Complex integration workflows ──

///|
/// Tests: ETL pipeline pattern (extract → filter → transform → load)
test "n8n/complex: ETL pipeline" {
  let wf = @n8n.Workflow::new("etl")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("extract"),
        "Extract",
        @n8n.Code(fn(_items) {
          [
            @n8n.Item::from_pairs([
              ("name", Json::string("alice")),
              ("age", Json::number(30)),
            ]),
            @n8n.Item::from_pairs([
              ("name", Json::string("bob")),
              ("age", Json::number(17)),
            ]),
            @n8n.Item::from_pairs([
              ("name", Json::string("carol")),
              ("age", Json::number(25)),
            ]),
          ]
        }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("filter"),
        "Filter Adults",
        @n8n.If({ field: "age", op: @n8n.GreaterEqual, value: Json::number(18) }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("transform"),
        "Transform",
        @n8n.Set([{ key: "category", value: Json::string("adult") }]),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("load"), "Load", @n8n.NoOp))
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("extract"))
    .connect_default(@n8n.NodeId("extract"), @n8n.NodeId("filter"))
    .connect(@n8n.NodeId("filter"), @n8n.PortIndex(0), @n8n.NodeId("transform"))
    .connect_default(@n8n.NodeId("transform"), @n8n.NodeId("load"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("load")) is Some(items) else {
    fail("expected output from load")
  }
  // Alice(30) and Carol(25) are adults; Bob(17) filtered out
  inspect(items.length(), content="2")
  inspect(
    items[0].get("category"),
    content=(
      #|Some(String("adult"))
    ),
  )
}

///|
/// Tests: Two branches merge then split again
test "n8n/complex: branch → merge → branch again" {
  let wf = @n8n.Workflow::new("branch-merge-branch")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "S1", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "S2", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("a"),
        "A",
        @n8n.Set([
          { key: "from", value: Json::string("A") },
          { key: "val", value: Json::number(10) },
        ]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("b"),
        "B",
        @n8n.Set([
          { key: "from", value: Json::string("B") },
          { key: "val", value: Json::number(20) },
        ]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(@n8n.NodeId("merge"), "Merge", @n8n.Merge(@n8n.Append)),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("check"),
        "Check",
        @n8n.If({ field: "val", op: @n8n.GreaterThan, value: Json::number(15) }),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("high"), "High", @n8n.NoOp))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("low"), "Low", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("a"))
    .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("b"))
    .connect_to_input(
      @n8n.NodeId("a"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      0,
    )
    .connect_to_input(
      @n8n.NodeId("b"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      1,
    )
    .connect_default(@n8n.NodeId("merge"), @n8n.NodeId("check"))
    .connect(@n8n.NodeId("check"), @n8n.PortIndex(0), @n8n.NodeId("high"))
    .connect(@n8n.NodeId("check"), @n8n.PortIndex(1), @n8n.NodeId("low"))
  let result = @n8n.execute(wf)
  // Merge: [A(val=10), B(val=20)], If(val>15): B→high, A→low
  guard result.final_outputs.get(@n8n.NodeId("high")) is Some(high_items) else {
    fail("expected high output")
  }
  inspect(high_items.length(), content="1")
  inspect(
    high_items[0].get("from"),
    content=(
      #|Some(String("B"))
    ),
  )
  guard result.final_outputs.get(@n8n.NodeId("low")) is Some(low_items) else {
    fail("expected low output")
  }
  inspect(low_items.length(), content="1")
  inspect(
    low_items[0].get("from"),
    content=(
      #|Some(String("A"))
    ),
  )
}

///|
/// Tests: Set node accumulates fields through chain
test "n8n/complex: Set accumulates fields through chain" {
  let wf = @n8n.Workflow::new("accumulate")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("s1"),
        "Set1",
        @n8n.Set([{ key: "first", value: Json::string("hello") }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("s2"),
        "Set2",
        @n8n.Set([{ key: "second", value: Json::number(42) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("s3"),
        "Set3",
        @n8n.Set([{ key: "third", value: Json::boolean(true) }]),
      ),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("s1"))
    .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("s2"))
    .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("s3"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("s3")) is Some(items) else {
    fail("expected output from s3")
  }
  inspect(items.length(), content="1")
  inspect(
    items[0].get("first"),
    content=(
      #|Some(String("hello"))
    ),
  )
  inspect(items[0].get("second"), content="Some(Number(42))")
  inspect(items[0].get("third"), content="Some(True)")
}

///|
/// Tests: Code node can filter items
test "n8n/complex: Code filters even numbers" {
  let wf = @n8n.Workflow::new("code-filter")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("gen"),
        "Generate",
        @n8n.Code(fn(_items) {
          [
            @n8n.Item::of("n", Json::number(1)),
            @n8n.Item::of("n", Json::number(2)),
            @n8n.Item::of("n", Json::number(3)),
            @n8n.Item::of("n", Json::number(4)),
            @n8n.Item::of("n", Json::number(5)),
          ]
        }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("filter"),
        "FilterEvens",
        @n8n.Code(fn(items) {
          items.filter(fn(item) {
            match item.get("n") {
              Some(Number(n, ..)) => n.to_int() % 2 == 0
              _ => false
            }
          })
        }),
      ),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("gen"))
    .connect_default(@n8n.NodeId("gen"), @n8n.NodeId("filter"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("filter")) is Some(items) else {
    fail("expected output from filter")
  }
  inspect(items.length(), content="2")
}

///|
/// Tests: Isolated nodes each execute independently
test "n8n/complex: isolated nodes execute independently" {
  let wf = @n8n.Workflow::new("isolated")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "S1", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "S2", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s3"), "S3", @n8n.Start))
  let result = @n8n.execute(wf)
  inspect(result.node_results.length(), content="3")
  inspect(result.final_outputs.length(), content="3")
}

///|
/// Tests: MergeByPosition in full workflow zips two branches
test "n8n/complex: MergeByPosition zips two branches" {
  let wf = @n8n.Workflow::new("zip-merge")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "S1", @n8n.Start))
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "S2", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("names"),
        "Names",
        @n8n.Code(fn(_items) {
          [
            @n8n.Item::of("name", Json::string("Alice")),
            @n8n.Item::of("name", Json::string("Bob")),
          ]
        }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("scores"),
        "Scores",
        @n8n.Code(fn(_items) {
          [
            @n8n.Item::of("score", Json::number(90)),
            @n8n.Item::of("score", Json::number(75)),
          ]
        }),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("merge"),
        "Merge",
        @n8n.Merge(@n8n.MergeByPosition),
      ),
    )
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("end"), "End", @n8n.NoOp))
    .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("names"))
    .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("scores"))
    .connect_to_input(
      @n8n.NodeId("names"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      0,
    )
    .connect_to_input(
      @n8n.NodeId("scores"),
      @n8n.default_port,
      @n8n.NodeId("merge"),
      1,
    )
    .connect_default(@n8n.NodeId("merge"), @n8n.NodeId("end"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("end")) is Some(items) else {
    fail("expected output from end")
  }
  inspect(items.length(), content="2")
  // Position 0: name=Alice, score=90
  inspect(
    items[0].get("name"),
    content=(
      #|Some(String("Alice"))
    ),
  )
  inspect(items[0].get("score"), content="Some(Number(90))")
  // Position 1: name=Bob, score=75
  inspect(
    items[1].get("name"),
    content=(
      #|Some(String("Bob"))
    ),
  )
  inspect(items[1].get("score"), content="Some(Number(75))")
}

///|
/// Tests: Set node overwriting existing field value
test "n8n/complex: Set overwrites existing field" {
  let wf = @n8n.Workflow::new("overwrite")
    .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set1"),
        "Set1",
        @n8n.Set([{ key: "x", value: Json::number(1) }]),
      ),
    )
    .add_node(
      @n8n.NodeDef::new(
        @n8n.NodeId("set2"),
        "Set2",
        @n8n.Set([{ key: "x", value: Json::number(99) }]),
      ),
    )
    .connect_default(@n8n.NodeId("start"), @n8n.NodeId("set1"))
    .connect_default(@n8n.NodeId("set1"), @n8n.NodeId("set2"))
  let result = @n8n.execute(wf)
  guard result.final_outputs.get(@n8n.NodeId("set2")) is Some(items) else {
    fail("expected output from set2")
  }
  inspect(items[0].get("x"), content="Some(Number(99))")
}
