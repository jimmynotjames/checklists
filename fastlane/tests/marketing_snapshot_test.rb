require "minitest/autorun"
require "ostruct"
require_relative "../lib/marketing_snapshot"

class MarketingSnapshotTest < Minitest::Test
  def test_only_public_fields_are_exported_without_rewriting_text
    files = {}
    record = OpenStruct.new(locale: "en-US", name: "Original \n", subtitle: "",
                            privacy_policy_url: nil, password: "private")
    MarketingSnapshot.localized_files([record], MarketingSnapshot::INFO_FIELDS, files)
    assert_equal({ "metadata/en-US/name.txt" => "Original \n", "metadata/en-US/subtitle.txt" => "" }, files)
  end

  def test_locale_cannot_escape_output_directory
    assert_raises(RuntimeError) do
      MarketingSnapshot.localized_files([OpenStruct.new(locale: "../../outside")], {}, {})
    end
  end

  def test_other_locale_codes_are_preserved_for_future_translations
    files = {}
    MarketingSnapshot.localized_files([OpenStruct.new(locale: "zh-Hant", name: "Text")], { "name" => :name }, files)
    assert_equal "Text", files["metadata/zh-Hant/name.txt"]
  end
end
