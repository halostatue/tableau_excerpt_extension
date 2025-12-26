defmodule TableauExcerptExtensionTest do
  use TableauExcerptExtension.PageCase, async: true

  describe "excerpt processing" do
    test "adds excerpt to posts without one" do
      body = "First paragraph.\n\nSecond paragraph."
      excerpt = process_page(body)
      assert excerpt == "First paragraph."
    end

    test "preserves existing excerpt" do
      body = "First paragraph.\n\nSecond paragraph."
      excerpt = process_page(body, frontmatter: %{excerpt: "Custom excerpt"})
      assert excerpt == "Custom excerpt"
    end

    test "preserves empty string excerpt" do
      body = "First paragraph.\n\nSecond paragraph."
      excerpt = process_page(body, frontmatter: %{excerpt: ""})
      assert excerpt == ""
    end

    test "preserves nil excerpt" do
      body = "First paragraph.\n\nSecond paragraph."
      excerpt = process_page(body, frontmatter: %{excerpt: nil})
      assert excerpt == nil
    end

    test "processes page with custom marker configuration" do
      body = """
      First paragraph content.

      <!--fold-->

      Rest of the content.
      """

      excerpt = process_page(body, marker: %{pattern: "<!--\\s*fold\\s*-->"})
      assert excerpt == "First paragraph content."
    end

    test "processes page with word-based fallback" do
      body = """
      This is a longer paragraph with many words that should be truncated.

      Second paragraph.
      """

      excerpt =
        process_page(body,
          fallback: %{
            strategy: :word,
            count: 5,
            more: "..."
          }
        )

      assert excerpt == "This is a longer paragraph..."
    end

    test "processes page with sentence-based fallback" do
      body = """
      First sentence here. Second sentence follows. Third sentence too.

      Second paragraph.
      """

      excerpt =
        process_page(body,
          fallback: %{
            strategy: :sentence,
            count: 2
          }
        )

      assert excerpt == "First sentence here. Second sentence follows."
    end

    test "handles question marks in sentence fallback" do
      body = """
      What is this? Another question follows? A third one too.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      assert excerpt == "What is this? Another question follows?"
    end

    test "handles exclamation marks in sentence fallback" do
      body = """
      Look out! Another exclamation follows! A third one too.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      assert excerpt == "Look out! Another exclamation follows!"
    end

    test "handles mixed punctuation in sentence fallback" do
      body = """
      This is a statement. Is this a question? Yes, it is! More content follows.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 3})
      assert excerpt == "This is a statement. Is this a question? Yes, it is!"
    end

    test "handles quotes after punctuation in sentence fallback" do
      body = """
      He said "Hello." She replied "Goodbye." They parted ways.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      assert excerpt == ~s|He said "Hello." She replied "Goodbye."|
    end

    test "handles quotes before punctuation in sentence fallback" do
      body = """
      He said "Hello". She replied "Goodbye". They parted ways.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      assert excerpt == ~s|He said "Hello". She replied "Goodbye".|
    end

    test "handles single quotes in sentence fallback" do
      body = """
      He said 'Hello.' She replied 'Goodbye.' They parted ways.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      assert excerpt == "He said 'Hello.' She replied 'Goodbye.'"
    end

    test "handles unicode punctuation in sentence fallback" do
      body = """
      Really‽ Another interrobang follows‽ A third one too.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      assert excerpt == "Really‽ Another interrobang follows‽"
    end

    test "handles complex quote combinations in sentence fallback" do
      body = """
      She asked "Are you sure?" He replied "Absolutely!" They agreed.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      assert excerpt == ~s|She asked "Are you sure?" He replied "Absolutely!"|
    end

    test "handles sentences with no ending punctuation" do
      body = """
      This sentence has no ending

      This one does. Another follows.
      """

      excerpt = process_page(body, fallback: %{strategy: :sentence, count: 2})
      # Should take the incomplete sentence since it's the first paragraph
      assert excerpt == "This sentence has no ending"
    end

    test "converts reference links to inline links" do
      body = """
      Check out [this link][ref] for more info.

      <!--more-->

      More content here.

      [ref]: https://example.com
      """

      excerpt = process_page(body)
      assert excerpt == "Check out [this link](https://example.com) for more info."
    end

    test "strips footnotes from excerpt" do
      body = """
      This has a footnote[^1] in the middle.

      <!--more-->

      [^1]: The footnote definition.
      """

      excerpt = process_page(body)
      assert excerpt == "This has a footnote in the middle."
    end

    test "removes marker from body when configured" do
      body = """
      First paragraph.

      <!--more-->

      Second paragraph.
      """

      result = process_page(body, parse: false, marker: %{remove: true})
      assert {:ok, %{posts: [%{body: updated_body}]}} = result
      refute String.contains?(updated_body, "<!--more-->")
    end

    test "preserves marker in body when configured" do
      body = """
      First paragraph.

      <!--more-->

      Second paragraph.
      """

      result = process_page(body, parse: false, marker: %{remove: false})
      assert {:ok, %{posts: [%{body: updated_body}]}} = result
      assert String.contains?(updated_body, "<!--more-->")
    end

    test "handles reference links with titles" do
      body = """
      Check out [this link][ref] for more info.

      <!--more-->

      [ref]: https://example.com "Example Title"
      """

      excerpt = process_page(body)
      assert excerpt == ~s|Check out [this link](https://example.com "Example Title") for more info.|
    end

    test "handles reference links with no matching definition" do
      body = """
      Check out [this link][missing] for more info.

      <!--more-->

      [ref]: https://example.com
      """

      excerpt = process_page(body)
      assert excerpt == "Check out this link for more info."
    end

    test "handles implicit reference links" do
      body = """
      Check out [example][] for more info.

      <!--more-->

      [example]: https://example.com
      """

      excerpt = process_page(body)
      assert excerpt == "Check out [example](https://example.com) for more info."
    end

    test "strips leading headings from excerpt" do
      body = """
      # Heading

      ## Another heading

      First paragraph content.

      <!--more-->

      More content.
      """

      excerpt = process_page(body)
      assert excerpt == "First paragraph content."
    end

    test "strips horizontal rules from excerpt" do
      body = """
      ---

      ***

      ___

      First paragraph content.

      <!--more-->

      More content.
      """

      excerpt = process_page(body)
      assert excerpt == "First paragraph content."
    end

    test "handles word truncation ending with terminal punctuation" do
      body = """
      This is a sentence. Another sentence follows here.

      Second paragraph.
      """

      excerpt = process_page(body, fallback: %{strategy: :word, count: 4, more: "..."})
      assert excerpt == "This is a sentence."
    end

    test "falls back when marker excerpt is empty after cleaning" do
      # Test case where marker extraction returns {nil, body} because
      # the excerpt before the marker is empty after cleaning
      body = """
      # Just a heading

      <!--more-->

      Content after marker.
      """

      excerpt = process_page(body)
      # Should fall back to paragraph extraction since cleaned excerpt is nil
      assert excerpt == "Content after marker."
    end

    test "handles case where fallback is disabled and no marker present" do
      # Test case where fallback is disabled and no marker is found
      body = """
      This is just regular content without any marker.

      More content here.
      """

      # Configure fallback to be disabled
      result = process_page(body, parse: false, fallback: false)
      assert {:ok, %{posts: [post]}} = result
      # Should have no excerpt field added since no marker and fallback disabled
      refute Map.has_key?(post, :excerpt)
    end

    test "handles case where marker is disabled but fallback is enabled" do
      # Test case where marker is disabled but fallback works
      body = """
      This is the first paragraph that should be excerpted.

      This is the second paragraph.
      """

      # Configure marker to be disabled, fallback enabled
      excerpt = process_page(body, marker: false)
      assert excerpt == "This is the first paragraph that should be excerpted."
    end

    test "handles word fallback when paragraph has fewer words than count" do
      # Test case where word count is less than configured count
      body = """
      Short paragraph.

      Second paragraph here.
      """

      # Configure word fallback with count higher than actual words
      excerpt = process_page(body, fallback: %{strategy: :word, count: 10, more: "..."})
      assert excerpt == "Short paragraph."
    end
  end
end
