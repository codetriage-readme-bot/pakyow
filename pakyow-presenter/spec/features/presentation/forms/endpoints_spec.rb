RSpec.describe "form endpoints" do
  include_context "app"

  context "form is rendered from resource new" do
    context "resource create endpoint exists" do
      let :app_init do
        Proc.new do
          resource :posts, "/presentation/forms/endpoints/posts" do
            new do
            end

            create do
            end
          end
        end
      end

      it "sets the endpoint to resource create" do
        call("/presentation/forms/endpoints/posts/new")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-c="form" action="/presentation/forms/endpoints/posts" method="post">')
        end
      end
    end

    context "resource create endpoint does not exist" do
      let :app_init do
        Proc.new do
          resource :posts, "/presentation/forms/endpoints/posts" do
            new do
            end
          end
        end
      end

      it "does not set an endpoint" do
        call("/presentation/forms/endpoints/posts/new")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-c="form">')
        end
      end
    end

    context "form explicitly defines an endpoint" do
      let :app_init do
        Proc.new do
          resource :posts, "/presentation/forms/endpoints/explicit/posts" do
            new do
            end

            create do
            end
          end

          controller :explicit, "/explicit" do
            post :create, "/create" do
            end
          end
        end
      end

      it "sets the endpoint to the explicitly defined endpoint" do
        call("/presentation/forms/endpoints/explicit/posts/new")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-e="explicit_create" data-c="form" action="/explicit/create" method="post">')
        end
      end
    end
  end

  context "form is rendered from resource edit" do
    context "resource update endpoint exists" do
      let :app_init do
        Proc.new {
          resource :posts, "/presentation/forms/endpoints/posts" do
            edit do
            end

            update do
            end
          end
        }
      end

      it "sets the endpoint to resource update" do
        call("/presentation/forms/endpoints/posts/1/edit")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-c="form" action="/presentation/forms/endpoints/posts/1" method="post" data-id="1">')
          expect(body).to include('<input type="hidden" name="_method" value="patch">')
        end
      end
    end

    context "resource update endpoint does not exist" do
      let :app_init do
        Proc.new {
          resource :posts, "/presentation/forms/endpoints/posts" do
            edit do
            end
          end
        }
      end

      it "does not set an endpoint" do
        call("/presentation/forms/endpoints/posts/1/edit")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-c="form" data-id="1">')
        end
      end
    end

    context "form explicitly defines an endpoint" do
      let :app_init do
        Proc.new {
          resource :posts, "/presentation/forms/endpoints/explicit/posts" do
            edit do
            end

            update do
            end
          end

          controller :explicit, "/explicit" do
            put :update, "/update" do
            end
          end
        }
      end

      it "sets the endpoint to the explicitly defined endpoint" do
        call("/presentation/forms/endpoints/explicit/posts/1/edit")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-e="explicit_update" data-c="form" action="/explicit/update" method="post"')
          expect(body).to include('<input type="hidden" name="_method" value="put">')
        end
      end
    end
  end

  context "form is rendered from a non-resource endpoint" do
    it "does not set an endpoint by default" do
      call("/presentation/forms/endpoints")[2].read.tap do |body|
        expect(body).to include('<form data-b="post" data-c="form">')
      end
    end

    context "create endpoint is defined for the binding" do
      let :app_init do
        Proc.new {
          resource :posts, "/posts" do
            create do
            end
          end
        }
      end

      it "sets up the form for creating" do
        call("/presentation/forms/endpoints")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-c="form" action="/posts" method="post">')
        end
      end
    end

    context "object is exposed for the form" do
      context "object has an id" do
        context "resource update route exists" do
          let :app_init do
            Proc.new {
              resource :posts, "/posts" do
                update do
                end
              end

              controller do
                get "/presentation/forms/endpoints" do
                  expose :post, { id: 1 }, for: :form
                end
              end
            }
          end

          it "sets the form up for updating" do
            call("/presentation/forms/endpoints")[2].read.tap do |body|
              expect(body).to include('<form data-b="post" data-c="form" action="/posts/1" method="post" data-id="1">')
              expect(body).to include('<input type="hidden" name="_method" value="patch">')
            end
          end

          context "form explicitly defines an endpoint" do
            let :app_init do
              Proc.new {
                resource :posts, "/posts" do
                  update do
                  end
                end

                controller do
                  get "/presentation/forms/endpoints" do
                    expose :post, { id: 1 }, for: :form
                  end
                end

                controller :explicit do
                  delete :endpoint, "/explicit"
                end
              }
            end

            it "sets the endpoint to the explicitly defined endpoint" do
              call("/presentation/forms/endpoints/explicit")[2].read.tap do |body|
                expect(body).to include('<form data-b="post" data-e="explicit_endpoint" data-c="form" action="/explicit" method="post">')
                expect(body).to include('<input type="hidden" name="_method" value="delete">')
              end
            end
          end
        end

        context "resource update route does not exist" do
          let :app_init do
            Proc.new {
              controller do
                get "/presentation/forms/endpoints" do
                  expose :post, { id: 1 }, for: :form
                end
              end
            }
          end

          it "does not set an endpoint" do
            call("/presentation/forms/endpoints")[2].read.tap do |body|
              expect(body).to include('<form data-b="post" data-c="form" data-id="1">')
            end
          end

          context "form explicitly defines an endpoint" do
            let :app_init do
              Proc.new {
                controller do
                  get "/presentation/forms/endpoints" do
                    expose :post, { id: 1 }, for: :form
                  end
                end

                controller :explicit do
                  delete :endpoint, "/explicit"
                end
              }
            end

            it "sets the endpoint to the explicitly defined endpoint" do
              call("/presentation/forms/endpoints/explicit")[2].read.tap do |body|
                expect(body).to include('<form data-b="post" data-e="explicit_endpoint" data-c="form" action="/explicit" method="post">')
                expect(body).to include('<input type="hidden" name="_method" value="delete">')
              end
            end
          end
        end
      end

      context "object does not have an id" do
        context "resource create route exists" do
          let :app_init do
            Proc.new {
              resource :posts, "/posts" do
                create do
                end
              end

              controller do
                get "/presentation/forms/endpoints" do
                  expose :post, {}, for: :form
                end
              end
            }
          end

          it "sets the form up for creating" do
            call("/presentation/forms/endpoints")[2].read.tap do |body|
              expect(body).to include('<form data-b="post" data-c="form" action="/posts" method="post">')
            end
          end

          context "form explicitly defines an endpoint" do
            let :app_init do
              Proc.new {
                resource :posts, "/posts" do
                  create do
                  end
                end

                controller do
                  get "/presentation/forms/endpoints" do
                    expose :post, {}, for: :form
                  end
                end

                controller :explicit do
                  delete :endpoint, "/explicit"
                end
              }
            end

            it "sets the endpoint to the explicitly defined endpoint" do
              call("/presentation/forms/endpoints/explicit")[2].read.tap do |body|
                expect(body).to include('<form data-b="post" data-e="explicit_endpoint" data-c="form" action="/explicit" method="post">')
                expect(body).to include('<input type="hidden" name="_method" value="delete">')
              end
            end
          end
        end

        context "resource create route does not exist" do
          let :app_init do
            Proc.new {
              controller do
                get "/presentation/forms/endpoints" do
                  expose :post, {}, for: :form
                end
              end
            }
          end

          it "does not set an endpoint" do
            call("/presentation/forms/endpoints")[2].read.tap do |body|
              expect(body).to include('<form data-b="post" data-c="form">')
            end
          end

          context "form explicitly defines an endpoint" do
            let :app_init do
              Proc.new {
                controller do
                  get "/presentation/forms/endpoints" do
                    expose :post, {}, for: :form
                  end
                end

                controller :explicit do
                  delete :endpoint, "/explicit"
                end
              }
            end

            it "sets the endpoint to the explicitly defined endpoint" do
              call("/presentation/forms/endpoints/explicit")[2].read.tap do |body|
                expect(body).to include('<form data-b="post" data-e="explicit_endpoint" data-c="form" action="/explicit" method="post">')
                expect(body).to include('<input type="hidden" name="_method" value="delete">')
              end
            end
          end
        end
      end
    end

    context "form explicitly defines an endpoint" do
      let :app_init do
        Proc.new {
          controller :explicit do
            delete :endpoint, "/explicit"
          end
        }
      end

      it "sets the endpoint to the explicitly defined endpoint" do
        call("/presentation/forms/endpoints/explicit")[2].read.tap do |body|
          expect(body).to include('<form data-b="post" data-e="explicit_endpoint" data-c="form" action="/explicit" method="post">')
          expect(body).to include('<input type="hidden" name="_method" value="delete">')
        end
      end

      context "endpoint is contextual" do
        let :app_init do
          Proc.new {
            resource :posts, "/posts" do
              resource :comments, "/comments" do
                new do
                  render "/presentation/forms/endpoints/explicit/contextual"
                end

                create do
                end
              end
            end

            controller do
              get "/presentation/forms/endpoints/explicit/contextual" do
                expose :comment, { post_id: 123 }, for: :form
              end
            end
          }
        end

        it "sets the endpoint when the required values are exposed through params" do
          call("/posts/1/comments/new")[2].read.tap do |body|
            expect(body).to include('<form data-b="comment" data-e="posts_comments_create" data-c="form" action="/posts/1/comments" method="post">')
          end
        end

        it "sets the endpoint when the object exposes the required values" do
          call("/presentation/forms/endpoints/explicit/contextual")[2].read.tap do |body|
            expect(body).to include('<form data-b="comment" data-e="posts_comments_create" data-c="form" action="/posts/123/comments" method="post">')
          end
        end
      end
    end
  end
end
