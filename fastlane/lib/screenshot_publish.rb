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

  # Deliver's wait per upload round before it retries assets still processing.
  UPLOAD_TIMEOUT_SECONDS = 300
  # After the upload, extra waits for assets that are only still processing.
  SETTLE_SECONDS = [60, 60, 60].freeze

  # The selected locales did not all end up complete, matching and in order.
  class IncompletePublish < RuntimeError
    attr_reader :failures

    def initialize(failures, upload_error)
      @failures = failures
      detail = failures.map { |locale, problems| "#{locale} (#{problems.join(', ')})" }.join("; ")
      cause = upload_error ? " Deliver stopped with: #{upload_error.message}." : ""
      super("Screenshot verification failed for #{failures.length} locale(s): #{detail}.#{cause}")
    end
  end

  def self.publish(app:, version:, locales:, screenshots:, uploader:, sleeper: Kernel.method(:sleep))
    raise ArgumentError, "Select at least one locale" if locales.empty? || locales.uniq != locales
    grouped = screenshots.group_by(&:language)
    unless grouped.keys.sort == locales.sort && screenshots.all?(&:display_type)
      raise ArgumentError, "Screenshot files must exactly match the selected locales and supported display sizes"
    end
    # Validate before any deletion. Passing only these localizations also scopes
    # Deliver's processing checks, retries, and sorting to this upload.
    selected = target(app, version, locales)
    uploader.delete_screenshots(selected, grouped, tries: 3)
    upload_error = begin
      uploader.upload_screenshots(selected, grouped, UPLOAD_TIMEOUT_SECONDS, tries: 3)
      nil
    rescue StandardError => e
      e
    end
    # Deliver raises once its retries run out, before sorting, so sort and verify
    # regardless; otherwise every locale it already uploaded keeps upload order.
    uploader.sort_screenshots(selected)
    failures = remote_failures(selected, grouped)
    SETTLE_SECONDS.each do |seconds|
      break unless failures.any? && failures.values.flatten.all? { |problem| problem.start_with?("processing") }

      sleeper.call(seconds)
      failures = remote_failures(selected, grouped)
    end
    raise IncompletePublish.new(failures, upload_error) unless failures.empty?
  end

  def self.verify_remote!(localizations, grouped)
    failures = remote_failures(localizations, grouped)
    raise IncompletePublish.new(failures, nil) unless failures.empty?
  end

  # Every selected locale's problems, so one retry can name all of them.
  def self.remote_failures(localizations, grouped)
    localizations.each_with_object({}) do |localization, failures|
      expected = grouped.fetch(localization.locale).group_by(&:display_type)
      sets = localization.get_app_screenshot_sets
      problems = []
      unless sets.map(&:screenshot_display_type).sort == expected.keys.sort
        problems << "unexpected sets #{sets.map(&:screenshot_display_type).sort.join('/')}"
      end
      sets.each do |set|
        type = set.screenshot_display_type
        checksums = expected.fetch(type, []).sort_by { |shot| File.basename(shot.path) }
                            .map { |shot| Digest::MD5.file(shot.path).hexdigest }
        remote = set.app_screenshots.to_a
        remote_checksums = remote.map { |shot| shot.source_file_checksum.to_s }
        if !remote.all?(&:complete?)
          problems << "processing #{type}"
        elsif remote_checksums.sort == checksums.sort && remote_checksums != checksums
          problems << "order #{type}"
        elsif remote_checksums != checksums
          problems << "files #{type}"
        end
      end
      failures[localization.locale] = problems unless problems.empty?
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
