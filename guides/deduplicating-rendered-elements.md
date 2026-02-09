# Deduplicating Rendered Elements in Excerpts

When rendering multiple post excerpts on an index page, you may encounter
duplicate elements like `<script>` or `<style>` tags if your posts contain
inline scripts (e.g., from mermaid diagrams, syntax highlighters) or custom
styling.

This guide shows how to deduplicate these rendered elements when displaying
excerpts.

## The Problem

If multiple posts on your index page contain the same script or style element,
you'll end up with duplicates:

```html
<div class="post-excerpt">
  <style>
    .custom-diagram {
      border: 1px solid #ccc;
    }
  </style>
  <script type="module">
    import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/...";
  </script>
  <!-- excerpt content -->
</div>

<div class="post-excerpt">
  <style>
    .custom-diagram {
      border: 1px solid #ccc;
    }
  </style>
  <script type="module">
    import mermaid from "https://cdn.jsdelivr.net/npm/mermaid@11/...";
  </script>
  <!-- excerpt content -->
</div>
```

This wastes bandwidth and can cause initialization conflicts or style
duplication.

## Solution: Element Deduplication

The following example deduplicates `<script>` tags, but the same pattern works
for `<style>` tags or other repeated elements.

```elixir
defmodule MySite.PostsPage do
  use Tableau.Page,
    layout: MySite.RootLayout,
    permalink: "/posts",
    title: "All Posts"

  def template(assigns) do
    posts =
      assigns.site.pages
      |> Enum.filter(& &1[:__tableau_post_extension__])
      |> Enum.sort_by(& &1.date, {:desc, Date})

    # Collect and deduplicate scripts from all excerpts
    {posts, scripts} = process_excerpts(posts)

    temple do
      ul class: "post-list" do
        for post <- posts do
          li class: "post-list-item" do
            h3 class: "post-list-title" do
              a href: post.permalink, do: post.title
            end

            if post[:excerpt] && post[:excerpt] != "" do
              div class: "post-list-excerpt" do
                post.excerpt
              end
            end
          end
        end
      end

      # Inject deduplicated scripts at the end
      for script <- scripts do
        script
      end
    end
  end

  defp process_excerpts(posts) do
    {posts_with_cleaned_excerpts, scripts} =
      Enum.reduce(posts, {[], MapSet.new()}, fn post, {acc_posts, acc_scripts} ->
        excerpt = post[:excerpt] || ""
        html = Tableau.markdown(excerpt)
        post_scripts = extract_scripts(html)
        cleaned = strip_scripts(html)

        updated_post = Map.put(post, :excerpt, cleaned)
        updated_scripts = MapSet.union(acc_scripts, MapSet.new(post_scripts))

        {[updated_post | acc_posts], updated_scripts}
      end)

    {Enum.reverse(posts_with_cleaned_excerpts), MapSet.to_list(scripts)}
  end

  defp extract_scripts(html) do
    ~r/<script\b[^>]*>.*?<\/script>/s
    |> Regex.scan(html)
    |> Enum.map(fn [script] -> script end)
  end

  defp strip_scripts(html) do
    String.replace(html, ~r/<script\b[^>]*>.*?<\/script>/s, "")
  end
end
```

### How It Works

1. **`process_excerpts/1`** - Processes all posts in a single reduce, returning
   posts with cleaned excerpt HTML and a deduplicated set of scripts

2. **`extract_scripts/1`** - Uses regex to find all `<script>` tags in the HTML

3. **`strip_scripts/1`** - Removes all `<script>` tags from the HTML

4. **Deduplication** - Uses `MapSet` to automatically deduplicate identical
   scripts

5. **Rendering** - Posts with cleaned excerpts render inline, collected scripts
   render once at the end

## Additional Transformations

The same processing pipeline can handle other transformations beyond simple
deduplication. For example, if your posts contain Mermaid diagrams with
sequential IDs (`id="mermaid-1"`), each excerpt will independently generate
`mermaid-1`, causing ID collisions when multiple excerpts appear on the same
page.

You could extend `process_excerpts/1` to renumber these IDs sequentially across
all excerpts, or transform them to use post-specific prefixes. The
implementation is then a simple matter of programming.
