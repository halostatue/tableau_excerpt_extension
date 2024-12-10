defmodule TableauExcerptExtensionTest do
  use TableauExcerptExtension.PageCase, async: true

  alias Tableau.PostExtension

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
      import ExUnit.CaptureLog

      log =
        capture_log(fn ->
          assert {:ok, %{enabled: false, fallback: false, marker: false}} =
                   TableauExcerptExtension.config(%{marker: false, fallback: false})
        end)

      assert log =~ "[TableauExcerptExtension] Disabling because both marker and fallback"
      assert log =~ "are disabled"
    end
  end

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

  describe "integration with PostExtension" do
    @describetag :tmp_dir

    setup %{tmp_dir: dir} do
      assert {:ok, post_config} =
               PostExtension.config(%{
                 dir: dir,
                 enabled: true,
                 layout: Blog.PostLayout
               })

      token = %{
        site: %{config: %{converters: [md: Tableau.MDExConverter]}},
        extensions: %{
          posts: %{config: post_config},
          excerpt: %{config: TableauExcerptExtension.PageCase.build_config()}
        },
        graph: Graph.new()
      }

      [token: token]
    end

    test "processes posts with excerpt markers correctly", %{token: token, tmp_dir: dir} do
      File.write!(Path.join(dir, "test-post.md"), """
      ---
      title: Test Post
      date: 2024-01-01
      ---

      This is the excerpt content.

      <!--more-->

      This is the full post content that should not appear in excerpts.

      More content here.
      """)

      # Process through both extensions
      {:ok, token} = PostExtension.pre_build(token)
      {:ok, token} = TableauExcerptExtension.pre_build(token)

      # Verify excerpt was extracted and marker was removed
      [post] = token.posts
      assert post.excerpt == "This is the excerpt content."
      refute String.contains?(post.body, "<!--more-->")
      assert String.contains?(post.body, "This is the full post content")
    end

    test "processes multiple posts with different excerpt scenarios", %{token: token, tmp_dir: dir} do
      # Create multiple posts with different excerpt scenarios
      File.write!(Path.join(dir, "post-with-marker.md"), """
      ---
      title: Post with Marker
      date: 2024-01-01
      ---

      First paragraph excerpt.

      <!--more-->

      Full content continues here.
      """)

      File.write!(Path.join(dir, "post-with-fallback.md"), """
      ---
      title: Post with Fallback
      date: 2024-01-02
      ---

      This is the first paragraph that should be used as excerpt.

      This is the second paragraph.
      """)

      File.write!(Path.join(dir, "post-with-existing-excerpt.md"), """
      ---
      title: Post with Existing Excerpt
      date: 2024-01-03
      excerpt: Custom excerpt from frontmatter
      ---

      This is the body content.

      <!--more-->

      More body content.
      """)

      # Process through both extensions
      {:ok, token} = PostExtension.pre_build(token)
      {:ok, token} = TableauExcerptExtension.pre_build(token)

      # Verify excerpts were processed correctly
      posts_by_title = Map.new(token.posts, &{&1.title, &1})

      # Post with marker: excerpt extracted, marker removed
      marker_post = posts_by_title["Post with Marker"]
      assert marker_post.excerpt == "First paragraph excerpt."
      refute String.contains?(marker_post.body, "<!--more-->")

      # Post with fallback: first paragraph used as excerpt
      fallback_post = posts_by_title["Post with Fallback"]
      assert fallback_post.excerpt == "This is the first paragraph that should be used as excerpt."

      # Post with existing excerpt: preserved unchanged, body not modified
      existing_post = posts_by_title["Post with Existing Excerpt"]
      assert existing_post.excerpt == "Custom excerpt from frontmatter"
      # Body should be unchanged since excerpt already exists
      assert String.contains?(existing_post.body, "<!--more-->")
    end

    test "preserves marker in body when configured", %{token: token, tmp_dir: dir} do
      # Configure to preserve marker
      preserve_config = TableauExcerptExtension.PageCase.build_config(marker: %{remove: false})
      token = put_in(token.extensions.excerpt.config, preserve_config)

      File.write!(Path.join(dir, "preserve-marker-post.md"), """
      ---
      title: Preserve Marker Post
      date: 2024-01-01
      ---

      Excerpt content here.

      <!--more-->

      Full content after marker.
      """)

      # Process through both extensions
      {:ok, token} = PostExtension.pre_build(token)
      {:ok, token} = TableauExcerptExtension.pre_build(token)

      [post] = token.posts
      assert post.excerpt == "Excerpt content here."
      # Verify marker was preserved in body
      assert String.contains?(post.body, "<!--more-->")
    end

    test "handles reference links in excerpts", %{token: token, tmp_dir: dir} do
      File.write!(Path.join(dir, "reference-links-post.md"), """
      ---
      title: Reference Links Post
      date: 2024-01-01
      ---

      Check out [this link][ref] for more info.

      <!--more-->

      More content here.

      [ref]: https://example.com "Example Site"
      """)

      # Process through both extensions
      {:ok, token} = PostExtension.pre_build(token)
      {:ok, token} = TableauExcerptExtension.pre_build(token)

      [post] = token.posts
      # Reference link should be converted to inline link in excerpt
      assert post.excerpt == ~s|Check out [this link](https://example.com "Example Site") for more info.|
      # Original body should still have reference definition
      assert String.contains?(post.body, "[ref]: https://example.com")
    end

    test "handles different fallback strategies", %{token: token, tmp_dir: dir} do
      # Configure word-based fallback
      word_config = TableauExcerptExtension.PageCase.build_config(fallback: %{strategy: :word, count: 5, more: "..."})
      token = put_in(token.extensions.excerpt.config, word_config)

      File.write!(Path.join(dir, "word-fallback-post.md"), """
      ---
      title: Word Fallback Post
      date: 2024-01-01
      ---

      This is a very long sentence with many words that should be truncated.

      Second paragraph here.
      """)

      # Process through both extensions
      {:ok, token} = PostExtension.pre_build(token)
      {:ok, token} = TableauExcerptExtension.pre_build(token)

      [post] = token.posts
      assert post.excerpt == "This is a very long..."
    end
  end
end
