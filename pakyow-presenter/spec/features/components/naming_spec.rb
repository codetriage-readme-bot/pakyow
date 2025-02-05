RSpec.describe "naming presenters in backend components" do
  include_context "app"

  let :app_init do
    Proc.new do
      component :single do
        presenter do
          def perform
            find(:post).replace(self.class.name)
          end
        end
      end
    end
  end

  it "names the component presenter predictibly" do
    expect(call("/components")[2].read).to include("Test::Components::Single::Presenter")
  end
end
