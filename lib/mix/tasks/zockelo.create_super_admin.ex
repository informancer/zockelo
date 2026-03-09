defmodule Mix.Tasks.Zockelo.CreateSuperAdmin do
  @shortdoc "Creates a super admin. Usage: mix zockelo.create_super_admin --email admin@example.com"

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, strict: [email: :string])
    email = Keyword.get(opts, :email)

    unless email do
      Mix.raise("Required: --email <address>")
    end

    Mix.Task.run("app.start")
    Zockelo.ReleaseTasks.create_super_admin(email)
  end
end
