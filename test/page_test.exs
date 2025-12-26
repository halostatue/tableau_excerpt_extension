defmodule PageTest do
  use TableauExcerptExtension.PageCase, async: true

  alias Tableau.PostExtension

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
