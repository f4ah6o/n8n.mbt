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
/// Generate a random field key from a broad alphabet-based pool.
/// Uses a prefix letter + random suffix to keep collision low while still readable.
fn gen_key() -> @qc.Gen[String] {
  @qc.tuple(@qc.alphabet(), @qc.int_range(0, 99)).fmap(fn(p) {
    let (ch, n) = p
    "\{ch}\{n}"
  })
}

///|
/// Generate a random Item with unique keys and 0-5 fields.
fn gen_item() -> @qc.Gen[@n8n.Item] {
  @qc.sized(fn(size) {
    let max_fields = if size > 5 { 5 } else if size < 0 { 0 } else { size }
    @qc.int_range(0, max_fields).bind(fn(n) {
      gen_unique_pair_array(n).fmap(fn(pairs) { @n8n.Item::from_pairs(pairs) })
    })
  })
}

///|
/// Generate an array of (key, json) pairs with unique keys.
fn gen_unique_pair_array(n : Int) -> @qc.Gen[Array[(String, Json)]] {
  if n <= 0 {
    return @qc.pure([])
  }
  // Generate more candidates than needed, then deduplicate by key.
  let candidate_count = n * 3
  @qc.tuple(gen_key(), gen_json())
  .array_with_size(candidate_count)
  .fmap(fn(raw) {
    let seen : Map[String, Bool] = {}
    let result : Array[(String, Json)] = []
    for pair in raw {
      if result.length() >= n {
        break
      }
      if not(seen.contains(pair.0)) {
        seen[pair.0] = true
        result.push(pair)
      }
    }
    result
  })
}

