RSpec.describe "route templating" do
  include_context "app"

  let :app_init do
    Proc.new {
      controller do
        template :talkback do
          get :hello, "/hello"
          get :goodbye, "/goodbye"
        end

        talkback :en, "/en" do
          hello do
            send "hello"
          end

          goodbye do
            send "goodbye"
          end

          get "/thanks" do
            send "thanks"
          end
        end

        talkback :fr, "/fr" do
          hello do
            send "bonjour"
          end
        end
      end
    }
  end

  it "creates routes from the template" do
    expect(call("/en/hello")[2].first).to eq("hello")
    expect(call("/en/goodbye")[2].first).to eq("goodbye")
    expect(call("/fr/hello")[2].first).to eq("bonjour")
  end

  it "extends the template with routes" do
    expect(call("/en/thanks")[2].first).to eq("thanks")
  end

  context "when the template defines actions" do
    let :app_init do
      Proc.new {
        controller do
          template :hooktest do
            action :foo
            action :bar
            get :perform, "/"
          end

          hooktest :test, "/test" do
            def foo
              $calls << :foo
            end

            def bar
              $calls << :bar
            end

            def baz
              $calls << :baz
            end

            action :baz
            skip_action :foo

            perform do
              $calls << :perform
            end
          end
        end
      }
    end

    before do
      $calls = []
    end

    it "calls the actions" do
      expect(call("/test")[0]).to eq(200)

      expect($calls[0]).to eq(:bar)
      expect($calls[1]).to eq(:baz)
      expect($calls[2]).to eq(:perform)
    end
  end
end
