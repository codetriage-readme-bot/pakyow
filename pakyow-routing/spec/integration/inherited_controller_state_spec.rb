RSpec.describe "inherited controller state" do
  include_context "app"

  describe "routes" do
    let :app_init do
      Proc.new {
        controller do
          default do
            res.body << "one"
          end

          namespace "/foo" do
            default do
              res.body << "two"
            end
          end
        end
      }
    end

    it "does not inherit" do
      expect(call("/foo")[2]).to eq(["two"])
    end
  end
end