///|
/// Generate an Item guaranteed to have the given key with a random value.
fn gen_item_with_key(key : String) -> @qc.Gen[@n8n.Item] {
  gen_json().bind(fn(val) { gen_item().fmap(fn(base) { base.set(key, val) }) })
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

///|
/// Multiset equality check: two arrays contain the same items with the same
/// multiplicities, regardless of order. Uses ToJson serialization as item identity.
fn items_multiset_eq(a : Array[@n8n.Item], b : Array[@n8n.Item]) -> Bool {
  if a.length() != b.length() {
    return false
  }
  let counts : Map[String, Int] = {}
  for item in a {
    let key = item.to_json().stringify()
    counts[key] = counts.get(key).unwrap_or(0) + 1
  }
  for item in b {
    let key = item.to_json().stringify()
    let c = counts.get(key).unwrap_or(0)
    if c <= 0 {
      return false
    }
    counts[key] = c - 1
  }
  true
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
/// If node: partition is a multiset-equal split — no duplication, no loss.
/// Concatenating true and false branches yields the exact same multiset as input.
test "pbt/if: multiset partition integrity" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let cond = @n8n.Condition::{ field: "x", op: Exists, value: Json::null() }
    let outputs = @n8n.execute_node(@n8n.If(cond), items)
    let t = outputs.get(@n8n.PortIndex(0)).unwrap_or([])
    let f = outputs.get(@n8n.PortIndex(1)).unwrap_or([])
    let combined : Array[@n8n.Item] = []
    for item in t {
      combined.push(item)
    }
    for item in f {
      combined.push(item)
    }
    items_multiset_eq(combined, items)
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// If node: items with the field present go to true, items without go to false.
/// Verifies placement correctness, not just count.
test "pbt/if: correct branch placement for Exists" {
  let prop = @qc.forall(gen_items(), fn(items) {
    let cond = @n8n.Condition::{ field: "x", op: Exists, value: Json::null() }
    let outputs = @n8n.execute_node(@n8n.If(cond), items)
    let t = outputs.get(@n8n.PortIndex(0)).unwrap_or([])
    let f = outputs.get(@n8n.PortIndex(1)).unwrap_or([])
    let all_true_have_x = t.iter().all(fn(item) { not(item.get("x") is None) })
    let all_false_lack_x = f.iter().all(fn(item) { item.get("x") is None })
    all_true_have_x && all_false_lack_x
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
/// Switch multiset partition: concatenating all output ports yields the original multiset.
test "pbt/switch: multiset partition integrity" {
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
    let combined : Array[@n8n.Item] = []
    for _, arr in outputs {
      for item in arr {
        combined.push(item)
      }
    }
    items_multiset_eq(combined, items)
  })
  @qc.quick_check(prop, max_success=200)
}

// ── json_compare Properties ──

///|
/// json_compare reflexivity: for any number x, x >= x, x <= x, x == x all hold,
/// and x > x, x < x both do not hold.
test "pbt/json_compare: reflexivity (all comparison ops)" {
  let gen = @qc.int_range(-1000, 1000).fmap(fn(n) {
    Json::number(n.to_double())
  })
  let prop = @qc.forall(gen, fn(x) {
    let item = @n8n.Item::of("v", x)
    let check = fn(op : @n8n.CompareOp) -> Bool {
      let out = @n8n.execute_node(@n8n.If({ field: "v", op, value: x }), [item])
      out.get(@n8n.PortIndex(0)).unwrap_or([]).length() == 1
    }
    // x == x, x >= x, x <= x must be true
    // x > x, x < x must be false
    check(Equal) &&
    check(GreaterEqual) &&
    check(LessEqual) &&
    not(check(GreaterThan)) &&
    not(check(LessThan))
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// json_compare antisymmetry: if a > b then !(b > a).
/// Tests the actual implication, not just mutual exclusion of > and <.
test "pbt/json_compare: antisymmetry (a > b implies !(b > a))" {
  let gen = @qc.tuple(@qc.int_range(-500, 500), @qc.int_range(-500, 500))
  let prop = @qc.forall(gen, fn(p) {
    let (a, b) = p
    let ja = Json::number(a.to_double())
    let jb = Json::number(b.to_double())
    let item_a = @n8n.Item::of("v", ja)
    let item_b = @n8n.Item::of("v", jb)
    // Check: a > b?
    let a_gt_out = @n8n.execute_node(
      @n8n.If({ field: "v", op: GreaterThan, value: jb }),
      [item_a],
    )
    let a_gt_b = a_gt_out.get(@n8n.PortIndex(0)).unwrap_or([]).length() == 1
    // Check: b > a?
    let b_gt_out = @n8n.execute_node(
      @n8n.If({ field: "v", op: GreaterThan, value: ja }),
      [item_b],
    )
    let b_gt_a = b_gt_out.get(@n8n.PortIndex(0)).unwrap_or([]).length() == 1
    // If a > b, then b > a must be false
    if a_gt_b {
      not(b_gt_a)
    } else {
      true
    }
  })
  @qc.quick_check(prop, max_success=200)
}

///|
/// json_compare trichotomy: for numbers, exactly one of a < b, a == b, a > b holds.
test "pbt/json_compare: trichotomy for numbers" {
  let gen = @qc.tuple(@qc.int_range(-500, 500), @qc.int_range(-500, 500))
  let prop = @qc.forall(gen, fn(p) {
    let (a, b) = p
    let ja = Json::number(a.to_double())
    let jb = Json::number(b.to_double())
    let item = @n8n.Item::of("v", ja)
    let test_op = fn(op : @n8n.CompareOp) -> Bool {
      let out = @n8n.execute_node(@n8n.If({ field: "v", op, value: jb }), [item])
      out.get(@n8n.PortIndex(0)).unwrap_or([]).length() == 1
    }
    let lt = test_op(LessThan)
    let eq = test_op(Equal)
    let gt = test_op(GreaterThan)
    // Exactly one must be true
    let count = (if lt { 1 } else { 0 }) +
      (if eq { 1 } else { 0 }) +
      (if gt { 1 } else { 0 })
    count == 1
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
    // All ordering ops should route to false branch for strings
    let test_op = fn(op : @n8n.CompareOp) -> Bool {
      let out = @n8n.execute_node(@n8n.If({ field: "v", op, value: jb }), [item])
      out.get(@n8n.PortIndex(0)).unwrap_or([]).length() == 0
    }
    test_op(GreaterThan) &&
    test_op(LessThan) &&
    test_op(GreaterEqual) &&
    test_op(LessEqual)
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
/// Diamond DAG: Start → Set(a) → Merge(Append) ← Set(b) ← Start
///                                      ↓
///                                    NoOp
/// Tests fan-out, merge, and multiple start nodes.
test "pbt/workflow: diamond DAG with merge" {
  let gen = @qc.tuple(gen_key(), gen_key())
  let prop = @qc.forall(gen, fn(p) {
    let (k1, k2) = p
    let wf = @n8n.Workflow::new("diamond")
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "Start1", @n8n.Start))
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "Start2", @n8n.Start))
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("set1"),
          "Set1",
          @n8n.Set([{ key: k1, value: Json::number(1.0) }]),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("set2"),
          "Set2",
          @n8n.Set([{ key: k2, value: Json::number(2.0) }]),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("merge"),
          "Merge",
          @n8n.Merge(@n8n.Append),
        ),
      )
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("out"), "Out", @n8n.NoOp))
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
      .connect_default(@n8n.NodeId("merge"), @n8n.NodeId("out"))
    let result = try! @n8n.execute(wf)
    // Merge(Append) of two Start→Set branches: 2 items at output
    let final_items = result.final_outputs.get(@n8n.NodeId("out")).unwrap_or([])
    let has_correct_count = final_items.length() == 2
    // Each item should have its respective Set field
    let has_k1 = final_items
      .iter()
      .any(fn(i) { i.get(k1) == Some(Json::number(1.0)) })
    let has_k2 = final_items
      .iter()
      .any(fn(i) { i.get(k2) == Some(Json::number(2.0)) })
    has_correct_count && has_k1 && has_k2
  })
  @qc.quick_check(prop, max_success=100)
}

///|
/// Fan-out: Start → Set(field) → If(Exists field) → true/false terminals.
/// Varies the condition field and Set assignments so the If routing changes per sample.
/// The Set guarantees the field exists, so the item always goes to the true branch.
test "pbt/workflow: fan-out via If branching" {
  let gen = @qc.tuple(gen_key(), gen_json())
  let prop = @qc.forall(gen, fn(p) {
    let (field, val) = p
    let wf = @n8n.Workflow::new("fanout")
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("s"), "Start", @n8n.Start))
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("set"),
          "Set",
          @n8n.Set([{ key: field, value: val }]),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("if"),
          "If",
          @n8n.If({ field, op: Exists, value: Json::null() }),
        ),
      )
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("t"), "True", @n8n.NoOp))
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("f"), "False", @n8n.NoOp))
      .connect_default(@n8n.NodeId("s"), @n8n.NodeId("set"))
      .connect_default(@n8n.NodeId("set"), @n8n.NodeId("if"))
      .connect(@n8n.NodeId("if"), @n8n.PortIndex(0), @n8n.NodeId("t"))
      .connect(@n8n.NodeId("if"), @n8n.PortIndex(1), @n8n.NodeId("f"))
    let result = try! @n8n.execute(wf)
    let t_items = result.final_outputs.get(@n8n.NodeId("t")).unwrap_or([])
    let f_items = result.final_outputs.get(@n8n.NodeId("f")).unwrap_or([])
    // Set ensures the field exists, so item goes to true branch
    let true_routed = t_items.length() == 1 && f_items.length() == 0
    // The true-branch item should carry the Set field
    let has_field = t_items.length() == 1 && t_items[0].get(field) == Some(val)
    true_routed && has_field
  })
  @qc.quick_check(prop, max_success=100)
}

