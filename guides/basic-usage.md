# Basic Usage

TableauExcerptExtension extracts excerpts from your Tableau posts for use in
post index pages and feeds. Simply enable the extension in your
`config/config.exs` and it will now process all posts to ensure that there's an
`excerpt` value.

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true
```

## Post Processing

If a post already has an `excerpt` field in its frontmatter, it's left unchanged
(regardless of value). Otherwise, the extension scans the post body using one of
three methods.

1. **Range markers**: Content between `<!--excerpt:start-->` and
   `<!--excerpt:end-->` will be extracted as the `excerpt`;
2. **Split marker**: Content before `<!--more-->` will be extracted as the
   `excerpt`; or
3. **Structural extraction**: The first paragraph of content will be extracted
   as the `excerpt`.

The range markers, the split marker, and the fallback strategy are all
configurable. See the `TableauExcerptExtension` module documentation for
details.

## Rendering Excerpts

To display excerpts on a post index page, update your page template:

```elixir
defmodule MySite.PostsPage do
  @moduledoc "/posts index page for my site"

  use Tableau.Page,
    layout: MySite.RootLayout,
    permalink: "/posts",
    title: "All Posts"

  def template(assigns) do
    posts =
      assigns.site.pages
      |> Enum.filter(& &1[:__tableau_post_extension__])
      |> Enum.sort_by(& &1.date, {:desc, Date})

    temple do
      ul do
        for post <- posts do
          render_post_summary(post)
        end
      end
    end
  end

  defp render_post_summary(post) do
    li do
      h3 do
        a href: post.permalink, do: post.title
      end

      render_post_excerpt(post)
    end
  end

  defp render_post_excerpt(%{excerpt: excerpt}) when not in [nil, ""] do
    div do
      Tableau.markdown(excerpt)
    end
  end

  defp render_post_excerpt(_), do: nil
end
```

## Strategies for Excerpt Extraction

`TableauExcerptExtension` supports three modes of pulling an excerpt from the
post. Two of them (range and split markers) require specific modification to the
source content.

### Range Marker Extraction

Use `<!--excerpt:start-->` and `<!--excerpt:end-->` to extract a specific
section from anywhere in your post. This will most commonly be on paragraphs,
but could be anywhere in the text.

```markdown
---
title: My Post
date: 2026-01-15
---

This introduction won't be in the excerpt.

<!--excerpt:start-->

This specific section will be the excerpt.

It can span multiple paragraphs.

<!--excerpt:end-->

More content here that won't be in the excerpt.
```

Range markers take precedence over `<!--more-->` markers, allowing you to choose
exactly what appears in the excerpt regardless of post structure.

Range marker extraction includes _any_ content elements within the range
markers, except those transformed in excerpt post-processing.

### Split Marker Extraction

Add `<!--more-->` to your post markdown where you want the excerpt to end. As
with range marker extraction, this will typically be after a complete paragraph,
but may be anywhere in the text.

```markdown
---
title: My Post
date: 2026-01-15
---

This is the introduction paragraph that will appear in the excerpt.

This is more detail that will also be in the excerpt.

<!--more-->

This content will only appear on the full post page, not in the excerpt.
```

Split marker extraction includes _any_ content elements before the split marker,
except those transformed in excerpt post-processing.

### Structural Extraction

The third method pulls a configured number of paragraphs, sentences (up to the
end of the first paragraph), or words (up to the end of the first paragraph).

Paragraphs are defined as blocks of text separated by multiple newlines (at
least `\n\n`).

Sentences are defined as blocks of text separated by common Latin language
punctuation characters (`.`, `!`, `?`, and `‽`), optionally trailed by English
quotes (`'` or `"`).

Words are defined as space separated text.

Prior to structural extraction, the format processor's `filter_paragraphs/1`
function is called to ensure that only paragraph-like blocks are included in
processing. For Markdown content, this excludes headings, horizontal rules, and
similar content.

## Excerpt Post-Processing

After an excerpt is extracted from the content, it may have content which is
incomplete, so the format processor's `clean/2` function is called with the
excerpt and the full post body for resolution.

For Markdown content, this ensures that both footnote references (`[^1]`) and
definitions (`[^1]: text`) are removed, and that reference links (`[link][ref]`)
are converted to inline links (`[link](uri)`). This ensures excerpts are clean
and self-contained, even when extracted from posts that use advanced markdown
features.
