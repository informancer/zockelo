defmodule Zockelo.Projections.PlayerProfileProjection do
  use Commanded.Projections.Ecto,
    application: Zockelo.CommandedApp,
    repo: Zockelo.Repo,
    name: __MODULE__

  import Ecto.Query

  alias Zockelo.Projections.PlayerProfile

  alias Zockelo.Domain.Events.{
    PlayerInvited,
    PlayerActivated,
    PlayerDeleted
  }

  project(%PlayerInvited.V1{} = e, _meta, fn multi ->
    # encrypted_email stored in events as Base64 string; decode to binary for DB
    encrypted_email = decode_b64(e.encrypted_email)

    Ecto.Multi.insert(multi, :profile, PlayerProfile.changeset(%{
      player_id: e.player_id,
      tenant_id: e.tenant_id,
      encrypted_email: encrypted_email,
      role: to_string(e.role),
      status: "invited"
    }))
  end)

  project(%PlayerActivated.V1{} = e, _meta, fn multi ->
    encrypted_name = decode_b64(e.encrypted_name)

    Ecto.Multi.update_all(multi, :profile,
      from(p in PlayerProfile, where: p.player_id == ^e.player_id),
      set: [status: "active", encrypted_name: encrypted_name]
    )
  end)

  project(%PlayerDeleted.V1{} = e, _meta, fn multi ->
    Ecto.Multi.update_all(multi, :profile,
      from(p in PlayerProfile, where: p.player_id == ^e.player_id),
      set: [status: "deleted"]
    )
  end)

  # ---------------------------------------------------------------------------
  # Private
  # ---------------------------------------------------------------------------

  # Events store encrypted fields as Base64 strings for JSON compatibility.
  # The DB columns are binary — decode back here.
  defp decode_b64(nil), do: nil
  defp decode_b64(b64) when is_binary(b64) do
    case Base.decode64(b64) do
      {:ok, bin} -> bin
      # Already raw binary (e.g. in unit tests using short string literals)
      :error -> b64
    end
  end
end
