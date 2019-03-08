require_relative "../shared_context"

RSpec.describe "StringDoc#set_node_label" do
  include_context :string_doc

  let :html do
    <<~HTML
      <article binding="post">
        <h1 binding="title">title goes here</h1>
      </article>
    HTML
  end

  let :node do
    doc.find_significant_nodes_with_name(:binding, :post)[0]
  end

  it "sets the label" do
    doc.set_node_label(node, :foo, :bar)
    expect(doc.find_significant_nodes_with_name(:binding, :post)[0].label(:foo)).to eq(:bar)
  end

  it "reassigns children" do
    doc.set_node_label(node, :foo, :bar)
    expect(doc.to_s).to eq("<article data-b=\"post\" data-c=\"article\"><h1 data-b=\"title\" data-c=\"article\">title goes here</h1></article>")
  end

  it "reassigns transformations" do
    doc.transform(node) do
      "transformed"
    end

    doc.set_node_label(node, :foo, :bar)
    expect(doc.to_s).to eq("transformed")
  end
end
