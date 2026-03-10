defmodule Zockelo.Legal.SupervisoryAuthority do
  @moduledoc """
  Static map of ISO 3166-1 alpha-2 country codes to EU/EEA data protection supervisory authorities.
  Returns {:ok, authority} or :unknown.

  Germany (DE) has the federal BfDI plus 16 Länder authorities — the template
  should render a Länder caveat when `germany_note: true` is present.
  """

  @authorities %{
    "AT" => %{name: "Datenschutzbehörde", url: "https://www.dsb.gv.at"},
    "BE" => %{name: "Autorité de protection des données / Gegevensbeschermingsautoriteit", url: "https://www.dataprotectionauthority.be"},
    "BG" => %{name: "Commission for Personal Data Protection", url: "https://www.cpdp.bg"},
    "CH" => %{name: "Federal Data Protection and Information Commissioner", url: "https://www.edoeb.admin.ch"},
    "CY" => %{name: "Commissioner for Personal Data Protection", url: "https://www.dataprotection.gov.cy"},
    "CZ" => %{name: "Úřad pro ochranu osobních údajů", url: "https://www.uoou.cz"},
    "DE" => %{name: "Bundesbeauftragte für den Datenschutz und die Informationsfreiheit (BfDI)", url: "https://www.bfdi.bund.de", germany_note: true},
    "DK" => %{name: "Datatilsynet", url: "https://www.datatilsynet.dk"},
    "EE" => %{name: "Andmekaitse Inspektsioon", url: "https://www.aki.ee"},
    "ES" => %{name: "Agencia Española de Protección de Datos", url: "https://www.aepd.es"},
    "FI" => %{name: "Tietosuojavaltuutetun toimisto", url: "https://tietosuoja.fi"},
    "FR" => %{name: "Commission Nationale de l'Informatique et des Libertés (CNIL)", url: "https://www.cnil.fr"},
    "GB" => %{name: "Information Commissioner's Office (ICO)", url: "https://ico.org.uk"},
    "GR" => %{name: "Hellenic Data Protection Authority", url: "https://www.dpa.gr"},
    "HR" => %{name: "Agencija za zaštitu osobnih podataka", url: "https://azop.hr"},
    "HU" => %{name: "Nemzeti Adatvédelmi és Információszabadság Hatóság", url: "https://www.naih.hu"},
    "IE" => %{name: "Data Protection Commission", url: "https://www.dataprotection.ie"},
    "IS" => %{name: "Persónuvernd", url: "https://www.personuvernd.is"},
    "IT" => %{name: "Garante per la protezione dei dati personali", url: "https://www.garanteprivacy.it"},
    "LI" => %{name: "Datenschutzstelle", url: "https://www.datenschutzstelle.li"},
    "LT" => %{name: "Valstybinė duomenų apsaugos inspekcija", url: "https://www.ada.lt"},
    "LU" => %{name: "Commission nationale pour la protection des données", url: "https://cnpd.public.lu"},
    "LV" => %{name: "Datu valsts inspekcija", url: "https://www.dvi.gov.lv"},
    "MT" => %{name: "Information and Data Protection Commissioner", url: "https://idpc.org.mt"},
    "NL" => %{name: "Autoriteit Persoonsgegevens", url: "https://www.autoriteitpersoonsgegevens.nl"},
    "NO" => %{name: "Datatilsynet", url: "https://www.datatilsynet.no"},
    "PL" => %{name: "Urząd Ochrony Danych Osobowych", url: "https://uodo.gov.pl"},
    "PT" => %{name: "Comissão Nacional de Proteção de Dados", url: "https://www.cnpd.pt"},
    "RO" => %{name: "Autoritatea Națională de Supraveghere a Prelucrării Datelor cu Caracter Personal", url: "https://www.dataprotection.ro"},
    "SE" => %{name: "Integritetsskyddsmyndigheten", url: "https://www.imy.se"},
    "SI" => %{name: "Informacijski pooblaščenec", url: "https://www.ip-rs.si"},
    "SK" => %{name: "Úrad na ochranu osobných údajov Slovenskej republiky", url: "https://dataprotection.gov.sk"}
  }

  @doc "Returns {:ok, authority_map} or :unknown for the given ISO 3166-1 alpha-2 country code."
  def lookup(nil), do: :unknown
  def lookup(""), do: :unknown

  def lookup(code) when is_binary(code) do
    case Map.fetch(@authorities, String.upcase(code)) do
      {:ok, authority} -> {:ok, authority}
      :error -> :unknown
    end
  end
end
