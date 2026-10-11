# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require_relative "../lib/screenshot_capture"

class ScreenshotCaptureTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def setup
    @capture = ScreenshotCapture.new(ROOT)
  end

  def test_snapshot_options_are_serial_and_run_scoped
    options = @capture.snapshot_options(
      run_id: "test-run",
      locales: ["en-US"],
      simulator_name: "iPhone 17 Pro Max Screenshots [12345678]"
    )

    assert_equal ["en-US"], options.fetch(:languages)
    assert_equal ["iPhone 17 Pro Max Screenshots [12345678]"], options.fetch(:devices)
    assert_equal false, options.fetch(:concurrent_simulators)
    assert_equal false, options.fetch(:erase_simulator)
    assert_equal true, options.fetch(:stop_after_first_error)
    assert_equal true, options.fetch(:result_bundle)
    assert_includes options.fetch(:output_directory), "/.build/screenshots/runs/test-run/raw"
    refute options.key?(:xcargs)
  end

  def test_test_runner_environment_is_scoped_and_restored
    original = ENV["TEST_RUNNER_RUN_APP_STORE_SCREENSHOTS"]
    ENV.delete("TEST_RUNNER_RUN_APP_STORE_SCREENSHOTS")

    @capture.send(:with_test_runner_environment, "test-run", "/repo/cache") do
      assert_equal "1", ENV.fetch("TEST_RUNNER_RUN_APP_STORE_SCREENSHOTS")
      assert_equal "/repo/cache", ENV.fetch("TEST_RUNNER_SCREENSHOT_CACHE_DIR")
      assert_equal "1", ENV.fetch("CHECKLISTS_SCOPED_SCREENSHOT_CAPTURE")
    end
    refute ENV.key?("TEST_RUNNER_RUN_APP_STORE_SCREENSHOTS")
  ensure
    original.nil? ? ENV.delete("TEST_RUNNER_RUN_APP_STORE_SCREENSHOTS") : ENV["TEST_RUNNER_RUN_APP_STORE_SCREENSHOTS"] = original
  end

  def test_capture_holds_one_slot_and_records_its_result
    Dir.mktmpdir do |state|
      previous = ENV.to_h.slice("SIMULATOR_SLOTS_STATE_DIR", "SIMULATOR_SLOTS_MASTER")
      ENV["SIMULATOR_SLOTS_STATE_DIR"] = state
      ENV["SIMULATOR_SLOTS_MASTER"] = state # any existing directory turns the pool on
      begin
        result = @capture.send(:with_simulator_slot) { :captured }
        assert_equal :captured, result
        events = File.readlines(File.join(state, "runs.log")).map { |line| JSON.parse(line) }
        assert_equal [1], events.select { |e| e["event"] == "start" }.map { |e| e["granted"] }
        assert_equal [0], events.select { |e| e["event"] == "result" }.map { |e| e["rc"] }
      ensure
        %w[SIMULATOR_SLOTS_STATE_DIR SIMULATOR_SLOTS_MASTER].each { |name| ENV[name] = previous[name] }
      end
    end
  end

  def test_capture_takes_no_slot_without_the_master
    Dir.mktmpdir do |state|
      previous = ENV.to_h.slice("SIMULATOR_SLOTS_STATE_DIR", "SIMULATOR_SLOTS_MASTER")
      ENV["SIMULATOR_SLOTS_STATE_DIR"] = state
      ENV["SIMULATOR_SLOTS_MASTER"] = File.join(state, "absent")
      begin
        assert_equal :captured, @capture.send(:with_simulator_slot) { :captured }
        refute File.exist?(File.join(state, "runs.log"))
      ensure
        %w[SIMULATOR_SLOTS_STATE_DIR SIMULATOR_SLOTS_MASTER].each { |name| ENV[name] = previous[name] }
      end
    end
  end

  def test_inactive_locale_is_rejected
    config = @capture.instance_variable_get(:@config)
    @capture.instance_variable_set(:@config, config.merge("active_locales" => ["en-US"]))
    error = assert_raises(ArgumentError) { @capture.send(:selected_locales, "de") }
    assert_includes error.message, "inactive screenshot locale"
  end
end
