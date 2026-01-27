# TableauExcerptExtension Usage Rules

TableauExcerptExtension is a Tableau extension that automatically extracts
excerpts from Markdown posts.

## Core Principle

If a post already has an `excerpt` field, it is unmodified. Otherwise, if the
content contains the excerpt marker (default `<!--more-->`), the excerpt is the
content before it. If no marker is found, the configured fallback strategy
extracts content automatically.

## Configuration

```elixir
# config/config.exs
config :tableau, TableauExcerptExtension,
  enabled: true,
  marker: %{
    pattern: "<!--\\s*more\\s*-->",
    remove: true
  },
  fallback: %{
    strategy: :paragraph,
    count: 1,
    more: "…"
  }
```

### Required Configuration

- `:enabled` (default `false`) - Enable/disable the extension

### Optional Configuration

- `:marker` - Excerpt marker configuration (set to `false` to disable)
  - `:pattern` (default `"<!--\\s*more\\s*-->"`) - Regex pattern string
  - `:remove` (default `true`) - Remove marker from post body

- `:fallback` - Fallback extraction strategy (set to `false` to disable)
  - `:strategy` (default `:paragraph`) - `:paragraph`, `:sentence`, or `:word`
  - `:count` - Number of units to extract (defaults vary by strategy)
  - `:more` (default `"…"`) - Suffix for truncated word excerpts

## Decision Guide: When to Use What

### Choose Your Marker Pattern

**Use default `"<!--\\s*more\\s*-->"` when:**

- Standard HTML comment marker is sufficient
- Compatibility with other static site generators
- Simple, recognizable marker

**Use custom pattern when:**

- Different marker convention in existing content
- Need multiple marker variations
- Example: `"<!--\\s*(more|excerpt|break)\\s*-->"`

**Set to `false` when:**

- No manual excerpt markers in content
- Only using fallback extraction
- Marker detection not needed

### Choose Your Fallback Strategy

**Use `:paragraph` (default) when:**

- Content has clear paragraph structure
- Want complete thoughts in excerpts
- Most common use case

**Use `:sentence` when:**

- Paragraphs are too long
- Want more control over excerpt length
- Need consistent excerpt sizes

**Use `:word` when:**

- Need precise length control
- Character/word limits required
- Excerpts for cards or previews with strict sizing

**Set to `false` when:**

- All posts have manual markers
- No automatic extraction needed
- Explicit excerpts only

### Choose Your Count

**For `:paragraph` strategy:**

- `count: 1` (default) - Single opening paragraph
- `count: 2` - Opening and second paragraph
- Higher counts rarely needed

**For `:sentence` strategy:**

- `count: 2` (default) - Two sentences
- `count: 1` - Single sentence (very brief)
- `count: 3-4` - Longer excerpts

**For `:word` strategy:**

- `count: 25` (default) - Brief excerpt
- `count: 50-75` - Medium excerpt
- `count: 100+` - Long excerpt

## Common Configuration Patterns

### Marker Only

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  marker: %{
    pattern: "<!--\\s*more\\s*-->",
    remove: true
  },
  fallback: false
```

### Fallback Only

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  marker: false,
  fallback: %{
    strategy: :paragraph,
    count: 1
  }
```

### Custom Marker with Fallback

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  marker: %{
    pattern: "<!--\\s*(more|excerpt)\\s*-->",
    remove: true
  },
  fallback: %{
    strategy: :sentence,
    count: 2
  }
```

### Word-Based Truncation

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  marker: false,
  fallback: %{
    strategy: :word,
    count: 50,
    more: "…"
  }
```

### Keep Marker in Body

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  marker: %{
    pattern: "<!--\\s*more\\s*-->",
    remove: false
  },
  fallback: %{
    strategy: :paragraph,
    count: 1
  }
```

## Markdown Processing

Excerpts are automatically cleaned:

1. **Leading headings removed** - Headings and horizontal rules at start
2. **Footnotes removed** - Both references `[^1]` and definitions
3. **Reference links converted** - `[text][ref]` becomes `[text](url)`
4. **Whitespace normalized** - Multiple spaces/newlines collapsed

## Rendering Excerpts

In your Tableau pages, render excerpts as markdown:

```elixir
defmodule MySite.PostsPage do
  use Tableau.Page,
    layout: MySite.RootLayout,
    permalink: "/posts"

  def template(assigns) do
    posts =
      assigns.site.pages
      |> Enum.filter(& &1[:__tableau_post_extension__])
      |> Enum.sort_by(& &1.date, {:desc, Date})

    temple do
      ul do
        for post <- posts do
          li do
            h3 do
              a href: post.permalink, do: post.title
            end

            if post[:excerpt] do
              div class: "excerpt" do
                Tableau.markdown(post.excerpt)
              end
            end
          end
        end
      end
    end
  end
end
```

## Common Gotchas

1. **Both disabled warning** - Setting both `:marker` and `:fallback` to `false`
   logs a warning and disables the extension.

2. **Pattern is string** - The `:pattern` value is a string that gets compiled
   to a Regex, not a Regex literal.

3. **Marker removal affects body** - When `:remove` is `true`, the post `:body`
   field is updated to remove the marker.

4. **Count defaults vary** - When no marker is present or disabled, the default
   `:count` depends on `:strategy`:
   - `:paragraph` → 1
   - `:sentence` → 2
   - `:word` → 25

5. **Word truncation mid-sentence** - When using `:word` strategy, the `:more`
   string is only appended if truncation happens mid-sentence (no ending
   punctuation).

6. **Paragraph detection** - Paragraphs are split on double newlines (`\n\n+`).
   Single newlines within paragraphs are preserved.

## Resources

- **[Hex Package](https://hex.pm/packages/tableau_excerpt_extension)** - Package
  on Hex.pm
- **[HexDocs](https://hexdocs.pm/tableau_excerpt_extension)** - Complete API
  documentation
- **[GitHub Repository](https://github.com/halostatue/tableau_excerpt_extension)** -
  Source code
- **[Tableau](https://hex.pm/packages/tableau)** - Static site generator
- **[Tableau PostExtension](https://hexdocs.pm/tableau/Tableau.PostExtension.html)** -
  Post processing extension
