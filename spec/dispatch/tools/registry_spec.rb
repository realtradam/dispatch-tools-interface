# frozen_string_literal: true

RSpec.describe Dispatch::Tools::Registry do
  let(:read_file_tool) do
    Dispatch::Tools::Definition.new(
      name: "read_file",
      description: "Read the contents of a file",
      parameters: {
        type: "object",
        properties: {
          path: { type: "string" }
        },
        required: [ "path" ]
      }
    ) { |params, _context| Dispatch::Tools::Result.success(output: "contents of #{params[:path]}") }
  end

  let(:write_file_tool) do
    Dispatch::Tools::Definition.new(
      name: "write_file",
      description: "Write contents to a file",
      parameters: {
        type: "object",
        properties: {
          path: { type: "string" },
          content: { type: "string" }
        },
        required: %w[path content]
      }
    ) { |_params, _context| Dispatch::Tools::Result.success(output: "written") }
  end

  let(:delete_file_tool) do
    Dispatch::Tools::Definition.new(
      name: "delete_file",
      description: "Delete a file",
      parameters: {
        type: "object",
        properties: {
          path: { type: "string" }
        },
        required: [ "path" ]
      }
    ) { |_params, _context| Dispatch::Tools::Result.success(output: "deleted") }
  end

  let(:registry) { described_class.new }

  describe "#register" do
    it "adds a tool definition to the registry" do
      registry.register(read_file_tool)

      expect(registry.has?("read_file")).to be true
    end

    it "returns self for chaining" do
      result = registry.register(read_file_tool)

      expect(result).to be(registry)
    end

    it "supports chaining multiple registrations" do
      registry.register(read_file_tool).register(write_file_tool)

      expect(registry.has?("read_file")).to be true
      expect(registry.has?("write_file")).to be true
    end

    it "raises DuplicateToolError when registering a tool with the same name" do
      registry.register(read_file_tool)

      duplicate_tool = Dispatch::Tools::Definition.new(
        name: "read_file",
        description: "Another read file",
        parameters: { type: "object", properties: {}, required: [] }
      ) { |_params, _context| Dispatch::Tools::Result.success(output: "dupe") }

      expect { registry.register(duplicate_tool) }.to raise_error(Dispatch::Tools::DuplicateToolError)
    end
  end

  describe "#get" do
    before { registry.register(read_file_tool) }

    it "returns the tool definition by name" do
      tool = registry.get("read_file")

      expect(tool).to be(read_file_tool)
    end

    it "returns nil for unknown tool name" do
      expect(registry.get("nonexistent")).to be_nil
    end
  end

  describe "#has?" do
    it "returns true when the tool is registered" do
      registry.register(read_file_tool)

      expect(registry.has?("read_file")).to be true
    end

    it "returns false when the tool is not registered" do
      expect(registry.has?("read_file")).to be false
    end
  end

  describe "#tools" do
    it "returns an empty array when no tools are registered" do
      expect(registry.tools).to eq([])
    end

    it "returns all registered tool definitions" do
      registry.register(read_file_tool).register(write_file_tool)

      expect(registry.tools).to contain_exactly(read_file_tool, write_file_tool)
    end
  end

  describe "#tool_names" do
    it "returns an empty array when no tools are registered" do
      expect(registry.tool_names).to eq([])
    end

    it "returns all registered tool names as strings" do
      registry.register(read_file_tool).register(write_file_tool)

      expect(registry.tool_names).to contain_exactly("read_file", "write_file")
    end
  end

  describe "#to_a" do
    it "returns an empty array when no tools are registered" do
      expect(registry.to_a).to eq([])
    end

    it "returns an array of hashes with name, description, and parameters" do
      registry.register(read_file_tool)

      result = registry.to_a

      expect(result).to be_an(Array)
      expect(result.size).to eq(1)
      expect(result.first).to eq({
                                   name: "read_file",
                                   description: "Read the contents of a file",
                                   parameters: {
                                     type: "object",
                                     properties: {
                                       path: { type: "string" }
                                     },
                                     required: [ "path" ]
                                   }
                                 })
    end

    it "returns plain hashes, not structs" do
      registry.register(read_file_tool)

      registry.to_a.each do |entry|
        expect(entry).to be_a(Hash)
      end
    end

    it "includes all registered tools" do
      registry.register(read_file_tool).register(write_file_tool)

      names = registry.to_a.map { |h| h[:name] }

      expect(names).to contain_exactly("read_file", "write_file")
    end
  end

  describe "#subset" do
    before do
      registry.register(read_file_tool).register(write_file_tool).register(delete_file_tool)
    end

    it "returns a new Registry containing only the specified tools" do
      sub = registry.subset("read_file", "write_file")

      expect(sub).to be_a(described_class)
      expect(sub.tool_names).to contain_exactly("read_file", "write_file")
    end

    it "does not include tools not specified" do
      sub = registry.subset("read_file")

      expect(sub.has?("write_file")).to be false
      expect(sub.has?("delete_file")).to be false
    end

    it "returns a different registry instance" do
      sub = registry.subset("read_file")

      expect(sub).not_to be(registry)
    end

    it "raises ToolNotFoundError when a requested name is not found" do
      expect { registry.subset("read_file", "nonexistent") }.to raise_error(Dispatch::Tools::ToolNotFoundError)
    end
  end

  describe "#size" do
    it "returns 0 for an empty registry" do
      expect(registry.size).to eq(0)
    end

    it "returns the number of registered tools" do
      registry.register(read_file_tool).register(write_file_tool)

      expect(registry.size).to eq(2)
    end
  end

  describe "#empty?" do
    it "returns true when no tools are registered" do
      expect(registry.empty?).to be true
    end

    it "returns false when tools are registered" do
      registry.register(read_file_tool)

      expect(registry.empty?).to be false
    end
  end
end
