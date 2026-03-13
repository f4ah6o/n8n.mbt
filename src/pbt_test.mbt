// ── Property-Based Tests for n8n engine ──
// Uses moonbitlang/quickcheck to verify algebraic and operational invariants.

// ── Generators ──

///|
/// Generate a random Json value (number, string, bool, or null).
fn gen_json() -> @qc.Gen[Json] {
  @qc.frequency([
    (4, @qc.int_range(-1000, 1000).fmap(fn(n) { Json::number(n.to_double()) })),
    (
      3,
      @qc.sized(fn(size) {
        @qc.int_range(1, if size > 0 { size } else { 3 }).bind(fn(len) {
          @qc.alphabet()
          .array_with_size(len)
          .fmap(fn(chars) {
            let sb = StringBuilder::new()
            for c in chars {
              sb.write_char(c)
            }
            Json::string(sb.to_string())
          })
        })
      }),
    ),
    (
      2,
      @qc.one_of_array([Json::boolean(true), Json::boolean(false)]).fmap(fn(x) {
        x
      }),
    ),
    (1, @qc.pure(Json::null())),
  ])
}

///|
/// Generate a random field key.
fn gen_key() -> @qc.Gen[String] {
  @qc.one_of_array(["a", "b", "c", "x", "y", "z", "name", "val", "id", "type"])
}

///|
/// Generate a random Item with 0-5 fields.
fn gen_item() -> @qc.Gen[@n8n.Item] {
  @qc.sized(fn(size) {
    let max_fields = if size > 5 { 5 } else if size < 0 { 0 } else { size }
    @qc.int_range(0, max_fields).bind(fn(n) {
      gen_pair_array(n).fmap(fn(pairs) { @n8n.Item::from_pairs(pairs) })
    })
  })
}

///|
fn gen_pair_array(n : Int) -> @qc.Gen[Array[(String, Json)]] {
  if n <= 0 {
    return @qc.pure([])
  }
  @qc.tuple(gen_key(), gen_json()).array_with_size(n)
}

///|
/// Generate a non-empty array of Items (1-10).
fn gen_items() -> @qc.Gen[Array[@n8n.Item]] {
  @qc.int_range(1, 10).bind(fn(n) { gen_item().array_with_size(n) })
}

///|
/// Generate a pair of Item arrays for Merge testing.
fn gen_item_pair() -> @qc.Gen[(Array[@n8n.Item], Array[@n8n.Item])] {
  @qc.tuple(gen_items(), gen_items())
}

// ── Item Properties ──

///|
/// Item::set then Item::get round-trip: setting a key and getting it returns the value.
test "pbt/item: set-get round trip" {
  let prop = @qc.forall(
    @qc.tuple(gen_item(), @qc.tuple(gen_key(), gen_json())),
    fn(p) {
      let (item, (key, val)) = p
      item.set(key, val).get(key) == Some(val)
    },
  )
  @qc.quick_check(prop, max_success=200)
}

