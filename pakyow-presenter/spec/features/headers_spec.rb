RSpec.describe "response headers for presented requests" do
  include_context "app"

  it "sets Content-Length" do
    expect(call("/")[1]["Content-Length"]).to eq(90)
  end

  it "sets Content-Type" do
    expect(call("/")[1]["Content-Type"]).to eq("text/html")
  end
end
