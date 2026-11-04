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

  # Fake simulator host: tracks which capture simulators are booted and the
  # largest number booted at once.
  def fake_capture(pending, booted: [])
    booted = booted.dup
    peak = booted.length
    status = Struct.new(:success?).new(true)
    runner = lambda do |*arguments|
      script = File.basename(arguments[1].to_s)
      stdout =
        if script == "capture_progress.py" && arguments[2] == "pending-targets"
          pending.map { |runtime, device| { "runtime" => runtime, "device" => device }.to_json }.join("\n")
        elsif script == "sim_common.py"
          "12345678\n"
        elsif script == "resolve_booted_sim_udid.py"
          name = arguments[arguments.index("--name") + 1].delete_suffix(" Screenshots [12345678]")
          booted.include?(name) ? "UDID-#{name}\n" : ""
        elsif File.basename(arguments[0]) == "prepare_simulator.sh"
          booted |= [arguments[1]]
          peak = [peak, booted.length].max
          "UDID-#{arguments[1]}\t#{arguments[1]} Screenshots [12345678]\n"
        elsif arguments.first(3) == %w[xcrun simctl shutdown]
          booted.delete(arguments[3].delete_prefix("UDID-"))
          ""
        elsif script == "prepare_output.py"
          { "output" => "/out", "report" => "/report", "review_page" => "/review" }.to_json
        else
          ""
        end
      [stdout, "", status]
    end
    capture = ScreenshotCapture.new(ROOT, command_runner: runner)
    config = capture.instance_variable_get(:@config)
    capture.instance_variable_set(
      :@config,
      config.merge(
        "active_locales" => %w[en-US de],
        "devices" => [{ "name" => "Phone" }, { "name" => "Duo" }]
      )
    )
    capture.define_singleton_method(:isolate_fastlane_snapshot!) { |_cache_dir| nil }
    yielded = []
    capture.send(:capture_run, run_id: "test-run", locales: %w[en-US de]) do |options|
      yielded << [options.fetch(:devices).first.delete_suffix(" Screenshots [12345678]"), options.fetch(:languages).first]
    end
    [yielded, peak]
  end

  def test_capture_runs_device_major_with_one_booted_simulator
    # Duo is still booted from an earlier run.
    yielded, peak = fake_capture(
      [%w[en-US Phone], %w[en-US Duo], %w[de Phone], %w[de Duo]],
      booted: ["Duo"]
    )
    assert_equal [%w[Phone en-US], %w[Phone de], %w[Duo en-US], %w[Duo de]], yielded
    assert_equal 1, peak
  end

  def test_resume_shuts_down_a_finished_device_left_booted
    yielded, peak = fake_capture([%w[de Duo]], booted: ["Phone"])
    assert_equal [%w[Duo de]], yielded
    assert_equal 1, peak
  end

  def test_inactive_locale_is_rejected
    config = @capture.instance_variable_get(:@config)
    @capture.instance_variable_set(:@config, config.merge("active_locales" => ["en-US"]))
    error = assert_raises(ArgumentError) { @capture.send(:selected_locales, "de") }
    assert_includes error.message, "inactive screenshot locale"
  end
end
