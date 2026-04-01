# frozen_string_literal: true

RSpec.describe Dispatch::Tools::Result do
  describe ".success" do
    it "creates a successful result with output" do
      result = described_class.success(output: "file contents here")

      expect(result.success?).to be true
      expect(result.failure?).to be false
      expect(result.output).to eq("file contents here")
      expect(result.error).to be_nil
    end

    it "defaults metadata to an empty hash" do
      result = described_class.success(output: "ok")

      expect(result.metadata).to eq({})
    end

    it "accepts custom metadata" do
      result = described_class.success(output: "Gate passed.", metadata: { stop_loop: true })

      expect(result.metadata).to eq({ stop_loop: true })
    end
  end

  describe ".failure" do
    it "creates a failed result with error" do
      result = described_class.failure(error: "File not found: src/missing.rb")

      expect(result.success?).to be false
      expect(result.failure?).to be true
      expect(result.error).to eq("File not found: src/missing.rb")
      expect(result.output).to be_nil
    end

    it "defaults metadata to an empty hash" do
      result = described_class.failure(error: "boom")

      expect(result.metadata).to eq({})
    end

    it "accepts custom metadata on failure" do
      result = described_class.failure(error: "bad", metadata: { retryable: false })

      expect(result.metadata).to eq({ retryable: false })
    end
  end

  describe "#to_s" do
    it "returns output on success" do
      result = described_class.success(output: "hello world")

      expect(result.to_s).to eq("hello world")
    end

    it "returns error on failure" do
      result = described_class.failure(error: "something went wrong")

      expect(result.to_s).to eq("something went wrong")
    end

    it "does not include metadata" do
      result = described_class.success(output: "ok", metadata: { stop_loop: true })

      expect(result.to_s).to eq("ok")
    end
  end

  describe "#to_h" do
    it "returns a hash with all fields for a success result" do
      result = described_class.success(output: "data", metadata: { flag: true })

      expect(result.to_h).to eq({
                                  success: true,
                                  output: "data",
                                  error: nil,
                                  metadata: { flag: true }
                                })
    end

    it "returns a hash with all fields for a failure result" do
      result = described_class.failure(error: "oops")

      expect(result.to_h).to eq({
                                  success: false,
                                  output: nil,
                                  error: "oops",
                                  metadata: {}
                                })
    end
  end

  describe "immutability" do
    it "is a frozen object" do
      result = described_class.success(output: "test")

      expect(result).to be_frozen
    end

    it "raises FrozenError when attempting to modify" do
      result = described_class.success(output: "original", metadata: { key: "value" })

      expect { result.instance_variable_set(:@output, "modified") }.to raise_error(FrozenError)
    end
  end
end
