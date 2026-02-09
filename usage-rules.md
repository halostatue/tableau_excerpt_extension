# TableauExcerptExtension Usage Rules

TableauExcerptExtension is a Tableau extension that extracts excerpts from posts
for use in index pages and feeds.

## Core Principle

If a post already has an `excerpt` field, it is unmodified. Otherwise, the
extension extracts an excerpt using one of three methods (in order of
precedence):

1. **Range markers** - Content between `<!--excerpt:start-->` and `<!--excerpt:end-->`
2. **Split marker** - Content before `<!--more-->`
3. **Structural extraction** - First paragraph(s), sentence(s), or word(s) based on text structure

## Configuration

```elixir
# config/config.exs
config :tableau, TableauExcerptExtension,
  enabled: true,
  range: %{
    start: "<!--\\s*excerpt:start\\s*-->",
    end: "<!--\\s*excerpt:end\\s*-->",
    remove: false
  },
  marker: %{
    pattern: "<!--\\s*more\\s*-->",
    remove: true
  },
  fallback: %{
    strategy: :paragraph,
    count: 1,
    more: "…"
  },
  processors: [
    md: TableauExcerptExtension.Processor.Markdown
  ]
```

### Required Configuration

- `:enabled` (default `false`) - Enable/disable the extension

### Optional Configuration

- `:range` - Range marker configuration (set to `false` to disable)
  - `:start` (default `"<!--\\s*excerpt:start\\s*-->"`) - Start marker pattern
  - `:end` (default `"<!--\\s*excerpt:end\\s*-->"`) - End marker pattern
  - `:remove` (default `false`) - Remove markers from post body

- `:marker` - Split marker configuration (set to `false` to disable)
  - `:pattern` (default `"<!--\\s*more\\s*-->"`) - Regex pattern string
  - `:remove` (default `true`) - Remove marker from post body

- `:fallback` - Structural extraction strategy (set to `false` to disable)
  - `:strategy` (default `:paragraph`) - `:paragraph`, `:sentence`, or `:word`
  - `:count` - Number of units to extract (defaults vary by strategy)
  - `:more` (default `"…"`) - Suffix for truncated word excerpts

- `:processors` - Format-specific processors (keyword list or map)
  - Default: `[md: TableauExcerptExtension.Processor.Markdown]`
  - Processors handle paragraph filtering and content cleaning
  - Unknown formats use `TableauExcerptExtension.Processor.Passthrough`

## Decision Guide: When to Use What

### Choose Your Extraction Method

**Use range markers when:**

- Need precise control over excerpt content
- Excerpt should come from middle of post
- Want different content than opening paragraphs
- Example: Pull a key quote or summary section

**Use split marker when:**

- Natural break point in content
- Excerpt is always the opening section
- Compatible with other static site generators
- Most common manual approach

**Use structural extraction when:**

- Consistent automatic excerpts needed
- No manual marker management
- Opening content works as excerpt
- Fallback for posts without markers

### Choose Your Range Marker Pattern

**Use default `<!--excerpt:start-->` / `<!--excerpt:end-->` when:**

- Standard HTML comment markers are sufficient
- Clear, explicit marker names
- No conflicts with existing content

**Use custom patterns when:**

- Different marker convention in existing content
- Need shorter or different marker names
- Example: `<!--begin-->` / `<!--end-->`

**Set to `false` when:**

- Not using range markers
- Only using split marker or structural extraction

### Choose Your Split Marker Pattern

**Use default `"<!--\\s*more\\s*-->"` when:**

- Standard HTML comment marker is sufficient
- Compatibility with other static site generators
- Simple, recognizable marker

**Use custom pattern when:**

- Different marker convention in existing content
- Need multiple marker variations
- Example: `"<!--\\s*(more|excerpt|break)\\s*-->"`

**Set to `false` when:**

- No manual split markers in content
- Only using range markers or structural extraction
- Split marker detection not needed

### Choose Your Structural Extraction Strategy

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

- All posts have manual markers (range or split)
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

### Range Markers Only

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  range: %{
    start: "<!--\\s*excerpt:start\\s*-->",
    end: "<!--\\s*excerpt:end\\s*-->",
    remove: false
  },
  marker: false,
  fallback: false
```

### Split Marker Only

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  range: false,
  marker: %{
    pattern: "<!--\\s*more\\s*-->",
    remove: true
  },
  fallback: false
```

### Structural Extraction Only

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  range: false,
  marker: false,
  fallback: %{
    strategy: :paragraph,
    count: 1
  }
```

### Custom Split Marker with Structural Extraction

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

### Word-Based Structural Extraction

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true,
  range: false,
  marker: false,
  fallback: %{
    strategy: :word,
    count: 50,
    more: "…"
  }
```

### Keep Split Marker in Body

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

## Format Processing

Excerpts are processed by format-specific processors. For Markdown (`.md` files):

1. **Structural extraction filtering** - Headings and horizontal rules excluded from paragraph detection
2. **Footnotes removed** - Both references `[^1]` and definitions `[^1]: text`
3. **Reference links converted** - `[text][ref]` becomes `[text](url)`

Unknown formats use the Passthrough processor (no filtering or cleaning).

## Rendering Excerpts

Excerpts are stored in the same format as the source and must be rendered with
the appropriate converter (e.g., `Tableau.markdown/1` for Markdown excerpts).

See the [Basic Usage guide](guides/basic-usage.md) for rendering examples and
the [Deduplicating Rendered Elements guide](guides/deduplicating-rendered-elements.md)
for handling duplicate scripts/styles when rendering multiple excerpts.

## Common Gotchas

1. **All extraction methods disabled** - Setting `:range`, `:marker`, and
   `:fallback` all to `false` logs a warning and disables the extension.

2. **Pattern is string** - The `:pattern` and `:start`/`:end` values are strings
   that get compiled to Regex, not Regex literals.

3. **Marker removal affects body** - When `:remove` is `true`, the post `:body`
   field is updated to remove the marker(s).

4. **Range marker removal default** - Range markers default to `:remove` being
   `false` (kept in body), while split marker defaults to `true` (removed).

5. **Count defaults vary** - When using structural extraction, the default
   `:count` depends on `:strategy`:
   - `:paragraph` → 1
   - `:sentence` → 2
   - `:word` → 25

6. **Word truncation mid-sentence** - When using `:word` strategy, the `:more`
   string is only appended if truncation happens mid-sentence (no ending
   punctuation).

7. **Paragraph detection** - Paragraphs are split on double newlines (`\n\n+`).
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
