require "fileutils"
require "json"
require "tmpdir"
require "time"

# Read-only Spaceship calls and an explicit public-field allowlist avoid deliver's
# broader metadata export (which can include private App Review information).
module MarketingSnapshot
  APP_IDENTIFIER = "com.jimmyho.checklists"
  ROOT = File.expand_path("../..", __dir__)
  INFO_FIELDS = {
    "name" => :name, "subtitle" => :subtitle,
    "privacy_url" => :privacy_policy_url
  }.freeze
  VERSION_FIELDS = {
    "description" => :description, "keywords" => :keywords,
    "marketing_url" => :marketing_url, "promotional_text" => :promotional_text,
    "support_url" => :support_url, "release_notes" => :whats_new
  }.freeze

  def self.find_app!
    app = Spaceship::ConnectAPI::App.find(APP_IDENTIFIER)
    raise "No access to #{APP_IDENTIFIER}" unless app && app.bundle_id == APP_IDENTIFIER
    app
  end

  def self.localized_files(records, fields, files)
    records.each do |record|
      locale = record.locale
      raise "Invalid ASC locale" unless locale.is_a?(String) && locale.match?(/\A[a-z]{2,3}(?:-[A-Za-z0-9]+)*\z/)
      fields.each do |filename, attribute|
        value = record.public_send(attribute)
        files["metadata/#{locale}/#{filename}.txt"] = value unless value.nil?
      end
    end
  end

  def self.download!
    app = find_app!
    version = app.get_app_store_versions(
      filter: { platform: "IOS", appVersionState: "READY_FOR_DISTRIBUTION" }, includes: nil
    ).first
    # fetch_live_app_info also accepts IN_REVIEW and PENDING_RELEASE; require
    # the distributed record explicitly so a pending edit cannot become source.
    info = Spaceship::ConnectAPI.get_app_infos(app_id: app.id, includes: nil).to_models.find do |record|
      record.state == "READY_FOR_DISTRIBUTION"
    end
    raise "No live iOS version or live app information; no draft fallback" unless version && info
    files = {}
    info_locales = info.get_app_info_localizations
    version_locales = version.get_app_store_version_localizations
    localized_files(info_locales, INFO_FIELDS, files)
    localized_files(version_locales, VERSION_FIELDS, files)
    files["metadata/copyright.txt"] = version.copyright unless version.copyright.nil?
    provenance = {
      "bundle_id" => app.bundle_id, "app_id" => app.id,
      "version" => version.version_string, "platform" => "IOS",
      "app_info_id" => info.id, "app_store_version_id" => version.id,
      "retrieved_at" => Time.now.utc.iso8601,
      "app_info_locales" => info_locales.map(&:locale).sort,
      "version_locales" => version_locales.map(&:locale).sort,
      "source" => "App Store Connect live listing; public fields only"
    }
    files["metadata-source.json"] = JSON.pretty_generate(provenance) + "\n"
    scratch = File.join(ROOT, "tmp", "app-store-metadata")
    FileUtils.mkdir_p(scratch)
    destination = Dir.mktmpdir("live-", scratch)
    files.each do |relative, content|
      path = File.join(destination, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, content)
    end
    destination
  end
end
