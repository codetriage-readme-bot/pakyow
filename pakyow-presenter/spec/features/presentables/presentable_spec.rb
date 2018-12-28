RSpec.describe "presentable exposures" do
  include_context "app"

  before do
    call "/"
  end

  after do
    $presentable = nil
  end

  let :app_init do
    Proc.new do
      controller :default do
        get "/" do
          expose :current_user, "current_user"
        end
      end

      presenter "/" do
        def perform
          $presentable = current_user
        end
      end
    end
  end

  it "makes exposures presentable" do
    expect($presentable).to eq("current_user")
  end

  context "multiple exposures are made, but for different channels" do
    after do
      $presentables = nil
    end

    let :app_init do
      Proc.new do
        controller :default do
          get "/" do
            expose :current_user, "user1", for: [:foo]
            expose :current_user, "user2", for: [:foo, :bar]
          end
        end

        presenter "/" do
          def perform
            $presentables = {
              default: current_user,
              foo: current_user(:foo),
              foo_bar: current_user(:foo, :bar)
            }
          end
        end
      end
    end

    it "returns none of the channeled values when no channel is provided" do
      expect($presentables[:default]).to be(nil)
    end

    it "makes each exposure available by its channel" do
      expect($presentables[:foo]).to eq("user1")
      expect($presentables[:foo_bar]).to eq("user2")
    end
  end
end
