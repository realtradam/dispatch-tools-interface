# Dispatch Tools Interface — Gem Implementation Plan

This plan covers the full implementation of the `dispatch-tools-interface` gem.

> **Canonical interface:** See `dispatch-tools-interface-plan.md` in the project root for the finalized, comprehensive interface specification. This plan must conform to that interface.

---

## Overview

This gem provides the framework for defining, registering, and executing AI tools. It is a dependency of every `dispatch-tool-*` gem and is used by the Rails agent loop to discover and invoke tools.

**This gem has zero knowledge of specific tools.** It provides only the framework. Concrete tool gems (files, inquire, test-runner) implement their tools on top of this interface.

---

## Gem Structure

```
dispatch-tools-interface/
├── lib/
│   └── dispatch/
│       └── tools/
│           ├── definition.rb
│           ├── registry.rb
│           ├── result.rb
│           └── errors.rb
├── spec/
│   └── dispatch/
│       └── tools/
│           ├── definition_spec.rb
│           ├── registry_spec.rb
│           └── result_spec.rb
├── dispatch-tools-interface.gemspec
├── Gemfile
├── Rakefile
└── README.md
```

---

## 1. `Dispatch::Tools::Definition`

Declares a tool's metadata and execution logic.

### Construction

```ruby
tool = Dispatch::Tools::Definition.new(
  name: "read_file",
  description: "Read the contents of a file",
  parameters: {
    type: "object",
    properties: {
      path: { type: "string", description: "File path relative to worktree root" },
      start_line: { type: "integer", description: "Start line (0-based)" },
      end_line: { type: "integer", description: "End line (0-based, -1 for EOF)" }
    },
    required: ["path"]
  }
) do |params, context|
  # execution block
  # params = parsed arguments hash (symbolized keys)
  # context = execution context hash (e.g. worktree_path, task_id)
  Dispatch::Tools::Result.success(output: file_contents)
end
```

### Attributes (read-only)

- `name` — String, unique tool identifier (snake_case).
- `description` — String, human-readable description for the LLM.
- `parameters` — Hash, JSON Schema object describing the tool's parameters.

### Methods

- `call(params, context: {})` — Execute the tool's block with the given params and context. Returns a `Dispatch::Tools::Result`. **Never raises** — catches all exceptions from the block and wraps them in `Result.failure`. Validates params via `validate_params` before executing the block; returns `Result.failure` with validation errors if invalid. Symbolizes param keys before passing to the block.
- `to_h` — Returns `{ name:, description:, parameters: }` as a plain hash suitable for passing to an LLM adapter.
- `to_tool_definition` — Returns a hash with the same shape as `to_h`. Used by `Registry#to_a`. (No dependency on the adapter gem — returns a plain hash, not a `Dispatch::Adapter::ToolDefinition` struct.)
- `validate_params(params)` — Validate params against the JSON Schema. Returns `[Boolean, Array<String>]` (valid, error messages). Uses `json_schemer` for full JSON Schema validation.

---

## 2. `Dispatch::Tools::Registry`

Collects tools and provides lookup. Built at agent boot time, then read-only during the agent loop.

### Methods

- `register(tool_definition)` — Add a `Definition` to the registry. Raises `Dispatch::Tools::DuplicateToolError` if a tool with the same name is already registered. Returns `self` for chaining.
- `get(name)` — Look up a tool by name. Returns `Definition` or raises `Dispatch::Tools::ToolNotFoundError`.
- `has?(name)` — Returns `Boolean`.
- `tools` — Returns `Array<Definition>` of all registered tools.
- `tool_names` — Returns `Array<String>` of all registered tool names.
- `to_a` — Returns an `Array<Hash>` where each hash has `{ name:, description:, parameters: }`. These are plain hashes (not adapter structs) — the adapter duck-types on `[:name]` or `.name`.
- `subset(*names)` — Returns a new `Registry` containing only the tools with the given names. Raises `ToolNotFoundError` for any name not found.
- `size` — Returns `Integer`, number of registered tools.
- `empty?` — Returns `Boolean`, true if no tools registered.

