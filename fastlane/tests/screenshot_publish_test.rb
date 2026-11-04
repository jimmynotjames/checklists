require "minitest/autorun"
require_relative "../lib/screenshot_publish"

class ScreenshotPublishTest < Minitest::Test
  Locale = Struct.new(:locale, :sets) do
    def get_app_screenshot_sets = sets || []
  end
  Shot = Struct.new(:language, :display_type, :path)
  RemoteShot = Struct.new(:source_file_checksum, :finished) do
    def complete? = finished
  end
  ScreenshotSet = Struct.new(:screenshot_display_type, :app_screenshots)
  Version = Struct.new(:version_string, :app_version_state, :localizations) do
    def get_app_store_version_localizations = localizations
  end
  App = Struct.new(:version) do
    def get_edit_app_store_version(platform:) = version
  end
  class Uploader
    attr_reader :calls
    attr_accessor :upload_error
    def initialize = @calls = []
    def delete_screenshots(locales, grouped, tries:) = @calls << [:delete, locales.map(&:locale), tries]
    def sort_screenshots(locales) = @calls << [:sort, locales.map(&:locale)]

    def upload_screenshots(locales, grouped, timeout, tries:)
      @calls << [:upload, locales.map(&:locale), tries, timeout]
      raise upload_error if upload_error
    end
  end

  def setup
    @version = Version.new("1.2", "PREPARE_FOR_SUBMISSION", [Locale.new("en-US"), Locale.new("fr-FR")])
    @app = App.new(@version)
    @uploader = Uploader.new
    @shots = [Shot.new("en-US", "APP_IPHONE_67", __FILE__)]
    @sleeps = []
    @version.localizations.first.sets = [ScreenshotSet.new("APP_IPHONE_67", [RemoteShot.new(Digest::MD5.file(__FILE__).hexdigest, true)])]
  end

  def publish
    ScreenshotPublish.publish(app: @app, version: "1.2", locales: ["en-US"], screenshots: @shots, uploader: @uploader,
                              sleeper: ->(seconds) { @sleeps << seconds })
  end

  def remote = @version.localizations.first.sets.first.app_screenshots.first

  def test_mutations_and_retries_only_receive_selected_locale
    publish
    assert_equal [[:delete, ["en-US"], 3], [:upload, ["en-US"], 3, 300], [:sort, ["en-US"]]], @uploader.calls
  end

  def test_deliver_giving_up_still_sorts_and_verifies
    @uploader.upload_error = RuntimeError.new("4 incomplete screenshot(s) still exist")
    publish # The remote set is complete and correct, so Deliver's give-up is not a failure.
    assert_equal [:sort, ["en-US"]], @uploader.calls.last

    remote.finished = false
    error = assert_raises(ScreenshotPublish::IncompletePublish) { publish }
    assert_equal({ "en-US" => ["processing APP_IPHONE_67"] }, error.failures)
    assert_includes error.message, "4 incomplete screenshot(s) still exist"
    assert_equal [:sort, ["en-US"]], @uploader.calls.last
  end

  def test_assets_still_processing_get_a_bounded_settle
    remote.finished = false
    sleeper = lambda do |seconds|
      @sleeps << seconds
      remote.finished = true if @sleeps.length == 2
    end
    ScreenshotPublish.publish(app: @app, version: "1.2", locales: ["en-US"], screenshots: @shots, uploader: @uploader,
                              sleeper: sleeper)
    assert_equal [60, 60], @sleeps

    @sleeps = []
    remote.finished = false
    assert_raises(ScreenshotPublish::IncompletePublish) { publish }
    assert_equal ScreenshotPublish::SETTLE_SECONDS, @sleeps
  end

  def test_wrong_files_fail_without_waiting
    remote.source_file_checksum = "wrong"
    error = assert_raises(ScreenshotPublish::IncompletePublish) { publish }
    assert_equal({ "en-US" => ["files APP_IPHONE_67"] }, error.failures)
    assert_empty @sleeps
  end

  def test_every_failing_locale_is_reported_for_one_retry
    path = File.expand_path("../lib/screenshot_publish.rb", __dir__)
    fr = @version.localizations.last
    fr.sets = [ScreenshotSet.new("APP_IPHONE_67", [RemoteShot.new(Digest::MD5.file(path).hexdigest, false)])]
    @version.localizations.first.sets.first.app_screenshots.first.source_file_checksum = "wrong"
    shots = @shots + [Shot.new("fr-FR", "APP_IPHONE_67", path)]
    error = assert_raises(ScreenshotPublish::IncompletePublish) do
      ScreenshotPublish.publish(app: @app, version: "1.2", locales: ["en-US", "fr-FR"], screenshots: shots,
                                uploader: @uploader, sleeper: ->(_seconds) {})
    end
    assert_equal({ "en-US" => ["files APP_IPHONE_67"], "fr-FR" => ["processing APP_IPHONE_67"] }, error.failures)
  end

  def test_remote_verification_rejects_unexpected_sets
    locale = Object.new
    def locale.locale = "en-US"
    def locale.get_app_screenshot_sets = []
    assert_raises(RuntimeError) { ScreenshotPublish.verify_remote!([locale], { "en-US" => @shots }) }
  end

  def test_incomplete_or_wrong_remote_asset_is_not_success
    remote = @version.localizations.first.sets.first.app_screenshots.first
    remote.finished = false
    assert_raises(RuntimeError) { publish }
    remote.finished = true
    remote.source_file_checksum = "wrong"
    assert_raises(RuntimeError) { publish }
  end

  def test_remote_order_must_match_reviewed_story
    @shots << Shot.new("en-US", "APP_IPHONE_67", File.expand_path("../lib/screenshot_publish.rb", __dir__))
    remote = @version.localizations.first.sets.first.app_screenshots
    remote << RemoteShot.new(Digest::MD5.file(@shots.last.path).hexdigest, true)
    # Expected filename order is screenshot_publish.rb, then screenshot_publish_test.rb.
    error = assert_raises(ScreenshotPublish::IncompletePublish) { publish }
    assert_equal({ "en-US" => ["order APP_IPHONE_67"] }, error.failures)
    remote.reverse!
    publish
  end

  def test_each_display_type_is_verified_as_its_own_set
    duo_path = File.expand_path("../lib/screenshot_publish.rb", __dir__)
    @shots << Shot.new("en-US", "APP_IPHONE_DUO", duo_path)
    sets = @version.localizations.first.sets
    assert_raises(RuntimeError) { publish }
    sets << ScreenshotSet.new("APP_IPHONE_DUO", [RemoteShot.new(Digest::MD5.file(__FILE__).hexdigest, true)])
    assert_raises(RuntimeError) { publish }
    sets.last.app_screenshots.first.source_file_checksum = Digest::MD5.file(duo_path).hexdigest
    publish
  end

  def test_wrong_version_fails_before_deletion
    @version.version_string = "1.3"
    assert_raises(ArgumentError) { publish }
    assert_empty @uploader.calls
  end

  def test_live_version_fails_before_deletion
    @version.app_version_state = "READY_FOR_SALE"
    assert_raises(ArgumentError) { publish }
    assert_empty @uploader.calls
  end

  def test_missing_localization_is_not_created
    @version.localizations = [Locale.new("fr-FR")]
    assert_raises(ArgumentError) { publish }
    assert_empty @uploader.calls
  end

  def test_extra_or_unrecognized_images_fail_before_deletion
    @shots << Shot.new("fr-FR", "APP_IPHONE_67")
    assert_raises(ArgumentError) { publish }
    @shots = [Shot.new("en-US", nil)]
    assert_raises(ArgumentError) { publish }
    assert_empty @uploader.calls
  end
end
