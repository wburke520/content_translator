defmodule ContentTranslator do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # TODO: How to restart this process if it fails? (don't know how supervisors work yet)
    redis_client = Exredis.start_using_connection_string(Config.redis_connection_string)
    Process.register(redis_client, :redis)

    children = [
      supervisor(ContentTranslator.Endpoint, []),
      worker(ContentTranslator.TranslationService, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ContentTranslator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    ContentTranslator.Endpoint.config_change(changed, removed)
    :ok
  end
end
