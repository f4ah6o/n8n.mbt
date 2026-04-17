///|
/// Condition operators for If/Switch node expressions.
pub(all) enum CompareOp {
  Equal
  NotEqual
  GreaterThan
  LessThan
  GreaterEqual
  LessEqual
  Contains
  NotContains
  Exists
  NotExists
} derive(Show, ToJson, Eq)

///|
/// A condition expression for If/Switch nodes.
/// Evaluates a field of each item against a value.
pub(all) struct Condition {
  field : String
  op : CompareOp
  value : Json
} derive(Show, ToJson, Eq)

///|
/// Merge mode: how items from multiple inputs are combined.
pub(all) enum MergeMode {
  /// Append all items from both inputs
  Append
  /// Merge items by position (zip)
  MergeByPosition
  /// Keep items from input 0 only
  KeepInput0
  /// Keep items from input 1 only
  KeepInput1
} derive(Show, ToJson, Eq)

///|
/// A field assignment for the Set node.
pub(all) struct FieldAssignment {
  key : String
  value : Json
} derive(Show, ToJson, Eq)

///|
/// Switch routing rule: condition → output port index.
pub(all) struct SwitchRule {
  condition : Condition
  output : PortIndex
} derive(Show, ToJson, Eq)

///|
/// The kind of node, determining its execution behavior.
/// Each variant carries its configuration parameters.
pub(all) enum NodeKind {
  /// Entry point of the workflow. Emits one empty item.
  Start
  /// Assigns fields on each item.
  Set(Array[FieldAssignment])
  /// Routes items: matching → output 0, non-matching → output 1.
  If(Condition)
  /// Combines items from two inputs.
  Merge(MergeMode)
  /// Applies a user-provided function to the items. May raise errors.
  Code((Array[Item]) -> Array[Item] raise)
  /// Pass-through: forwards items unchanged.
  NoOp
  /// Multi-way conditional routing.
  Switch(Array[SwitchRule], fallback~ : PortIndex)
  /// Filters items: matching items pass through, non-matching are dropped.
  Filter(Condition)
  /// Keeps only the first N items.
  Limit(Int)
  /// Removes the specified fields from each item.
  RemoveFields(Array[String])
  /// Renames fields: Array of (old_name, new_name) pairs.
  RenameFields(Array[(String, String)])
}

///|
/// How to handle errors during node execution. Maps to n8n's onError.
pub(all) enum OnError {
  /// Stop the workflow on error (default).
  StopWorkflow
  /// Continue execution, passing input items through on the regular output.
  ContinueRegularOutput
  /// Continue execution, routing error info to a separate error output.
  ContinueErrorOutput
} derive(Show, ToJson, Eq)

///|
/// A node definition within a workflow.
pub(all) struct NodeDef {
  id : NodeId
  name : String
  kind : NodeKind
  /// Whether this node is disabled (skipped during execution).
  disabled : Bool
  /// Error handling strategy.
  on_error : OnError
} derive(Show)

///|
pub fn NodeDef::new(id : NodeId, name : String, kind : NodeKind) -> NodeDef {
  { id, name, kind, disabled: false, on_error: StopWorkflow }
}

///|
/// Create a node with custom options.
pub fn NodeDef::with_options(
  id : NodeId,
  name : String,
  kind : NodeKind,
  disabled? : Bool = false,
  on_error? : OnError = StopWorkflow,
) -> NodeDef {
  { id, name, kind, disabled, on_error }
}

///|
/// Returns how many output ports this node kind has.
pub fn NodeKind::output_count(self : NodeKind) -> Int {
  match self {
    Start
    | Set(_)
    | Merge(_)
    | Code(_)
    | NoOp
    | Filter(_)
    | Limit(_)
    | RemoveFields(_)
    | RenameFields(_) => 1
    If(_) => 2
    Switch(rules, fallback~) => {
      let PortIndex(fb_idx) = fallback
      let mut max_port = fb_idx
      for rule in rules {
        let PortIndex(idx) = rule.output
        if idx > max_port {
          max_port = idx
        }
      }
      max_port + 1
    }
  }
}