///|
/// If → Merge round-trip: split items by condition, then Merge(Append) should
/// recover the original multiset (regardless of which items go true vs false).
test "pbt/workflow: if-split then merge-append recovers all items" {
  let gen = @qc.int_range(1, 8).bind(fn(n) {
    // Generate n items, some with field "x" and some without
    let item_gen = @qc.one_of([gen_item_with_key("x"), gen_item()])
    item_gen.array_with_size(n)
  })
  let prop = @qc.forall(gen, fn(items) {
    // Build: Code(inject items) → If(Exists "x") → true/false → Merge(Append) → Out
    let wf = @n8n.Workflow::new("split-merge")
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("src"),
          "Source",
          @n8n.Code(fn(_input) { items }),
        ),
      )
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("if"),
          "If",
          @n8n.If({ field: "x", op: Exists, value: Json::null() }),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("merge"),
          "Merge",
          @n8n.Merge(@n8n.Append),
        ),
      )
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("out"), "Out", @n8n.NoOp))
      .connect_default(@n8n.NodeId("start"), @n8n.NodeId("src"))
      .connect_default(@n8n.NodeId("src"), @n8n.NodeId("if"))
      .connect_to_input(
        @n8n.NodeId("if"),
        @n8n.PortIndex(0),
        @n8n.NodeId("merge"),
        0,
      )
      .connect_to_input(
        @n8n.NodeId("if"),
        @n8n.PortIndex(1),
        @n8n.NodeId("merge"),
        1,
      )
      .connect_default(@n8n.NodeId("merge"), @n8n.NodeId("out"))
    let result = try! @n8n.execute(wf)
    let final_items = result.final_outputs.get(@n8n.NodeId("out")).unwrap_or([])
    // All items should be recovered after split + merge
    items_multiset_eq(final_items, items)
  })
  @qc.quick_check(prop, max_success=100)
}

