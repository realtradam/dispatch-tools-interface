# frozen_string_literal: true

RSpec.describe Dispatch::Tools::Definition do
  let(:parameters_schema) do
    {
      type: "object",
      properties: {
        path: { type: "string", description: "File path" },
        start_line: { type: "integer", description: "Start line (0-based)" },
        end_line: { type: "integer", description: "End line (0-based, -1 for EOF)" }
      },
      required: ["path"]
    }
  end

  let(:tool) do
    described_class.new(
      name: "read_file",
      description: "Read the contents of a file",
      parameters: parameters_schema
    ) do |params, _context|
      Dispatch::Tools::Result.success(output: "contents of #{params[:path]}")
    end
  end

  describe "#initialize" do
    it "creates a definition with all attributes" do
      expect(tool.name).to eq("read_file")
      expect(tool.description).to eq("Read the contents of a file")
      expect(tool.parameters).to eq(parameters_schema)
    end

    it "has read-only attributes" do
      expect(tool).to respond_to(:name)
      expect(tool).to respond_to(:description)
      expect(tool).to respond_to(:parameters)
      expect(tool).not_to respond_to(:name=)
      expect(tool).not_to respond_to(:description=)
      expect(tool).not_to respond_to(:parameters=)
    end
  end

  describe "#call" do
    it "executes the block and returns a Result" do
      result = tool.call({ path: "src/main.rb" })

      expect(result).to be_a(Dispatch::Tools::Result)
      expect(result.success?).to be true
      expect(result.output).to eq("contents of src/main.rb")
    end

    it "passes context to the block" do
      context_tool = described_class.new(
        name: "context_test",
        description: "Test context passing",
        parameters: { type: "object", properties: {}, required: [] }
      ) do |_params, context|
        Dispatch::Tools::Result.success(output: "worktree: #{context[:worktree_path]}")
      end

      result = context_tool.call({}, context: { worktree_path: "/path/to/worktree" })

      expect(result.output).to eq("worktree: /path/to/worktree")
    end

    it "defaults context to an empty hash" do
      context_tool = described_class.new(
        name: "context_default",
        description: "Test default context",
        parameters: { type: "object", properties: {}, required: [] }
      ) do |_params, context|
        Dispatch::Tools::Result.success(output: "context is #{context.class}")
      end

      result = context_tool.call({})

      expect(result.output).to eq("context is Hash")
    end

    it "never raises when the block raises an exception" do
      failing_tool = described_class.new(
        name: "failing",
        description: "A tool that fails",
        parameters: { type: "object", properties: {}, required: [] }
      ) do |_params, _context|
        raise StandardError, "something broke"
      end

      result = nil
      expect { result = failing_tool.call({}) }.not_to raise_error

      expect(result.failure?).to be true
      expect(result.error).to include("something broke")
    end

    it "catches non-StandardError exceptions from the block" do
      failing_tool = described_class.new(
        name: "type_error_tool",
        description: "Raises TypeError",
        parameters: { type: "object", properties: {}, required: [] }
      ) do |_params, _context|
        raise TypeError, "wrong type"
      end

      result = nil
      expect { result = failing_tool.call({}) }.not_to raise_error

      expect(result.failure?).to be true
      expect(result.error).to include("wrong type")
    end

    it "returns Result.failure when params fail validation" do
      result = tool.call({})

      expect(result.failure?).to be true
      expect(result.error).to be_a(String)
      expect(result.error).not_to be_empty
    end

    it "symbolizes string-keyed params before passing to the block" do
      received_params = nil

      spy_tool = described_class.new(
        name: "spy",
        description: "Records params",
        parameters: {
          type: "object",
          properties: {
            name: { type: "string" }
          },
          required: []
        }
      ) do |params, _context|
        received_params = params
        Dispatch::Tools::Result.success(output: "ok")
      end

      spy_tool.call({ "name" => "Alice" })

      expect(received_params).to have_key(:name)
      expect(received_params).not_to have_key("name")
      expect(received_params[:name]).to eq("Alice")
    end

    it "handles deeply nested string keys by symbolizing top-level keys" do
      received_params = nil

      spy_tool = described_class.new(
        name: "deep_spy",
        description: "Records params",
        parameters: {
          type: "object",
          properties: {
            options: { type: "object" }
          },
          required: []
        }
      ) do |params, _context|
        received_params = params
        Dispatch::Tools::Result.success(output: "ok")
      end

      spy_tool.call({ "options" => { "nested" => true } })

      expect(received_params).to have_key(:options)
    end
  end

  describe "#to_h" do
    it "returns a hash with name, description, and parameters" do
      hash = tool.to_h

      expect(hash).to eq({
        name: "read_file",
        description: "Read the contents of a file",
        parameters: parameters_schema
      })
    end

    it "returns a plain hash, not a struct" do
      expect(tool.to_h).to be_a(Hash)
    end
  end

  describe "#to_tool_definition" do
    it "returns the same shape as to_h" do
      expect(tool.to_tool_definition).to eq(tool.to_h)
    end

    it "returns a plain hash" do
      expect(tool.to_tool_definition).to be_a(Hash)
    end
  end

  describe "#validate_params" do
    it "returns [true, []] for valid params" do
      valid, errors = tool.validate_params({ path: "src/main.rb" })

      expect(valid).to be true
      expect(errors).to eq([])
    end

    it "returns [true, []] for valid params with optional fields" do
      valid, errors = tool.validate_params({ path: "src/main.rb", start_line: 0, end_line: 10 })

      expect(valid).to be true
      expect(errors).to eq([])
    end

    it "returns [false, errors] when required params are missing" do
      valid, errors = tool.validate_params({})

      expect(valid).to be false
      expect(errors).not_to be_empty
    end

    it "returns [false, errors] when params have wrong types" do
      valid, errors = tool.validate_params({ path: 123 })

      expect(valid).to be false
      expect(errors).not_to be_empty
    end

    it "handles string-keyed params for validation" do
      valid, errors = tool.validate_params({ "path" => "src/main.rb" })

      expect(valid).to be true
      expect(errors).to eq([])
    end
  end
end
