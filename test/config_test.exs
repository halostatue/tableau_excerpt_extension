defmodule ConfigTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

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

    test "allows marker and fallback to be disabled" do
      log =
        capture_log(fn ->
          assert {:ok, %{enabled: false, fallback: false, marker: false}} =
                   TableauExcerptExtension.config(%{marker: false, fallback: false})
        end)

      assert log =~ "[TableauExcerptExtension] Disabling because both marker and fallback"
      assert log =~ "are disabled"
    end
  end
end
