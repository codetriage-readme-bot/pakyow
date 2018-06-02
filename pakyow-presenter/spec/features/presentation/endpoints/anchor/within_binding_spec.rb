RSpec.describe "presenting a view that defines an anchor endpoint within a binding" do
  include_context "testable app"

  let :app_definition do
    Proc.new {
      instance_exec(&$presenter_app_boilerplate)
    }
  end

  it "does not set the href automatically" do
    expect(call("/presentation/endpoints/anchor/within_binding")[2].body.read).to include_sans_whitespace(
      <<~HTML
        <div data-b="post">
          <h1 data-b="title">title</h1>

          <a href="#" data-e="posts_list">Back</a>
        </div>
      HTML
    )
  end

  context "binding is bound to" do
    let :app_definition do
      Proc.new {
        instance_exec(&$presenter_app_boilerplate)

        resources :posts, "/posts" do
          list do
            render "/presentation/endpoints/anchor/within_binding"
          end
        end

        presenter "/presentation/endpoints/anchor/within_binding" do
          find(:post).present(title: "foo")
        end
      }
    end

    it "sets the href" do
      expect(call("/presentation/endpoints/anchor/within_binding")[2].body.read).to include_sans_whitespace(
        <<~HTML
          <div data-b="post">
            <h1 data-b="title">foo</h1>

            <a href="/posts" data-e="posts_list">Back</a>
          </div>
        HTML
      )
    end

    context "endpoint is current" do
      it "receives a current class" do
        expect(call("/posts")[2].body.read).to include_sans_whitespace(
          <<~HTML
            <div data-b="post">
              <h1 data-b="title">foo</h1>

              <a href="/posts" data-e="posts_list" class="current">Back</a>
            </div>
          HTML
        )
      end
    end
  end
end