### Usage

```ruby
registry = Dispatch::Tools::Registry.new
registry.register(read_file_tool).register(write_file_tool)

# Pass to LLM adapter
adapter.chat(messages, system: system_prompt, tools: registry.to_a)

# Execute a tool call from LLM response
tool = registry.get("read_file")
result = tool.call({ path: "src/main.rb", start_line: 0, end_line: -1 }, context: { worktree_path: "/path/to/worktree" })
```

---

## 3. `Dispatch::Tools::Result`

Standardized return type for tool execution. Immutable after creation.

### Construction

```ruby
# Success
result = Dispatch::Tools::Result.success(output: "file contents here")

# Failure
result = Dispatch::Tools::Result.failure(error: "File not found: src/missing.rb")

# Success with metadata (used by system tools to signal loop control)
result = Dispatch::Tools::Result.success(output: "Gate passed.", metadata: { stop_loop: true })
```

### Attributes (read-only)

- `success?` — Boolean.
- `failure?` — Boolean (inverse of `success?`).
- `output` — String, the tool's output (present on success).
- `error` — String, error message (present on failure).
- `metadata` — Hash, arbitrary metadata (default `{}`). Opaque to the tools interface — consumers (e.g. the agent loop) may inspect it for flags like `stop_loop`. Not sent to the LLM.

### Methods

- `to_s` — Returns `output` on success, `error` on failure. This is what gets sent back to the LLM as the tool result content. `metadata` is not included.
- `to_h` — Returns `{ success: Boolean, output: String?, error: String?, metadata: Hash }`.

---

## 4. Error Classes

Define under `Dispatch::Tools`:

- `Dispatch::Tools::Error` — base error.
- `Dispatch::Tools::DuplicateToolError` — tool name already registered.
- `Dispatch::Tools::ToolNotFoundError` — tool name not in registry.
- `Dispatch::Tools::ValidationError` — parameter validation failed.
- `Dispatch::Tools::ExecutionError` — unhandled error during tool execution.

### Error Design Principle

`call()` never raises. It catches all exceptions (including `ValidationError` and `ExecutionError`) and wraps them in `Result.failure`. The error classes exist for cases where tools are used outside the standard `call()` path (e.g., `validate_params` called directly, or `registry.get()` with a bad name).

---

## 5. Testing

- **Definition tests:**
  - Creating a definition with all attributes.
  - Calling `call()` executes the block and returns a `Result`.
  - `call()` with a failing block returns `Result.failure` (not an exception).
  - `call()` with validation failure returns `Result.failure` with validation error.
  - `to_h` produces the correct shape.
  - `validate_params` correctly validates against the schema.
  - Symbolized keys: verify that string-keyed params are symbolized before passing to block.
- **Registry tests:**
  - Register and retrieve tools.
  - Duplicate registration raises error.
  - Unknown tool lookup raises error.
  - `to_a` produces correct output (array of hashes).
  - `subset` returns a filtered registry.
  - `size` and `empty?` return correct values.
  - Chaining: `registry.register(a).register(b)` works.
- **Result tests:**
  - `success` factory sets correct state.
  - `failure` factory sets correct state.
  - `metadata` defaults to empty hash; can be set.
  - `to_s` returns the right value.
  - `to_h` includes metadata.

---

## 6. Gemspec Dependencies

- `json_schemer` (~> 2.0) for JSON Schema validation of tool parameters.
- No dependency on other dispatch gems. This is the base that others depend on.

---

## Key Constraints

- This gem must have zero knowledge of specific tools. It provides only the framework.
- The `context` hash passed to `call()` is opaque to this gem — tool gems define what they need in context (e.g. `worktree_path`).
- `call()` never raises — all exceptions become `Result.failure`.
- `to_a` returns plain hashes, not adapter structs — no cross-gem dependency.
- `metadata` on Result is opaque to this gem — it exists for consumers (like the agent loop) to use for signaling (e.g. `stop_loop`).
- Thread-safe: `Registry` may be read concurrently. Write operations (register) happen at boot time only.
