# TableauExcerptExtension

- code :: <https://github.com/halostatue/tableau_excerpt_extension>
- issues :: <https://github.com/halostatue/tableau_excerpt_extension/issues>

A Tableau extension that automatically extracts excerpts from posts.

## Overview

The excerpt extension processes your Tableau markdown posts and extracts an
excerpt for use in post index pages.

If a post already has an `excerpt` field, it is unmodified. Otherwise, the
content up to `<!--more-->` or the first paragraph is chosen.

TableauExcerptExtension is markdown-aware and will convert reference links
(`[link][ref]`) to inline links (`[link](uri)`) and remove footnotes (`[^1]`).

## Usage

TableauExcerptExtension mostly works automatically once configured.

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true
```

To take advantage of the post `excerpt`, post index pages should be updated to
render it:

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
      if Enum.empty?(posts) do
        p do
          "No posts yet. Check back soon!"
        end
      else
        ul do
          for post < -posts do
            li do
              h3 do
                a href: post.permalink, do: post.title
              end

              if post[:excerpt] && post[:excerpt] != "" do
                div do
                  Tableau.markdown(excerpt)
                end
              end
            end
          end
        end
      end
    end
  end
end
```

## Installation

TableauExcerptExtension can be installed by adding `tableau_excerpt_extension`
to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tableau_excerpt_extension, "~> 1.0"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

TableauExcerptExtension follows [Semantic Versioning 2.0][semver].

[12f]: https://12factor.net/
[docs]: https://hexdocs.pm/tableau_excerpt_extension
[semver]: http://semver.org/