///|
/// Multiple start nodes: all start nodes contribute items to a downstream merge.
test "pbt/workflow: multiple start nodes merge" {
  let gen = @qc.int_range(2, 5)
  let prop = @qc.forall(gen, fn(n) {
    let mut wf = @n8n.Workflow::new("multi-start").add_node(
      @n8n.NodeDef::new(@n8n.NodeId("merge"), "Merge", @n8n.Merge(@n8n.Append)),
    )
    // Add n start nodes: s0 and s1 connect to merge input 0 and 1 respectively.
    // Additional starts chain through NoOp nodes into input 0.
    for i in 0..<n {
      let sid = @n8n.NodeId("s\{i}")
      wf = wf.add_node(
        @n8n.NodeDef::new(
          sid,
          "Start\{i}",
          @n8n.Set([{ key: "src", value: Json::number(i.to_double()) }]),
        ),
      )
      let start_id = @n8n.NodeId("start\{i}")
      wf = wf.add_node(@n8n.NodeDef::new(start_id, "RealStart\{i}", @n8n.Start))
      wf = wf.connect_default(start_id, sid)
      if i <= 1 {
        wf = wf.connect_to_input(
          sid,
          @n8n.default_port,
          @n8n.NodeId("merge"),
          i,
        )
      } else {
        // Extra starts: chain into input 0 via the first Set node
        wf = wf.connect_to_input(
          sid,
          @n8n.default_port,
          @n8n.NodeId("merge"),
          0,
        )
      }
    }
    let result = try! @n8n.execute(wf)
    // Each start produces 1 item, so merge should have n items total
    let mut merge_items : Array[@n8n.Item] = []
    for nr in result.node_results {
      if nr.node_id == @n8n.NodeId("merge") {
        merge_items = nr.outputs.get(@n8n.default_port).unwrap_or([])
        break
      }
    }
    merge_items.length() == n
  })
  @qc.quick_check(prop, max_success=100)
}

