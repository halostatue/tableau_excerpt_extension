# TableauExcerptExtension Changelog

## 1.1.0 / 2026-02-09

- Added a new excerpt strategy, range markers, configured with the `:range`
  configuration option. This allows for specific sections of code (which need
  not be at the beginning of the content) to be excerpted. The default range
  markers are `<!--excerpt:start-->` and `<!--excerpt:end-->` and all content
  between those markers is extracted. This is higher priority than split
  markers.

- Split marker excerpts now include all content before the marker, including
  headings and horizontal rules. This is a mildly breaking change that can be
  mitigated with the new range marker feature.

- Extracted Markdown processing to a new pluggable format processor system via
  the `TableauExcerptExtension.Processor` behaviour. This is configured with the
  `:processors` configuration option.

- Added guides.

## 1.0.2 / 2025-01-26

- Added [usage rules](./usage-rules.md) for use with [`usage_rules`][urules].

  The usage rules were built with the assistance of [Kiro][kiro].

## 1.0.1 / 2025-12-26

- Updated the version requirements and fixed a problem where a regular
  expression isn't supported by older versions of Elixir and Erlang/OTP.

## 1.0.0 / 2025-12-25

- Initial release.

[kiro]: https://kiro.dev
[urules]: https://github.com/ash-project/usage_rules
