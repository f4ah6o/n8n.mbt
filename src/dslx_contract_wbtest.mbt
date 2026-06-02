///|
fn dslx_n8n_contract_spec() -> @dslx.Dslx {
  @dslx.n8nx()
}

///|
fn dslx_n8n_contract_example() -> @dslx.File {
  @dslx.file(
    "examples/n8n-workflow.dsl",
    "workflow Sync step Pull http Pull => Push",
  )
}

///|
fn dslx_n8n_contract_project() -> @dslx.Proj {
  @dslx.proj("n8n-contract")
  .dslx(dslx_n8n_contract_spec())
  .file(@dslx.file("README.md", "# n8n contract\n"))
  .exmp(dslx_n8n_contract_example())
}

///|
test "dslx n8n contract describes private project" {
  let spec = dslx_n8n_contract_spec()
  let project = dslx_n8n_contract_project()
  inspect(@dslx.name(spec), content="N8nx")
  inspect(@dslx.vspc(spec).length(), content="0")
  inspect(@dslx.vprj(project).length(), content="0")
  let files = @dslx.pack(project)
  inspect(files.length(), content="6")
  inspect(files[0].path, content="README.md")
  inspect(files[1].path, content="examples/n8n-workflow.dsl")
  inspect(files[2].path, content="N8nx/astx.mbt")
}

///|
test "dslx n8n contract checks examples through project" {
  let project = dslx_n8n_contract_project()
  let example = dslx_n8n_contract_example()
  let parsed = @dslx.runp(project, "N8nx", "n8nw", example.text)
  inspect(parsed.done, content="true")
  inspect(parsed.digs.length(), content="0")
  inspect(@dslx.chex(project, "N8nx", "n8nw", example).length(), content="0")
}

///|
test "dslx n8n contract reports missing spec and invalid example" {
  let project = dslx_n8n_contract_project()
  let example = dslx_n8n_contract_example()
  let missing = @dslx.runp(project, "Missing", "n8nw", example.text)
  inspect(missing.done, content="false")
  inspect(missing.tree is None, content="true")
  inspect(missing.digs.length(), content="1")
  inspect(missing.digs[0].text, content="unknown project spec")

  let invalid = @dslx.file("examples/invalid-n8n.dsl", "workflow")
  let invalid_diags = @dslx.chex(project, "N8nx", "n8nw", invalid)
  inspect(invalid_diags.length(), content="1")
  inspect(invalid_diags[0].text, content="expected pattern")
}
