RSpec.describe "updating an object in a populated view" do
  include_context "testable app"
  include_context "websocket intercept"

  let :app_definition do
    Proc.new do
      instance_exec(&$ui_app_boilerplate)

      resources :posts, "/posts" do
        disable_protection :csrf

        list do
          expose :posts, data.posts
          render "/simple/posts"
        end

        create do
          verify do
            required :post do
              required :title
            end
          end

          data.posts.create(params[:post]); halt
        end

        update do
          verify do
            required :id
            required :post do
              required :title
            end
          end

          data.posts.by_id(params[:id]).update(params[:post])
        end
      end

      source :posts do
        primary_id
        attribute :title
      end

      presenter "/simple/posts" do
        find(:post).present(posts)
      end
    end
  end

  it "transforms" do
    call("/posts", method: :post, params: { post: { title: "foo" } })
    call("/posts", method: :post, params: { post: { title: "bar" } })
    call("/posts", method: :post, params: { post: { title: "baz" } })

    transformations = save_ui_case("updating", path: "/posts") do
      expect(call("/posts/2", method: :patch, params: { post: { title: "qux" } })[0]).to eq(200)
    end

    expect(transformations[0][:calls].to_json).to eq(
      '[["find",["post"],[],[["present",[[{"id":1,"title":"foo"},{"id":2,"title":"qux"},{"id":3,"title":"baz"}]],[],[]]]]]'
    )
  end
end

RSpec.describe "updating an object in a way that presents a new prop" do
  include_context "testable app"
  include_context "websocket intercept"

  let :app_definition do
    Proc.new do
      instance_exec(&$ui_app_boilerplate)

      resources :posts, "/posts" do
        disable_protection :csrf

        list do
          expose :posts, data.posts
          render "/simple/posts"
        end

        create do
          verify do
            required :post do
              required :title
            end
          end

          data.posts.create(params[:post]); halt
        end

        update do
          verify do
            required :id
            required :post do
              required :body
            end
          end

          data.posts.by_id(params[:id]).update(params[:post])
        end
      end

      source :posts do
        primary_id
        attribute :title
        attribute :body
      end

      presenter "/simple/posts" do
        find(:post).present(posts)
      end
    end
  end

  it "transforms" do
    call("/posts", method: :post, params: { post: { title: "foo" } })
    call("/posts", method: :post, params: { post: { title: "bar" } })
    call("/posts", method: :post, params: { post: { title: "baz" } })

    transformations = save_ui_case("updating_new_prop", path: "/posts") do
      expect(call("/posts/2", method: :patch, params: { post: { body: "bar body" } })[0]).to eq(200)
    end

    expect(transformations[0][:calls].to_json).to eq(
      '[["find",["post"],[],[["present",[[{"id":1,"title":"foo"},{"id":2,"title":"bar","body":"bar body"},{"id":3,"title":"baz"}]],[],[]]]]]'
    )
  end
end

RSpec.describe "updating an object in a way that presents a new prop in a different version" do
  include_context "testable app"
  include_context "websocket intercept"

  let :app_definition do
    Proc.new do
      instance_exec(&$ui_app_boilerplate)

      resources :posts, "/posts" do
        disable_protection :csrf

        list do
          expose :posts, data.posts
          render "/versioned/posts"
        end

        create do
          verify do
            required :post do
              required :title
            end
          end

          data.posts.create(params[:post]); halt
        end

        update do
          verify do
            required :id
            required :post do
              required :body
            end
          end

          data.posts.by_id(params[:id]).update(params[:post])
        end
      end

      source :posts do
        primary_id
        attribute :title
        attribute :body
      end

      presenter "/versioned/posts" do
        find(:post).present(posts) do |post_view, post|
          post_view.use(post.body ? :published : :unpublished)
        end
      end
    end
  end

  it "transforms" do
    call("/posts", method: :post, params: { post: { title: "foo" } })
    call("/posts", method: :post, params: { post: { title: "bar" } })
    call("/posts", method: :post, params: { post: { title: "baz" } })

    transformations = save_ui_case("updating_new_prop_with_version", path: "/posts") do
      expect(call("/posts/2", method: :patch, params: { post: { body: "bar body" } })[0]).to eq(200)
    end

    expect(transformations[0][:calls].to_json).to eq(
      '[["find",["post"],[],[["present",[[{"id":1,"title":"foo"},{"id":2,"title":"bar","body":"bar body"},{"id":3,"title":"baz"}]],[[["use",["unpublished"],[],[]]],[["use",["published"],[],[]]],[["use",["unpublished"],[],[]]]],[]]]]]'
    )
  end
end
