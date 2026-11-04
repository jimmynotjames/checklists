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
    def initialize = @calls = []
    def delete_screenshots(locales, grouped, tries:) = @calls << [:delete, locales.map(&:locale), tries]
    def upload_screenshots(locales, grouped, timeout, tries:) = @calls << [:upload, locales.map(&:locale), tries, timeout]
    def sort_screenshots(locales) = @calls << [:sort, locales.map(&:locale)]
  end

  def setup
    @version = Version.new("1.2", "PREPARE_FOR_SUBMISSION", [Locale.new("en-US"), Locale.new("fr-FR")])
    @app = App.new(@version)
    @uploader = Uploader.new
    @shots = [Shot.new("en-US", "APP_IPHONE_67", __FILE__)]
    @version.localizations.first.sets = [ScreenshotSet.new("APP_IPHONE_67", [RemoteShot.new(Digest::MD5.file(__FILE__).hexdigest, true)])]
  end

  def publish
    ScreenshotPublish.publish(app: @app, version: "1.2", locales: ["en-US"], screenshots: @shots, uploader: @uploader)
  end

  def test_mutations_and_retries_only_receive_selected_locale
    publish
    assert_equal [[:delete, ["en-US"], 3], [:upload, ["en-US"], 3, 120], [:sort, ["en-US"]]], @uploader.calls
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
    assert_raises(RuntimeError) { publish }
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
