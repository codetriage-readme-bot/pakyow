RSpec.shared_context "app" do
  let :app do
    local_app_def = app_def

    block = if instance_variable_defined?(:@default_app_def)
      local_default_app_def = @default_app_def

      Proc.new do
        instance_exec(&local_default_app_def)
        instance_exec(&local_app_def)
      end
    else
      Proc.new do
        instance_exec(&local_app_def)
      end
    end

    Pakyow.app(:test, &block)
  end

  let :app_def do
    Proc.new {}
  end

  let :app_init do
    Proc.new {}
  end

  let :autorun do
    true
  end

  let :mode do
    :test
  end

  before do
    Pakyow.config.server.name = :mock
    Pakyow.config.logger.enabled = false
    Pakyow.instance_variable_set(:@error, nil)
    setup_and_run if autorun
  end

  def setup(env: :test)
    super if defined?(super)
    Pakyow.mount app, at: "/", &app_init
    Pakyow.setup(env: env)
  end

  def run
    @app = Pakyow.run
    check_environment
    check_apps
  end

  def setup_and_run(env: mode)
    setup(env: env) && run
  end

  def call(path = "/", opts = {})
    connection_for_call = nil
    allow_any_instance_of(Pakyow::Connection).to receive(:finalize).and_wrap_original do |method|
      connection_for_call = method.receiver
      method.call
    end

    result = @app.call(Rack::MockRequest.env_for(path, opts)).tap do
      check_response(connection_for_call)
    end

    # Unwrap the response body so it's easier to test values.
    #
    [result[0], result[1], result[2].is_a?(Rack::BodyProxy) ? result[2].instance_variable_get(:@body) : result[2]]
  end

  def call_fast(path = "/", opts = {})
    @app.call(Rack::MockRequest.env_for(path, opts))
  end

  let :allow_environment_errors do
    false
  end

  let :allow_application_rescues do
    false
  end

  let :allow_request_failures do
    false
  end

  def check_environment
    if Pakyow.error && !allow_environment_errors
      fail <<~MESSAGE
        Environment unexpectedly failed to boot:

          #{Pakyow.error.class}: #{Pakyow.error.message}

        #{Pakyow.error.backtrace.to_a.join("\n")}
      MESSAGE
    end
  end

  def check_apps
    Pakyow.apps.each do |app|
      if app.respond_to?(:rescued?) && app.rescued? && !allow_application_rescues
        fail <<~MESSAGE
          #{app.class} unexpectedly failed to boot:

            #{app.rescued.class}: #{app.rescued.message}

          #{app.rescued.backtrace.to_a.join("\n")}
        MESSAGE
      end
    end
  end

  def check_response(connection)
    if connection && connection.status >= 500 && !allow_application_rescues && !allow_request_failures
      fail <<~MESSAGE
        Request unexpectedly failed.

          #{connection.error.class}: #{connection.error.message}

        #{connection.error.backtrace.to_a.join("\n")}
      MESSAGE
    end
  end
end