///|
/// Input index ordering: items from input 0 come before items from input 1
/// for non-Merge nodes that flatten grouped inputs.
test "pbt/workflow: input index ordering for non-Merge nodes" {
  let gen = @qc.tuple(
    @qc.int_range(1, 5).fmap(fn(n) { Json::number(n.to_double()) }),
    @qc.int_range(6, 10).fmap(fn(n) { Json::number(n.to_double()) }),
  )
  let prop = @qc.forall(gen, fn(p) {
    let (v1, v2) = p
    // Two Start→Set branches feeding into a Code node at input 0 and input 1.
    // Code node receives flattened items — input 0 items should come first.
    let wf = @n8n.Workflow::new("order-test")
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("s1"), "S1", @n8n.Start))
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("s2"), "S2", @n8n.Start))
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("set1"),
          "Set1",
          @n8n.Set([{ key: "v", value: v1 }]),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("set2"),
          "Set2",
          @n8n.Set([{ key: "v", value: v2 }]),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("code"),
          "Code",
          @n8n.Code(fn(items) { items }),
        ),
      )
      .connect_default(@n8n.NodeId("s1"), @n8n.NodeId("set1"))
      .connect_default(@n8n.NodeId("s2"), @n8n.NodeId("set2"))
      .connect_to_input(
        @n8n.NodeId("set1"),
        @n8n.default_port,
        @n8n.NodeId("code"),
        0,
      )
      .connect_to_input(
        @n8n.NodeId("set2"),
        @n8n.default_port,
        @n8n.NodeId("code"),
        1,
      )
    let result = try! @n8n.execute(wf)
    let code_items = result.final_outputs.get(@n8n.NodeId("code")).unwrap_or([])
    guard code_items.length() == 2 else { return false }
    // Input 0 (v1) should come before input 1 (v2)
    code_items[0].get("v") == Some(v1) && code_items[1].get("v") == Some(v2)
  })
  @qc.quick_check(prop, max_success=100)
}

///|
/// Switch fan-out into merge: items routed to different switch ports
/// can be merged back to recover the original multiset.
test "pbt/workflow: switch fan-out then merge recovers items" {
  let gen = @qc.int_range(1, 6).bind(fn(n) {
    // Generate items: some with "x", some with "y", some with neither
    let item_gen = @qc.one_of([
      gen_item_with_key("x"),
      gen_item_with_key("y"),
      gen_item(),
    ])
    item_gen.array_with_size(n)
  })
  let prop = @qc.forall(gen, fn(items) {
    // Code(inject) → Switch(x→0, y→1, fallback→0) → Merge(Append) → Out
    let wf = @n8n.Workflow::new("switch-merge")
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("start"), "Start", @n8n.Start))
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("src"),
          "Source",
          @n8n.Code(fn(_input) { items }),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("sw"),
          "Switch",
          @n8n.Switch(
            [
              {
                condition: { field: "x", op: Exists, value: Json::null() },
                output: @n8n.PortIndex(0),
              },
              {
                condition: { field: "y", op: Exists, value: Json::null() },
                output: @n8n.PortIndex(1),
              },
            ],
            fallback=@n8n.PortIndex(0),
          ),
        ),
      )
      .add_node(
        @n8n.NodeDef::new(
          @n8n.NodeId("merge"),
          "Merge",
          @n8n.Merge(@n8n.Append),
        ),
      )
      .add_node(@n8n.NodeDef::new(@n8n.NodeId("out"), "Out", @n8n.NoOp))
      .connect_default(@n8n.NodeId("start"), @n8n.NodeId("src"))
      .connect_default(@n8n.NodeId("src"), @n8n.NodeId("sw"))
      .connect_to_input(
        @n8n.NodeId("sw"),
        @n8n.PortIndex(0),
        @n8n.NodeId("merge"),
        0,
      )
      .connect_to_input(
        @n8n.NodeId("sw"),
        @n8n.PortIndex(1),
        @n8n.NodeId("merge"),
        1,
      )
      .connect_default(@n8n.NodeId("merge"), @n8n.NodeId("out"))
    let result = try! @n8n.execute(wf)
    let final_items = result.final_outputs.get(@n8n.NodeId("out")).unwrap_or([])
    items_multiset_eq(final_items, items)
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
