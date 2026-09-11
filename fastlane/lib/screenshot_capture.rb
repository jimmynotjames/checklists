# frozen_string_literal: true

require "json"
require "fileutils"
require "open3"
require "securerandom"
require "time"

# Owns local screenshot capture state. It has no App Store Connect dependency.
class ScreenshotCapture
  SUPPORTED_FASTLANE_VERSION = "2.236.1"

  def initialize(root, command_runner: nil)
    @root = File.expand_path(root)
    @config = JSON.parse(File.read(File.join(@root, "fastlane", "screenshot-config.json")))
    @command_runner = command_runner || method(:capture_command)
  end

  def capture(options = {}, &block)
    directory = File.join(@root, ".build", "screenshots")
    FileUtils.mkdir_p(directory)
    File.open(File.join(directory, "capture.lock"), "w") do |lock|
      raise "A screenshot capture is already running in this checkout" unless lock.flock(File::LOCK_EX | File::LOCK_NB)
      capture_run(options, &block)
    end
  end

  def capture_run(options = {})
    raise ArgumentError, "capture requires a capture_screenshots callback" unless block_given?

    locales = selected_locales(options[:locales])
    run_id = options[:run_id].to_s.strip
    run_id = "#{Time.now.utc.strftime('%Y%m%dT%H%M%SZ')}-#{SecureRandom.hex(4)}" if run_id.empty?
    begin_run(run_id, locales)

    pending_targets(run_id, locales).each do |target|
      simulator = prepare_simulator(target.fetch("device"))
      cache_dir = File.join(run_directory(run_id), "cache")
      isolate_fastlane_snapshot!(cache_dir)
      with_test_runner_environment(run_id, cache_dir) do
        yield(
          snapshot_options(
            run_id: run_id,
            locales: [target.fetch("runtime")],
            simulator_name: simulator.fetch("name")
          )
        )
      end
      mark_success(run_id, target.fetch("runtime"), target.fetch("device"))
    end

    verify_capture(run_id, locales)
    prepare_output(run_id: run_id, locales: locales)
  end
  private :capture_run

  def prepare_output(run_id:, locales: nil)
    selected = selected_locales(locales)
    payload = run_python(
      "prepare_output.py",
      "--run-id", run_id,
      *locale_arguments(selected)
    )
    result = JSON.parse(payload)
    result.merge(
      "run_id" => run_id,
      "capture_root" => File.join(run_directory(run_id), "raw"),
      "screenshots_path" => result.fetch("output"),
      "report_path" => result.fetch("report"),
      "review_page" => result.fetch("review_page"),
      "runtime_locales" => selected,
      "storefront_locales" => selected.map { |runtime| locale_row(runtime).fetch("storefront") }
    )
  end

  def snapshot_options(run_id:, locales:, simulator_name:)
    {
      project: File.join(@root, "checklists", "checklists.xcodeproj"),
      scheme: "checklists",
      only_testing: ["checklistsUITests/AppStoreScreenshots"],
      devices: [simulator_name],
      languages: locales,
      output_directory: File.join(run_directory(run_id), "raw"),
      derived_data_path: File.join(@root, ".build", "screenshots", "DerivedData"),
      buildlog_path: File.join(run_directory(run_id), "logs"),
      package_cache_path: File.join(@root, ".build", "screenshots", "package-cache"),
      clear_previous_screenshots: false,
      erase_simulator: false,
      reinstall_app: false,
      override_status_bar: true,
      localize_simulator: false,
      concurrent_simulators: false,
      # Each invocation covers one target. Fail before recording success even
      # when a failing test left some image files behind.
      stop_after_first_error: true,
      result_bundle: true,
      number_of_retries: 0,
      skip_open_summary: true,
      output_simulator_logs: true,
      skip_helper_version_check: true
    }
  end

  private

  def selected_locales(value)
    requested = Array(value).flat_map { |entry| entry.to_s.split(",") }.map(&:strip).reject(&:empty?).uniq
    requested = @config.fetch("active_locales") if requested.empty?
    inactive = requested - @config.fetch("active_locales")
    unless inactive.empty?
      raise ArgumentError,
            "inactive screenshot locale(s): #{inactive.join(', ')}; enable them in screenshot-config.json first"
    end
    requested
  end

  def locale_row(runtime)
    @config.fetch("locales").find { |row| row.fetch("runtime") == runtime } ||
      raise(ArgumentError, "unknown screenshot locale: #{runtime}")
  end

  def begin_run(run_id, locales)
    run_python("capture_progress.py", "begin", "--run-id", run_id, *locale_arguments(locales))
  end

  def pending_targets(run_id, locales)
    output = run_python("capture_progress.py", "pending-targets", "--run-id", run_id, *locale_arguments(locales))
    output.lines.map { |line| JSON.parse(line) }
  end

  def verify_capture(run_id, locales)
    run_python("capture_progress.py", "status", "--run-id", run_id, *locale_arguments(locales))
  end

  def mark_success(run_id, runtime, device)
    run_python(
      "capture_progress.py", "mark-success",
      "--run-id", run_id, "--locale", runtime, "--device", device
    )
  end

  def prepare_simulator(device_name)
    output = run_command(File.join(@root, "scripts", "screenshot_content", "prepare_simulator.sh"), device_name)
    udid, name = output.strip.split("\t", 2)
    raise "simulator helper returned an invalid identity" if udid.to_s.empty? || name.to_s.empty?

    { "udid" => udid, "name" => name }
  end

  def run_python(script, *arguments)
    run_command("python3", File.join(@root, "scripts", "screenshot_content", script), *arguments)
  end

  def run_command(*arguments)
    stdout, stderr, status = @command_runner.call(*arguments)
    return stdout if status.success?

    message = stderr.to_s.strip
    message = stdout.to_s.strip if message.empty?
    raise "#{File.basename(arguments.first)} failed: #{message}"
  end

  def capture_command(*arguments)
    Open3.capture3(*arguments, chdir: @root)
  end

  def isolate_fastlane_snapshot!(cache_dir)
    installed = defined?(Fastlane::VERSION) ? Fastlane::VERSION : nil
    unless installed == SUPPORTED_FASTLANE_VERSION
      raise "Screenshot isolation is validated only with fastlane #{SUPPORTED_FASTLANE_VERSION}; " \
            "found #{installed || 'unknown'}. Revalidate the snapshot preparation override before capture."
    end
    require "snapshot"
    FileUtils.mkdir_p(cache_dir)
    Snapshot.send(:remove_const, :CACHE_DIR) if Snapshot.const_defined?(:CACHE_DIR, false)
    Snapshot.const_set(:CACHE_DIR, cache_dir)
    Snapshot.send(:remove_const, :SCREENSHOTS_DIR) if Snapshot.const_defined?(:SCREENSHOTS_DIR, false)
    Snapshot.const_set(:SCREENSHOTS_DIR, File.join(cache_dir, "screenshots"))

    launcher = Snapshot::SimulatorLauncherBase
    return if launcher.instance_variable_defined?(:@checklists_scoped_preparation)

    # Stock snapshot shuts down every booted simulator and patches machine-global
    # preferences before every test. The caller already booted the exact dedicated
    # device; all other preparation features are disabled in snapshot_options.
    launcher.prepend(Module.new do
      def prepare_simulators_for_launch(_device_types, language: nil, locale: nil) # rubocop:disable Lint/UnusedMethodArgument
        # Snapshot otherwise retries non-65 xcodebuild failures up to twenty
        # times independently of number_of_retries. Leave retries to an explicit
        # resume after diagnosis, including simulator-launch failures.
        self.current_number_of_retries_due_to_failing_simulator = 20
      end
    end)
    launcher.instance_variable_set(:@checklists_scoped_preparation, true)
  end

  def with_test_runner_environment(run_id, cache_dir)
    values = {
      "CHECKLISTS_SCOPED_SCREENSHOT_CAPTURE" => "1",
      "TEST_RUNNER_RUN_APP_STORE_SCREENSHOTS" => "1",
      "TEST_RUNNER_SCREENSHOT_CACHE_DIR" => cache_dir,
      "TEST_RUNNER_SCREENSHOT_CAPTURE_RUN_ID" => run_id
    }
    previous = values.to_h { |name, _value| [name, ENV[name]] }
    values.each { |name, value| ENV[name] = value }
    yield
  ensure
    previous&.each { |name, value| value.nil? ? ENV.delete(name) : ENV[name] = value }
  end

  def locale_arguments(locales)
    locales.flat_map { |locale| ["--locales", locale] }
  end

  def run_directory(run_id)
    File.join(@root, ".build", "screenshots", "runs", run_id)
  end

end
