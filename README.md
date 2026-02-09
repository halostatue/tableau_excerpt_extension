# TableauExcerptExtension

[![Hex.pm][shield-hex]][hexpm] [![Hex Docs][shield-docs]][docs]
[![Apache 2.0][shield-licence]][licence] ![Coveralls][shield-coveralls]

- code :: <https://github.com/halostatue/tableau_excerpt_extension>
- issues :: <https://github.com/halostatue/tableau_excerpt_extension/issues>

A [Tableau][tableau] extension that automatically extracts excerpts from
[posts][posts].

## Overview

The excerpt extension processes your Tableau posts and extracts excerpts for use
in post index pages. Excerpts are stored in the post frontmatter in the same
format as the source and rendered with the appropriate converter; for Markdown
content, this would be `Tableau.markdown/1`.

Excerpts can be explicitly marked with range markers (`<!--excerpt:start-->` and
`<!--excerpt:end-->`), a split marker (`<!--more-->`), or extracted using
configurable fallback strategies (paragraphs, sentences, or words).

Format-specific processor modules handle paragraph detection for fallback
extraction and cleaning of format-specific syntax (footnotes, reference links,
or other syntax).

See the guides below for detailed usage and the [module documentation][docs] for
configuration options.

## Usage

TableauExcerptExtension mostly works automatically once enabled.

```elixir
config :tableau, TableauExcerptExtension,
  enabled: true
```

See the [Basic Usage Guide](guides/basic-usage.md) for details on rendering
excerpts in your post index pages and the [module documentation][docs] for
configuration options.

## Installation

TableauExcerptExtension can be installed by adding `tableau_excerpt_extension`
to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tableau_excerpt_extension, "~> 1.1"}
  ]
end
```

Documentation is found on [HexDocs][docs].

## Semantic Versioning

TableauExcerptExtension follows [Semantic Versioning 2.0][semver].

[basic]: guides/basic-usage.md
[docs]: https://hexdocs.pm/tableau_excerpt_extension
[hexpm]: https://hex.pm/packages/tableau_excerpt_extension
[licence]: https://github.com/halostatue/tableau_excerpt_extension/blob/main/LICENCE.md
[posts]: https://hexdocs.pm/tableau/Tableau.PostExtension.html
[script]: guides/deduplicating-rendered-elements.md
[semver]: https://semver.org/
[shield-coveralls]: https://img.shields.io/coverallsCoverage/github/halostatue/tableau_excerpt_extension?style=for-the-badge
[shield-docs]: https://img.shields.io/badge/hex-docs-lightgreen.svg?style=for-the-badge "Hex Docs"
[shield-hex]: https://img.shields.io/hexpm/v/tableau_excerpt_extension?style=for-the-badge "Hex Version"
[shield-licence]: https://img.shields.io/hexpm/l/tableau_excerpt_extension?style=for-the-badge&label=licence "Apache 2.0"
[tableau]: https://hex.pm/packages/tableau
