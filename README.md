# Dispatch::Tools::Interface

A Ruby gem that provides a structured interface for defining, validating, and executing tool definitions. Tools are defined with JSON Schema parameter validation (via [json_schemer](https://github.com/davishmcclurg/json_schemer)) and organized in a registry for lookup and execution.

Designed as a building block for systems that expose callable tools — such as AI agent frameworks, plugin architectures, or RPC-style APIs.

### Core Components

| Class | Purpose |
|---|---|
| `Dispatch::Tools::Definition` | Defines a single tool: name, description, JSON Schema parameters, and an execution block |
| `Dispatch::Tools::Registry` | Stores and retrieves tool definitions by name |
| `Dispatch::Tools::Result` | Immutable value object representing success or failure of a tool call |

---

### Installation

Add to your Gemfile:

```ruby
gem "dispatch-tools-interface"
```

Then run:

```bash
bundle install
```

Or install directly:

```bash
gem install dispatch-tools-interface
```

---

### Usage

#### Defining a Tool

Create a `Definition` with a name, description, a JSON Schema hash for parameters, and a block that receives validated params and an optional context hash:

```ruby
read_file = Dispatch::Tools::Definition.new(
  name: "read_file",
  description: "Read the contents of a file",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string", description: "File path" },
      start_line: { type: "integer", description: "Start line (0-based)" },
      end_line: { type: "integer", description: "End line (0-based, -1 for EOF)" }
    },
    required: ["path"]
  }
) do |params, context|
  content = File.read(params[:path])
  Dispatch::Tools::Result.success(output: content)
end
```

#### Calling a Tool

Pass a params hash (string or symbol keys) and an optional `context` keyword argument. Parameters are validated against the JSON Schema before the block executes. If validation fails, a `Result.failure` is returned — the block is never called. Exceptions raised inside the block are caught and wrapped in a failure result.

```ruby
result = read_file.call({ path: "src/main.rb" })

result.success?  # => true
result.output    # => "contents of src/main.rb"
result.to_s      # => "contents of src/main.rb"

# With context
result = read_file.call({ path: "src/main.rb" }, context: { worktree_path: "/tmp/work" })

# Validation failure
result = read_file.call({})  # missing required "path"
result.failure?  # => true
result.error     # => "Parameter validation failed: ..."
```

#### Working with Results

`Result` is an immutable (frozen) value object with two factory methods:

```ruby
success = Dispatch::Tools::Result.success(output: "done", metadata: { elapsed: 0.3 })
success.success?   # => true
success.output     # => "done"
success.metadata   # => { elapsed: 0.3 }
success.to_h       # => { success: true, output: "done", error: nil, metadata: { elapsed: 0.3 } }

failure = Dispatch::Tools::Result.failure(error: "File not found")
failure.failure?   # => true
failure.error      # => "File not found"
failure.to_s       # => "File not found"
```

#### Using the Registry

The `Registry` stores tool definitions by name and supports lookup, listing, and subsetting:

```ruby
registry = Dispatch::Tools::Registry.new

registry.register(read_file)
registry.register(write_file)
registry.register(delete_file)

# Lookup
tool = registry.get("read_file")
result = tool.call({ path: "README.md" })

# Query
registry.has?("read_file")  # => true
registry.tool_names         # => ["read_file", "write_file", "delete_file"]
registry.size               # => 3
registry.empty?             # => false

# Export all definitions as an array of hashes
registry.to_a
# => [{ name: "read_file", description: "...", parameters: { ... } }, ...]

# Create a subset registry with only specific tools
subset = registry.subset("read_file", "write_file")
subset.tool_names  # => ["read_file", "write_file"]
```

Registration is chainable:

```ruby
registry.register(tool_a).register(tool_b).register(tool_c)
```

#### Error Handling

All custom errors inherit from `Dispatch::Tools::Error`:

| Error | Raised when |
|---|---|
| `DuplicateToolError` | Registering a tool with a name that already exists |
| `ToolNotFoundError` | Calling `Registry#get` or `Registry#subset` with an unknown name |
| `ValidationError` | Available for custom validation logic |
| `ExecutionError` | Available for custom execution error handling |

---

### Development

After checking out the repo, run `bin/setup` to install dependencies. Then run the test suite:

```bash
bundle exec rake spec
```

Use `bin/console` for an interactive prompt to experiment with the library.

---

### License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
