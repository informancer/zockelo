defmodule Zockelo.Workers.StaleRecordCleanupWorker do
  @moduledoc """
  Daily Oban worker that deletes expired records:
    - `magic_link_tokens` where `expires_at < now()`
    - `invite_links` where `expires_at < now()` (non-null only)
    - `sessions` where `expires_at < now()`
    - `admin_audit_log` entries older than `audit_log_retention_days` system config (default: 2555 days / 7 years)
  """

  use Oban.Worker, queue: :scheduled, max_attempts: 3

  import Ecto.Query

  alias Zockelo.Repo
  alias Zockelo.Auth.{MagicLinkToken, Session, InviteLink}
  alias Zockelo.Audit.AdminAuditLog

  @default_audit_retention_days 2555

  @impl true
  def perform(_job) do
    now = DateTime.utc_now()
    audit_cutoff = DateTime.add(now, -audit_retention_days(), :day)

    {magic_count, _} = Repo.delete_all(from t in MagicLinkToken, where: t.expires_at < ^now)
    {invite_count, _} = Repo.delete_all(from l in InviteLink, where: not is_nil(l.expires_at) and l.expires_at < ^now)
    {session_count, _} = Repo.delete_all(from s in Session, where: s.expires_at < ^now)
    {audit_count, _} = Repo.delete_all(from a in AdminAuditLog, where: a.performed_at < ^audit_cutoff)

    require Logger
    Logger.info("StaleRecordCleanup: deleted #{magic_count} tokens, #{invite_count} invite links, #{session_count} sessions, #{audit_count} audit log entries")

    :ok
  end

  defp audit_retention_days do
    Application.get_env(:zockelo, :audit_log_retention_days, @default_audit_retention_days)
  end
end
