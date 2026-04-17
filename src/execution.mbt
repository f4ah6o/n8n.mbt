///|
/// Status of a node or workflow execution. Maps to n8n's ExecutionStatus.
pub(all) enum ExecutionStatus {
  /// Not yet started.
  New
  /// Currently executing.
  Running
  /// Completed successfully.
  Success
  /// Completed with error.
  Error
  /// Node was skipped (disabled).
  Skipped
  /// Execution was cancelled.
  Canceled
} derive(Show, ToJson, Eq)

///|
/// Error information captured when a node fails.
pub(all) struct NodeError {
  /// The error message.
  message : String
  /// The node that failed.
  node_id : NodeId
} derive(Show, ToJson, Eq)
