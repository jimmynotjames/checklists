require_relative "metadata_publish"
require "digest"

# Use Deliver's screenshot primitives with an explicitly scoped localization list.
# Its full runner can create versions/localizations, and its screenshot uploader
# sorts and retries failed assets across all supplied localizations.
module ScreenshotPublish
  def self.target(app, requested, locales)
    version = app.get_edit_app_store_version(platform: "IOS")
    MetadataPublish.validate_target!(version, requested)
    available = version.get_app_store_version_localizations
    missing = locales - available.map(&:locale)
    raise ArgumentError, "Create the requested listing localizations first: #{missing.join(', ')}" unless missing.empty?

    available.select { |localization| locales.include?(localization.locale) }
  end

  def self.publish(app:, version:, locales:, screenshots:, uploader:)
    raise ArgumentError, "Select at least one locale" if locales.empty? || locales.uniq != locales
    grouped = screenshots.group_by(&:language)
    unless grouped.keys.sort == locales.sort && screenshots.all?(&:display_type)
      raise ArgumentError, "Screenshot files must exactly match the selected locales and supported display sizes"
    end
    # Validate before any deletion. Passing only these localizations also scopes
    # Deliver's processing checks, retries, and sorting to this upload.
    selected = target(app, version, locales)
    uploader.delete_screenshots(selected, grouped, tries: 3)
    uploader.upload_screenshots(selected, grouped, 120, tries: 3)
    uploader.sort_screenshots(selected)
    verify_remote!(selected, grouped)
  end

  def self.verify_remote!(localizations, grouped)
    localizations.each do |localization|
      expected = grouped.fetch(localization.locale).group_by(&:display_type)
      sets = localization.get_app_screenshot_sets
      unless sets.map(&:screenshot_display_type).sort == expected.keys.sort
        raise "Unexpected screenshot sets after upload for #{localization.locale}; inspect before retrying"
      end
      sets.each do |set|
        checksums = expected.fetch(set.screenshot_display_type).sort_by { |shot| File.basename(shot.path) }
                            .map { |shot| Digest::MD5.file(shot.path).hexdigest }
        remote = set.app_screenshots.to_a
        unless remote.all?(&:complete?) && remote.map(&:source_file_checksum) == checksums
          raise "Screenshot processing/order verification failed for #{localization.locale}; inspect before retrying"
        end
      end
    end
  end

  def self.inventory(app)
    version = app.get_edit_app_store_version(platform: "IOS")
    live = app.get_live_app_store_version(platform: "IOS")
    inspected = version || live
    {
      primary_locale: app.primary_locale,
      editable_version: version&.version_string,
      inspected_version: inspected&.version_string,
      localizations: inspected ? inspected.get_app_store_version_localizations.map do |localization|
        {
          locale: localization.locale,
          screenshot_sets: localization.get_app_screenshot_sets.map do |set|
            { display_type: set.screenshot_display_type, count: set.app_screenshots.to_a.length }
          end
        }
      end : []
    }
  end
end