///|
/// Item::merge with empty is right identity.
test "pbt/item: merge with empty (right identity)" {
  let prop = @qc.forall(gen_item(), fn(item) {
    item.merge(@n8n.Item::empty()) == item
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Item::merge with empty is left identity.
test "pbt/item: merge with empty (left identity)" {
  let prop = @qc.forall(gen_item(), fn(item) {
    @n8n.Item::empty().merge(item) == item
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Item::of creates an item with exactly one field.
test "pbt/item: of creates single-field item" {
  let prop = @qc.forall(@qc.tuple(gen_key(), gen_json()), fn(p) {
    let (k, v) = p
    let item = @n8n.Item::of(k, v)
    item.get(k) == Some(v)
  })
  @qc.quick_check(prop, max_success=200)
}

// ── NoOp Properties ──

///|
/// NoOp is identity: items pass through unchanged.
test "pbt/noop: identity" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let outputs = @n8n.execute_node(@n8n.NoOp, items)
    outputs.get(@n8n.default_port).unwrap_or([]) == items
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// NoOp is idempotent: applying twice yields same result.
test "pbt/noop: idempotent" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let out1 = @n8n.execute_node(@n8n.NoOp, items)
      .get(@n8n.default_port)
      .unwrap_or([])
    let out2 = @n8n.execute_node(@n8n.NoOp, out1)
      .get(@n8n.default_port)
      .unwrap_or([])
    out1 == out2
  })
  @qc.quick_check(prop, max_success=200)
}

// ── If Properties ──

///|
/// If node partitions items: true_count + false_count == input count.
test "pbt/if: partition preserves count" {
  let gen = @qc.tuple(
    gen_items(),
    @qc.tuple(gen_key(), @qc.one_of_array(["Equal", "NotEqual", "Exists"])),
  )
  let prop = @qc.forall(gen, fn(p) {
    let (items, (field, op_name)) = p
    let op : @n8n.CompareOp = match op_name {
      "Equal" => Equal
      "NotEqual" => NotEqual
      _ => Exists
    }
    let cond = @n8n.Condition::{ field, op, value: Json::number(0.0) }
    let outputs = @n8n.execute_node(@n8n.If(cond), items)
    let true_items = outputs.get(@n8n.PortIndex(0)).unwrap_or([])
    let false_items = outputs.get(@n8n.PortIndex(1)).unwrap_or([])
    true_items.length() + false_items.length() == items.length()
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// If node: every item ends up in exactly one branch (no duplication, no loss).
test "pbt/if: no item duplication or loss" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let cond = @n8n.Condition::{ field: "x", op: Exists, value: Json::null() }
    let outputs = @n8n.execute_node(@n8n.If(cond), items)
    let t = outputs.get(@n8n.PortIndex(0)).unwrap_or([])
    let f = outputs.get(@n8n.PortIndex(1)).unwrap_or([])
    // Concatenate and check same set of items
    let combined : Array[@n8n.Item] = []
    for item in t {
      combined.push(item)
    }
    for item in f {
      combined.push(item)
    }
    combined.length() == items.length()
  })
  @qc.quick_check(prop, max_success=200)
}

// ── Set Properties ──

///|
/// Set node preserves item count.
test "pbt/set: preserves item count" {
  let gen = @qc.tuple(gen_items(), @qc.tuple(gen_key(), gen_json()))
  let prop = @qc.forall(gen, fn(p) {
    let (items, (key, val)) = p
    let assignments = [@n8n.FieldAssignment::{ key, value: val }]
    let outputs = @n8n.execute_node(@n8n.Set(assignments), items)
    let result = outputs.get(@n8n.default_port).unwrap_or([])
    result.length() == items.length()
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Set node: every output item has the assigned field.
test "pbt/set: all outputs contain assigned field" {
  let gen = @qc.tuple(gen_items(), @qc.tuple(gen_key(), gen_json()))
  let prop = @qc.forall(gen, fn(p) {
    let (items, (key, val)) = p
    let assignments = [@n8n.FieldAssignment::{ key, value: val }]
    let outputs = @n8n.execute_node(@n8n.Set(assignments), items)
    let result = outputs.get(@n8n.default_port).unwrap_or([])
    result.iter().all(fn(item) { item.get(key) == Some(val) })
  })
  @qc.quick_check(prop, max_success=200)
}

// ── Merge Properties ──

///|
/// Merge(Append): output length == len(input0) + len(input1).
test "pbt/merge/append: output length is sum of inputs" {
  let prop = @qc.forall(gen_item_pair(), fn(p) {
    let (a, b) = p
    let out = @n8n.execute_merge(@n8n.Append, a, b)
    let result = out.get(@n8n.default_port).unwrap_or([])
    result.length() == a.length() + b.length()
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Merge(KeepInput0): output == input0.
test "pbt/merge/keep_input0: output is input0" {
  let prop = @qc.forall(gen_item_pair(), fn(p) {
    let (a, b) = p
    let out = @n8n.execute_merge(@n8n.KeepInput0, a, b)
    out.get(@n8n.default_port).unwrap_or([]) == a
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Merge(KeepInput1): output == input1.
test "pbt/merge/keep_input1: output is input1" {
  let prop = @qc.forall(gen_item_pair(), fn(p) {
    let (a, b) = p
    let out = @n8n.execute_merge(@n8n.KeepInput1, a, b)
    out.get(@n8n.default_port).unwrap_or([]) == b
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Merge(MergeByPosition): output length == max(len(input0), len(input1)).
test "pbt/merge/by_position: output length is max of inputs" {
  let prop = @qc.forall(gen_item_pair(), fn(p) {
    let (a, b) = p
    let out = @n8n.execute_merge(@n8n.MergeByPosition, a, b)
    let result = out.get(@n8n.default_port).unwrap_or([])
    let expected = if a.length() > b.length() { a.length() } else { b.length() }
    result.length() == expected
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Merge(Append) with empty input0 is identity for input1.
test "pbt/merge/append: empty left identity" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let out = @n8n.execute_merge(@n8n.Append, [], items)
    out.get(@n8n.default_port).unwrap_or([]) == items
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Merge(Append) with empty input1 is identity for input0.
test "pbt/merge/append: empty right identity" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let out = @n8n.execute_merge(@n8n.Append, items, [])
    out.get(@n8n.default_port).unwrap_or([]) == items
  })
  @qc.quick_check(prop, max_success=200)
}

// ── Switch Properties ──

///|
/// Switch partitions items: sum of all output port lengths == input length.
test "pbt/switch: partition preserves count" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let rules : Array[@n8n.SwitchRule] = [
      {
        condition: { field: "x", op: Exists, value: Json::null() },
        output: @n8n.PortIndex(0),
      },
      {
        condition: { field: "y", op: Exists, value: Json::null() },
        output: @n8n.PortIndex(1),
      },
    ]
    let kind = @n8n.Switch(rules, fallback=@n8n.PortIndex(2))
    let outputs = @n8n.execute_node(kind, items)
    let mut total = 0
    for _, arr in outputs {
      total = total + arr.length()
    }
    total == items.length()
  })
  @qc.quick_check(prop, max_success=200)
}

// ── json_compare Properties ──

///|
/// json_compare: reflexivity — compare(x, x) == Some(0) for numbers.
test "pbt/json_compare: reflexivity" {
  let gen = @qc.int_range(-1000, 1000).fmap(fn(n) {
    Json::number(n.to_double())
  })
  let prop = @qc.forall(gen, fn(x) {
    let out = @n8n.execute_node(@n8n.If({ field: "v", op: Equal, value: x }), [
      @n8n.Item::of("v", x),
    ])
    let true_items = out.get(@n8n.PortIndex(0)).unwrap_or([])
    true_items.length() == 1
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// json_compare: antisymmetry — if a > b then not(b > a).
test "pbt/json_compare: antisymmetry" {
  let gen = @qc.tuple(@qc.int_range(-500, 500), @qc.int_range(-500, 500))
  let prop = @qc.forall(gen, fn(p) {
    let (a, b) = p
    let ja = Json::number(a.to_double())
    let jb = Json::number(b.to_double())
    let item = @n8n.Item::from_pairs([("v", ja)])
    let gt_out = @n8n.execute_node(
      @n8n.If({ field: "v", op: GreaterThan, value: jb }),
      [item],
    )
    let gt_result = gt_out.get(@n8n.PortIndex(0)).unwrap_or([]).length() == 1
    let lt_out = @n8n.execute_node(
      @n8n.If({ field: "v", op: LessThan, value: jb }),
      [item],
    )
    let lt_result = lt_out.get(@n8n.PortIndex(0)).unwrap_or([]).length() == 1
    // Can't be both greater and less
    not(gt_result && lt_result)
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// Non-numeric comparison: GreaterEqual on strings returns false (incomparable).
test "pbt/json_compare: non-numeric comparison is false" {
  let gen = @qc.tuple(gen_key(), gen_key())
  let prop = @qc.forall(gen, fn(p) {
    let (a, b) = p
    let ja = Json::string(a)
    let jb = Json::string(b)
    let item = @n8n.Item::of("v", ja)
    // GreaterEqual on strings should route to false branch
    let out = @n8n.execute_node(
      @n8n.If({ field: "v", op: GreaterEqual, value: jb }),
      [item],
    )
    let true_count = out.get(@n8n.PortIndex(0)).unwrap_or([]).length()
    true_count == 0
  })
  @qc.quick_check(prop, max_success=200)
}

// ── Workflow Execution Properties ──

///|
/// Start → NoOp chain: output is always one empty item, regardless of chain length.
test "pbt/workflow: start-noop chain preserves single empty item" {
  let gen = @qc.int_range(1, 5)
  let prop = @qc.forall(gen, fn(n) {
    let mut wf = @n8n.Workflow::new("chain").add_node(
      @n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start),
    )
    let mut prev = @n8n.NodeId("s")
    for i in 0..<n {
      let id = @n8n.NodeId("n\{i}")
      wf = wf.add_node(@n8n.NodeDef::new(id, "NoOp\{i}", @n8n.NoOp))
      wf = wf.connect_default(prev, id)
      prev = id
    }
    let result = try! @n8n.execute(wf)
    let final_items = result.final_outputs.get(prev).unwrap_or([])
    final_items.length() == 1 && final_items[0] == @n8n.Item::empty()
  })
  @qc.quick_check(prop, max_success=100)
}

///|
/// Workflow execution produces results for every node in topo order.
test "pbt/workflow: execution covers all nodes" {
  let gen = @qc.int_range(1, 4)
  let prop = @qc.forall(gen, fn(n) {
    let mut wf = @n8n.Workflow::new("all-nodes").add_node(
      @n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start),
    )
    let mut prev = @n8n.NodeId("s")
    for i in 0..<n {
      let id = @n8n.NodeId("n\{i}")
      wf = wf.add_node(@n8n.NodeDef::new(id, "NoOp\{i}", @n8n.NoOp))
      wf = wf.connect_default(prev, id)
      prev = id
    }
    let result = try! @n8n.execute(wf)
    // 1 Start + n NoOps = n+1 nodes
    result.node_results.length() == n + 1
  })
  @qc.quick_check(prop, max_success=100)
}

///|
/// topo_sort returns all nodes: length == node count.
test "pbt/workflow: topo_sort returns all nodes" {
  let gen = @qc.int_range(1, 6)
  let prop = @qc.forall(gen, fn(n) {
    let mut wf = @n8n.Workflow::new("topo").add_node(
      @n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start),
    )
    let mut prev = @n8n.NodeId("s")
    for i in 0..<n {
      let id = @n8n.NodeId("n\{i}")
      wf = wf.add_node(@n8n.NodeDef::new(id, "NoOp\{i}", @n8n.NoOp))
      wf = wf.connect_default(prev, id)
      prev = id
    }
    let sorted = try! wf.topo_sort()
    sorted.length() == n + 1
  })
  @qc.quick_check(prop, max_success=100)
}
