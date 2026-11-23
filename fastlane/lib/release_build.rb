require "fileutils"
require "json"
require "open3"
require "time"

# Local release bookkeeping. Never parses credentials or retries an upload.
class ReleaseBuild
  PROJECT = "checklists/checklists.xcodeproj".freeze
  PBXPROJ = "#{PROJECT}/project.pbxproj".freeze
  IDENTIFIER = "com.jimmyho.checklists".freeze

  def initialize(root)
    @root = root
  end

  def git(*args)
    output, status = Open3.capture2e("git", "-C", @root, *args)
    raise "git #{args.first} failed: #{output}" unless status.success?
    output.strip
  end

  def project_text
    File.read(File.join(@root, PBXPROJ))
  end

  def app_settings(text)
    blocks = text.scan(/buildSettings = \{.*?\n\s*\};/m).select do |block|
      block.match?(/PRODUCT_BUNDLE_IDENTIFIER = #{Regexp.escape(IDENTIFIER)};/)
    end
    raise "Expected exactly two app build configurations" unless blocks.length == 2
    blocks
  end

  def version
    versions = app_settings(project_text).map do |block|
      block[/MARKETING_VERSION = (\d+(?:\.\d+){0,2});/, 1]
    end
    raise "App configurations need one matching numeric marketing version" if versions.include?(nil) || versions.uniq.length != 1
    versions.first
  end

  def set_build_number(number)
    raise "Build number must be a positive integer" unless number.is_a?(Integer) && number.positive?
    original = project_text
    updated = original.dup
    app_settings(original).each do |block|
      raise "Expected one numeric app build number" unless block.scan(/CURRENT_PROJECT_VERSION = \d+;/).length == 1
      updated.sub!(block, block.sub(/CURRENT_PROJECT_VERSION = \d+;/, "CURRENT_PROJECT_VERSION = #{number};"))
    end
    File.write(File.join(@root, PBXPROJ), updated)
  end

  def verify_secrets!
    raise "Shipping lanes reject SKIP_RELEASE_SECRETS_CHECK=1" if ENV["SKIP_RELEASE_SECRETS_CHECK"] == "1"
    success = system("bash", File.join(@root, "scripts/verify_release_secrets.sh"))
    raise "Release secrets check failed" unless success
  end

  # Xcode's own export method name; manageAppVersionAndBuildNumber is off because the beta lane
  # allocates CURRENT_PROJECT_VERSION itself.
  EXPORT_OPTIONS = <<~PLIST.freeze
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>destination</key><string>export</string>
      <key>manageAppVersionAndBuildNumber</key><false/>
      <key>method</key><string>app-store-connect</string>
      <key>signingStyle</key><string>automatic</string>
      <key>teamID</key><string>EDMB3Z5KAY</string>
    </dict>
    </plist>
  PLIST

  # Plain xcodebuild instead of fastlane's build_app: gym parses the project with the xcodeproj
  # gem, which rejects the array-valued shellScript Xcode writes (#418).
  def archive_and_export(output)
    archive_path = File.join(output, "checklists.xcarchive")
    logs = File.join(output, "logs")
    FileUtils.mkdir_p(logs)
    plist = File.join(output, "ExportOptions.plist")
    File.write(plist, EXPORT_OPTIONS)
    xcodebuild!("archive", File.join(logs, "archive.log"),
                "clean", "archive", "-project", File.join(@root, PROJECT), "-scheme", "checklists",
                "-configuration", "Release", "-destination", "generic/platform=iOS",
                "-archivePath", archive_path, "-derivedDataPath", File.join(@root, "tmp/release-derived-data"),
                "-allowProvisioningUpdates", "CODE_SIGN_STYLE=Automatic")
    xcodebuild!("export", File.join(logs, "export.log"),
                "-exportArchive", "-archivePath", archive_path, "-exportPath", output,
                "-exportOptionsPlist", plist, "-allowProvisioningUpdates")
    ipa = File.join(output, "checklists.ipa")
    raise "Export succeeded but wrote no #{ipa}" unless File.file?(ipa)
    ipa
  end

  def xcodebuild!(stage, log, *args)
    puts "xcodebuild #{stage}: logging to #{log}"
    return if system("xcodebuild", *args, out: log, err: [:child, :out])

    errors = File.readlines(log).grep(/error:/).first(20).join
    raise "xcodebuild #{stage} failed; see #{log}\n#{errors}"
  end

  def archive_only(archive: method(:archive_and_export))
    verify_secrets!
    output = File.join(@root, "tmp/archive-validation")
    FileUtils.mkdir_p(output)
    archive.call(output)
  end

  def beta(latest:, upload:, archive: method(:archive_and_export))
    branch = git("branch", "--show-current")
    raise "Run beta on a release branch, never main or detached HEAD" if branch.empty? || branch == "main"
    raise "Commit tracked changes before beta" unless git("status", "--porcelain", "--untracked-files=no").empty?
    raise "Remove or commit untracked source before beta" unless untracked_source.empty?
    verify_secrets!
    marketing_version = version
    source_sha = git("rev-parse", "HEAD")
    output = File.join(@root, "tmp/releases", "#{Time.now.utc.strftime('%Y%m%dT%H%M%S')}-#{Process.pid}")
    FileUtils.mkdir_p(output)
    record_path = File.join(output, "release.json")
    record = { source_sha: source_sha, version: marketing_version, branch: branch, status: "allocating" }
    persist = lambda do |status|
      record[:status] = status
      File.write(record_path, JSON.pretty_generate(record) + "\n")
    end
    persist.call("allocating")
    # Explicit version avoids accidentally numbering a different TestFlight train.
    number = Integer(latest.call(marketing_version).to_s, 10) + 1
    record[:build] = number
    persist.call("archiving")
    set_build_number(number)
    expected_project = project_text
    ipa = archive.call(output)
    # Archive/export tools must not change source under the bookkeeping commit.
    verify_source!(source_sha, expected_project)
    persist.call("upload_started")
    upload.call(ipa)
    persist.call("uploaded")
    verify_source!(source_sha, expected_project)
    message_path = File.join(output, "commit-message.txt")
    File.write(message_path, "Updated TestFlight build number to #{number}.\n\nSource-commit: #{source_sha}\nVersion: #{marketing_version}\nBuild: #{number}\n")
    # --only prevents unrelated staged changes from entering this commit.
    # A version's ASC next number can already equal the local project value.
    # Keep a provenance commit in that case rather than failing after upload.
    git("commit", "--only", "--allow-empty", "-F", message_path, "--", PBXPROJ)
    persist.call("committed")
    record_path
  rescue StandardError
    warn "Release stopped; preserve project changes and inspect #{record_path}. If upload_started, check ASC before retrying." if record_path
    raise
  end

  def verify_source!(sha, expected_project)
    raise "HEAD changed during release" unless git("rev-parse", "HEAD") == sha
    changed = (git("diff", "--name-only", "HEAD").split("\n") - [PBXPROJ])
    raise "Tracked source changed during release" unless changed.empty?
    raise "Project changed during release" unless project_text == expected_project
    raise "Untracked source appeared during release" unless untracked_source.empty?
  end

  def untracked_source
    git("ls-files", "--others", "--exclude-standard").split("\n").reject { |path| path.start_with?(".codex/") }
  end
end
