///|
/// Show implementation for NodeKind (cannot auto-derive due to function type).
pub impl Show for NodeKind with output(self, logger) {
  match self {
    Start => logger.write_string("Start")
    Set(assignments) => {
      logger.write_string("Set(")
      assignments.output(logger)
      logger.write_string(")")
    }
    If(cond) => {
      logger.write_string("If(")
      cond.output(logger)
      logger.write_string(")")
    }
    Merge(mode) => {
      logger.write_string("Merge(")
      mode.output(logger)
      logger.write_string(")")
    }
    Code(_) => logger.write_string("Code(<fn>)")
    NoOp => logger.write_string("NoOp")
    Switch(rules, fallback~) => {
      logger.write_string("Switch(")
      rules.output(logger)
      logger.write_string(", fallback=")
      fallback.output(logger)
      logger.write_string(")")
    }
  }
}
