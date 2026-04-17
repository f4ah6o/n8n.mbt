///|
/// Evaluate a condition against a JSON value.
fn evaluate_condition(cond : Condition, item : Item) -> Bool {
  let field_val = item.get(cond.field)
  match cond.op {
    Exists => not(field_val is None)
    NotExists => field_val is None
    _ => {
      guard field_val is Some(actual) else { return false }
      compare_json(cond.op, actual, cond.value)
    }
  }
}

///|
/// Compare two Json values with the given operator.
fn compare_json(op : CompareOp, actual : Json, expected : Json) -> Bool {
  match op {
    Equal => json_eq(actual, expected)
    NotEqual => not(json_eq(actual, expected))
    Contains => json_contains(actual, expected)
    NotContains => not(json_contains(actual, expected))
    GreaterThan => json_compare(actual, expected) is Some(v) && v > 0
    LessThan => json_compare(actual, expected) is Some(v) && v < 0
    GreaterEqual => json_compare(actual, expected) is Some(v) && v >= 0
    LessEqual => json_compare(actual, expected) is Some(v) && v <= 0
    Exists | NotExists => true // handled above
  }
}

///|
/// Check structural equality of two Json values.
fn json_eq(a : Json, b : Json) -> Bool {
  match (a, b) {
    (Null, Null) => true
    (True, True) => true
    (False, False) => true
    (Number(x, ..), Number(y, ..)) => x == y
    (String(x), String(y)) => x == y
    _ => false
  }
}

///|
/// Check if a string value contains another string.
fn json_contains(haystack : Json, needle : Json) -> Bool {
  match (haystack, needle) {
    (String(h), String(n)) => h.contains(n)
    _ => false
  }
}

///|
/// Numeric comparison of two Json values.
/// Returns None if the values are not both numbers (incomparable).
fn json_compare(a : Json, b : Json) -> Int? {
  match (a, b) {
    (Number(x, ..), Number(y, ..)) =>
      if x < y {
        Some(-1)
      } else if x > y {
        Some(1)
      } else {
        Some(0)
      }
    _ => None
  }
}

///|
/// Execute a single node given its kind and input items.
/// Returns a map of output port index → items.
pub fn execute_node(
  kind : NodeKind,
  inputs : Array[Item],
) -> Map[PortIndex, Array[Item]] raise {
  let outputs : Map[PortIndex, Array[Item]] = {}
  match kind {
    Start => outputs[default_port] = [Item::empty()]
    Set(assignments) => {
      let result : Array[Item] = []
      for item in inputs {
        let mut current = item
        for assignment in assignments {
          current = current.set(assignment.key, assignment.value)
        }
        result.push(current)
      }
      outputs[default_port] = result
    }
    If(condition) => {
      let true_items : Array[Item] = []
      let false_items : Array[Item] = []
      for item in inputs {
        if evaluate_condition(condition, item) {
          true_items.push(item)
        } else {
          false_items.push(item)
        }
      }
      outputs[PortIndex(0)] = true_items
      outputs[PortIndex(1)] = false_items
    }
    Merge(_) =>
      abort(
        "execute_node() does not support Merge; use execute_merge() instead",
      )
    Code(func) => outputs[default_port] = func(inputs)
    NoOp => outputs[default_port] = inputs
    Filter(condition) => {
      let result : Array[Item] = []
      for item in inputs {
        if evaluate_condition(condition, item) {
          result.push(item)
        }
      }
      outputs[default_port] = result
    }
    Limit(n) => {
      let result : Array[Item] = []
      let limit = if n < inputs.length() { n } else { inputs.length() }
      for i in 0..<limit {
        result.push(inputs[i])
      }
      outputs[default_port] = result
    }
    RemoveFields(fields) => {
      let result : Array[Item] = []
      for item in inputs {
        let json : Map[String, Json] = {}
        for k, v in item.json {
          let mut should_remove = false
          for f in fields {
            if k == f {
              should_remove = true
              break
            }
          }
          if not(should_remove) {
            json[k] = v
          }
        }
        result.push({ json, })
      }
      outputs[default_port] = result
    }
    RenameFields(pairs) => {
      let result : Array[Item] = []
      for item in inputs {
        let json : Map[String, Json] = {}
        for k, v in item.json {
          let mut new_key = k
          for pair in pairs {
            if k == pair.0 {
              new_key = pair.1
              break
            }
          }
          json[new_key] = v
        }
        result.push({ json, })
      }
      outputs[default_port] = result
    }
    Switch(rules, fallback~) => {
      // Initialize output arrays
      let max_port = kind.output_count()
      for i in 0..<max_port {
        outputs[PortIndex(i)] = []
      }
      for item in inputs {
        let mut matched = false
        for rule in rules {
          if evaluate_condition(rule.condition, item) {
            let arr = outputs.get(rule.output).unwrap_or([])
            arr.push(item)
            outputs[rule.output] = arr
            matched = true
            break
          }
        }
        if not(matched) {
          let arr = outputs.get(fallback).unwrap_or([])
          arr.push(item)
          outputs[fallback] = arr
        }
      }
    }
  }
  outputs
}

///|
/// Execute a Merge node with grouped inputs from input 0 and input 1.
/// This is called by the engine instead of execute_node for Merge nodes.
pub fn execute_merge(
  mode : MergeMode,
  input0 : Array[Item],
  input1 : Array[Item],
) -> Map[PortIndex, Array[Item]] {
  let outputs : Map[PortIndex, Array[Item]] = {}
  outputs[default_port] = match mode {
    Append => {
      let result : Array[Item] = []
      for item in input0 {
        result.push(item)
      }
      for item in input1 {
        result.push(item)
      }
      result
    }
    KeepInput0 => input0
    KeepInput1 => input1
    MergeByPosition => {
      // Zip items by position: merge fields of input0[i] with input1[i].
      // If one input is shorter, remaining items from the longer input pass through.
      let result : Array[Item] = []
      let max_len = if input0.length() > input1.length() {
        input0.length()
      } else {
        input1.length()
      }
      for i in 0..<max_len {
        if i < input0.length() && i < input1.length() {
          result.push(input0[i].merge(input1[i]))
        } else if i < input0.length() {
          result.push(input0[i])
        } else {
          result.push(input1[i])
        }
      }
      result
    }
  }
  outputs
}
