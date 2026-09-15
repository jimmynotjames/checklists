require "minitest/autorun"
require "tmpdir"
require_relative "release_build"

class ReleaseBuildTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  class FakeRelease < ReleaseBuild
    attr_accessor :branch, :dirty, :untracked, :fail_commit
    attr_reader :commands

    def initialize(root)
      super
      @branch = "u/jimmyho/codex/testflight"
      @dirty = @untracked = ""
      @commands = []
    end

    def git(*args)
      @commands << args
      case args.first
      when "branch" then @branch
      when "status" then @dirty
      when "ls-files" then @untracked
      when "rev-parse" then "a" * 40
      when "diff" then PBXPROJ
      when "commit"
        raise "Commit failed" if @fail_commit
        "committed"
      else raise "Unexpected git call #{args.inspect}"
      end
    end

    def verify_secrets!; end
  end

  def setup
    FileUtils.mkdir_p(File.join(ROOT, "tmp"))
    @root = Dir.mktmpdir("release-test-", File.join(ROOT, "tmp"))
    FileUtils.mkdir_p(File.join(@root, ReleaseBuild::PROJECT))
    @path = File.join(@root, ReleaseBuild::PBXPROJ)
    @original = File.read(File.join(ROOT, ReleaseBuild::PBXPROJ))
    File.write(@path, @original)
    @release = FakeRelease.new(@root)
    @events = []
  end

  def teardown
    FileUtils.remove_entry(@root)
  end

  def run_beta(upload: nil, archive: nil)
    @release.beta(
      latest: lambda { |version| @events << [:latest, version]; 40 },
      archive: archive || lambda { |options| @events << [:archive, options]; "artifact.ipa" },
      upload: upload || lambda { |ipa| @events << [:upload, ipa] }
    )
  end

  def record
    JSON.parse(File.read(Dir[File.join(@root, "tmp/releases/*/release.json")].fetch(0)))
  end

  def test_success_only_changes_build_tokens_and_commits_after_upload
    run_beta
    assert_equal @original.gsub(/CURRENT_PROJECT_VERSION = \d+;/, "CURRENT_PROJECT_VERSION = 41;"), File.read(@path)
    assert_equal [:latest, :archive, :upload], @events.map(&:first)
    assert_equal @release.version, @events.first.last
    assert_equal "committed", record["status"]
    commit = @release.commands.find { |command| command.first == "commit" }
    assert_equal ["--", ReleaseBuild::PBXPROJ], commit.last(2)
    assert_includes commit, "--only"
    message = File.read(commit[commit.index("-F") + 1])
    assert_includes message, "Source-commit: #{'a' * 40}"
    assert_operator message.lines.first.strip.length, :<=, 72
  end

  def test_upload_failure_preserves_bump_and_uncertain_record_without_commit
    assert_raises(RuntimeError) { run_beta(upload: ->(_) { raise "Transport failed" }) }
    assert_equal "upload_started", record["status"]
    assert_includes File.read(@path), "CURRENT_PROJECT_VERSION = 41;"
    refute @release.commands.any? { |args| args.first == "commit" }
  end

  def test_archive_failure_never_uploads_or_commits
    assert_raises(RuntimeError) { run_beta(archive: ->(_) { raise "Archive failed" }) }
    assert_equal "archiving", record["status"]
    refute @events.any? { |event| event.first == :upload }
    refute @release.commands.any? { |args| args.first == "commit" }
  end

  def test_commit_failure_records_successful_upload
    @release.fail_commit = true
    assert_raises(RuntimeError) { run_beta }
    assert_equal "uploaded", record["status"]
  end

  def test_rejects_main_detached_dirty_and_untracked_source
    ["main", ""].each do |branch|
      @release.branch = branch
      assert_raises(RuntimeError) { run_beta }
    end
    @release.branch = "release"
    @release.dirty = " M source.swift"
    assert_raises(RuntimeError) { run_beta }
    @release.dirty = ""
    @release.untracked = "checklists/checklists/New.swift"
    assert_raises(RuntimeError) { run_beta }
    assert_empty @events
    assert_equal @original, File.read(@path)
  end

  def test_allows_untracked_codex_configuration
    @release.untracked = ".codex/hooks.json"
    run_beta
    assert_equal "committed", record["status"]
  end

  def test_real_git_records_upload_when_build_number_is_already_current
    release = ReleaseBuild.new(@root)
    def release.verify_secrets!; end
    release.git("init", "-b", "release-test")
    release.git("config", "user.name", "Release test")
    release.git("config", "user.email", "release-test@example.invalid")
    release.git("config", "commit.gpgsign", "false")
    File.write(File.join(@root, ".gitignore"), "tmp/\n")
    release.git("add", ".gitignore", ReleaseBuild::PBXPROJ)
    message = File.join(@root, "tmp", "initial-message.txt")
    FileUtils.mkdir_p(File.dirname(message))
    File.write(message, "Prepared test fixture.\n")
    release.git("commit", "-F", message)
    original_sha = release.git("rev-parse", "HEAD")
    current = @original[/CURRENT_PROJECT_VERSION = (\d+);/, 1].to_i
    path = release.beta(latest: ->(_) { current - 1 }, archive: ->(_) { "artifact.ipa" }, upload: ->(_) {})
    refute_equal original_sha, release.git("rev-parse", "HEAD")
    assert_equal "", release.git("diff", "HEAD^", "HEAD", "--", ReleaseBuild::PBXPROJ)
    assert_includes release.git("log", "-1", "--format=%B"), "Source-commit: #{original_sha}"
    assert_equal "committed", JSON.parse(File.read(path))["status"]
  end

  def test_archive_validation_preserves_project_without_git_or_provisioning
    with_env(ReleaseBuild::PROVISIONING_PROFILE_ENV, "reChecklist Distribution Profile") do
      @release.archive_only do |options|
        refute_includes options[:xcargs], "allowProvisioningUpdates"
        refute options.key?(:export_xcargs)
        assert options[:archive_path].start_with?(File.join(@root, "tmp/"))
        assert_equal(
          {
            signingStyle: "manual",
            teamID: ReleaseBuild::TEAM_ID,
            signingCertificate: ReleaseBuild::DISTRIBUTION_CERTIFICATE,
            provisioningProfiles: { ReleaseBuild::IDENTIFIER => "reChecklist Distribution Profile" }
          },
          options[:export_options]
        )
      end
    end
    assert_empty @release.commands
    assert_equal @original, File.read(@path)
  end

  def test_archive_validation_requires_provisioning_profile_env
    with_env(ReleaseBuild::PROVISIONING_PROFILE_ENV, nil) do
      assert_raises(RuntimeError) { @release.archive_only { |_options| } }
    end
  end

  def with_env(name, value)
    previous = ENV[name]
    ENV[name] = value
    yield
  ensure
    ENV[name] = previous
  end

  def test_source_change_during_archive_stops_before_upload
    assert_raises(RuntimeError) do
      run_beta(archive: lambda { |_|
        File.write(@path, File.read(@path) + "// changed\n")
        "artifact.ipa"
      })
    end
    refute @events.any? { |event| event.first == :upload }
  end

  def test_release_secret_bypass_rejected
    previous = ENV["SKIP_RELEASE_SECRETS_CHECK"]
    ENV["SKIP_RELEASE_SECRETS_CHECK"] = "1"
    assert_raises(RuntimeError) { ReleaseBuild.new(@root).verify_secrets! }
  ensure
    ENV["SKIP_RELEASE_SECRETS_CHECK"] = previous
  end
end
