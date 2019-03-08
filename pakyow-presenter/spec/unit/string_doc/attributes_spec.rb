RSpec.describe StringDoc::Attributes do
  describe "#initialize" do
    it "initializes with a hash" do
      expect(StringDoc::Attributes.new({})).to be_instance_of(StringDoc::Attributes)
    end
  end

  let :attributes do
    StringDoc::Attributes.new(name: "foo", title: "bar")
  end

  describe "#keys" do
    it "delegates to the internal hash" do
      expect(attributes.hash).to receive(:keys)
      attributes.keys
    end
  end

  describe "#key?" do
    it "delegates to the internal hash" do
      expect(attributes.hash).to receive(:key?).with("name")
      attributes.key?(:name)
    end
  end

  describe "#[]" do
    it "delegates to the internal hash" do
      expect(attributes.hash).to receive(:[]).with("name")
      attributes[:name]
    end
  end

  describe "#each" do
    it "delegates to the internal hash" do
      expect(attributes.hash).to receive(:each)
      attributes.each
    end
  end

  describe "#==" do
    it "returns true when the objects are equal" do
      other = StringDoc::Attributes.new(name: "foo", title: "bar")
      expect(attributes).to eq(other)
    end

    it "returns false when the objects are not equal" do
      other = StringDoc::Attributes.new(name: "foo", title: "baz")
      expect(attributes).not_to eq(other)
    end

    it "returns false when the other object is not of type StringDoc::Attributes" do
      other = 'name="foo" title="bar"'
      expect(attributes).not_to eq(other)
    end
  end
end
