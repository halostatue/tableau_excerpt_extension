defmodule ConfigTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias TableauExcerptExtension.Processor.Markdown

  describe "config/1" do
    test "accepts keyword list config" do
      assert {:ok, %{enabled: true}} = TableauExcerptExtension.config(enabled: true)
    end

    test "accepts map config" do
      assert {:ok, %{enabled: true}} = TableauExcerptExtension.config(%{enabled: true})
    end

    test "defaults enabled to false" do
      assert {:ok, %{enabled: false}} = TableauExcerptExtension.config(%{})
    end

    test "accepts fallback and marker as lists" do
      assert {:ok, %{fallback: %{}, marker: %{}}} =
               TableauExcerptExtension.config(fallback: [count: 2], marker: [remove: false])
    end

    test "validates fallback.strategy" do
      assert {:error, "fallback.strategy must be one of :paragraph, :sentence, or :word, got: :invalid"} =
               TableauExcerptExtension.config(%{fallback: %{strategy: :invalid}})
    end

    test "validates fallback.count" do
      assert {:error, "fallback.count must be a positive integer, got: 0"} =
               TableauExcerptExtension.config(%{fallback: %{count: 0}})

      assert {:error, "fallback.count must be a positive integer, got: \"invalid\""} =
               TableauExcerptExtension.config(%{fallback: %{count: "invalid"}})
    end

    test "validates marker.pattern regex" do
      assert {:error, "marker.pattern must be a valid regular expression, got: \"[\""} =
               TableauExcerptExtension.config(%{marker: %{pattern: "["}})
    end

    test "compiles the marker.pattern regex" do
      assert {:ok, %{marker: %{pattern: %Regex{}}}} =
               TableauExcerptExtension.config(%{marker: %{pattern: "<!--\\s*(?:more|fold)\\s*-->"}})
    end

    test "applies default counts based on strategy" do
      {:ok, config} = TableauExcerptExtension.config(%{fallback: %{strategy: :paragraph}})
      assert config.fallback.count == 1

      {:ok, config} = TableauExcerptExtension.config(%{fallback: %{strategy: :sentence}})
      assert config.fallback.count == 2

      {:ok, config} = TableauExcerptExtension.config(%{fallback: %{strategy: :word}})
      assert config.fallback.count == 25
    end

    test "validates range.start regex" do
      assert {:error, "range.start and range.end must be valid regular expressions"} =
               TableauExcerptExtension.config(%{range: %{start: "["}})
    end

    test "validates range.end regex" do
      assert {:error, "range.start and range.end must be valid regular expressions"} =
               TableauExcerptExtension.config(%{range: %{end: "["}})
    end

    test "compiles range patterns to regexes" do
      {:ok, config} =
        TableauExcerptExtension.config(%{range: %{start: "<!--\\s*start\\s*-->", end: "<!--\\s*end\\s*-->"}})

      assert %Regex{} = config.range.start_pattern
      assert %Regex{} = config.range.end_pattern
    end

    test "accepts processors as keyword list" do
      {:ok, config} = TableauExcerptExtension.config(processors: [md: Markdown])
      assert config.processors.md == Markdown
    end

    test "accepts processors as map" do
      {:ok, config} = TableauExcerptExtension.config(%{processors: %{md: Markdown}})
      assert config.processors.md == Markdown
    end

    test "allows marker and fallback to be disabled" do
      assert {:ok, %{marker: false, fallback: false}} =
               TableauExcerptExtension.config(%{marker: false, fallback: false})
    end

    test "allows range to be disabled" do
      assert {:ok, %{range: false}} =
               TableauExcerptExtension.config(%{range: false})
    end

    test "disables extension when all extraction methods are disabled" do
      log =
        capture_log(fn ->
          assert {:ok, %{enabled: false, range: false, marker: false, fallback: false}} =
                   TableauExcerptExtension.config(%{range: false, marker: false, fallback: false})
        end)

      assert log =~ "[TableauExcerptExtension] Disabled because no extraction method is enabled"
    end
  end
end
