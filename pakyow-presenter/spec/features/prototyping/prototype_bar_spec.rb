RSpec.describe "prototype bar" do
  include_context "app"

  let :mode do
    :prototype
  end

  it "renders the bar" do
    expect(call("/prototyping/prototype_bar")[2].read).to include_sans_whitespace(
      <<~HTML
        div class="pw-prototype"
      HTML
    )
  end

  context "not in prototype mode" do
    let :mode do
      :test
    end

    it "does not render the bar" do
      expect(call("/prototyping/prototype_bar")[2].read).not_to include_sans_whitespace(
        <<~HTML
          div class="pw-prototype"
        HTML
      )
    end
  end

  context "view does not contain a body" do
    it "does not render the bar" do
      expect(call("/prototyping/prototype_bar/no_body")[2].read).not_to include_sans_whitespace(
        <<~HTML
          div class="pw-prototype"
        HTML
      )
    end
  end
end
