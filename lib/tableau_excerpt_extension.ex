defmodule TableauExcerptExtension do
  @moduledoc """
  Tableau extension to extract excerpts from posts.

  ## Extraction Rules

  1. If the post frontmatter already has an `:excerpt` field, it is preserved unchanged;
  2. If the content contains range markers (default `<!--excerpt:start-->` and
     `<!--excerpt:end-->`), extract the content between them;
  3. If the content contains the split marker (default `<!--more-->`), extract
     everything before it;
  4. Otherwise, use structural extraction to extract content based on text structure.

  The post frontmatter is updated to add an `:excerpt` field and the post body may be
  updated to remove the split marker (depending on configuration). Range markers are not
  removed from the body.

  ## Configuration

  ```elixir
  config :tableau, TableauExcerptExtension,
    enabled: true,
    range: %{
      start: "<!--\\s*excerpt:start\\s*-->",
      end: "<!--\\s*excerpt:end\\s*-->"
    },
    marker: %{
      pattern: "<!--\\s*more\\s*-->",
      remove: true
    },
    fallback: %{
      count: 1,
      more: "…",
      strategy: :paragraph
    },
    processors: [
      md: TableauExcerptExtension.Processor.Markdown
    ]
  ```

  ### Configuration Options

  - `:enabled` (default `false`): Enable or disable the extension

  - `:range`: Range marker configuration. Set to `false` to disable range extraction

    - `:start` (default `"<!--\\s*excerpt:start\\s*-->"`): Pattern for the start marker
    - `:end` (default `"<!--\\s*excerpt:end\\s*-->"`): Pattern for the end marker
    - `:remove` (default `false`): Remove the markers from the post body (content between
      markers is preserved)

  - `:marker`: Split marker configuration. Set to `false` to disable marker matching

    - `:pattern` (default `"<!--\\s*more\\s*-->"`): A string converted into a Regex
      pattern for split marker matching

    - `:remove` (default `true`): Remove the marker from the post body

  - `:fallback`: Structural extraction strategy when no markers are found. Set to `false`
    to disable.

    - `:more` (default `…`): If using `:word` mode and the excerpt is truncated
      mid-sentence, this string will be appended

    - `:count`: The count of paragraphs, sentences or words to extract; the default
      depends on the strategy selected

      | strategy  | default |
      | --------- | ------- |
      | paragraph | 1       |
      | sentence  | 2       |
      | word      | 25      |

    - `:strategy` (default: `:paragraph`): The extraction strategy to use

      - `:paragraph`: Extract _count_ complete paragraphs
      - `:sentence`: Extract _count_ sentences, stopping at the first paragraph boundary
      - `:word`: Extract _count_ words, stopping at the first paragraph boundary and
        appending the `more` string if mid-sentence

  - `:processors`: Map of file extensions (atoms) to processor modules. Processors handle
    format-specific filtering and cleaning. The default is
    `%{md: TableauExcerptExtension.Processor.Markdown}`; content without an explicit
    processor will be passed to the Passthrough processor.

  ## Format Processing

  Excerpts are processed by format-specific processors based on the post's file extension.
  Processors implement the `TableauExcerptExtension.Processor` behaviour with two
  callbacks:

  - `filter_paragraphs/1`: Filters paragraph-like blocks (e.g., remove headings/rules).
    This is only called when using the `fallback` structural extraction.
  - `clean/2`: Cleans format-specific syntax from excerpts (e.g., footnotes, reference
    links). This is called for all extracted excerpts (excerpts already present in
    post frontmatter are ignored).

  ### Built-in Processors

  - `TableauExcerptExtension.Processor.Markdown`: Filters headings/rules, cleans footnotes
    and reference links
  - `TableauExcerptExtension.Processor.Passthrough`: Passthrough processor for unknown
    formats

  ### Custom Processors

  To support additional formats, implement the `TableauExcerptExtension.Processor`
  behaviour and add to the `:processors` config:

  ```elixir
  config :tableau, TableauExcerptExtension,
    processors: %{
      md: TableauExcerptExtension.Processor.Markdown,
      djot: MySite.DjotProcessor
    }
  ```
  """

  use Tableau.Extension, key: :excerpt, priority: 140

  alias TableauExcerptExtension.Processor.Markdown
  alias TableauExcerptExtension.Processor.Passthrough

  require Logger

  @defaults %{
    enabled: false,
    marker: %{pattern: "<!--\\s*more\\s*-->", remove: true},
    range: %{
      start: "<!--\\s*excerpt:start\\s*-->",
      end: "<!--\\s*excerpt:end\\s*-->",
      remove: false
    },
    fallback: %{count: nil, more: "…", strategy: :paragraph},
    processors: %{
      md: Markdown
    }
  }

  @impl Tableau.Extension
  def config(config) when is_list(config), do: config(Map.new(config))

  def config(config) do
    @defaults
    |> Map.merge(config, fn
      _, v1, v2 when is_list(v2) -> Map.merge(v1, Map.new(v2))
      _, v1, v2 when is_map(v2) -> Map.merge(v1, v2)
      _, _, v -> v
    end)
    |> resolve_config()
  end

  @impl Tableau.Extension
  def pre_build(token) do
    {:ok, Map.put(token, :posts, Enum.map(token.posts, &put_new_excerpt(&1, token.extensions.excerpt.config)))}
  end

  defp put_new_excerpt(%{excerpt: _} = post, _config), do: post

  defp put_new_excerpt(post, config) do
    processor = get_processor(post.file, config.processors)

    case extract_excerpt(post.body, config, processor) do
      nil -> post
      excerpt when is_binary(excerpt) -> Map.put(post, :excerpt, excerpt)
      {excerpt, body} -> Map.merge(post, %{excerpt: excerpt, body: body})
    end
  end

  defp get_processor(filename, processors) do
    "." <> ext = Path.extname(filename)
    # credo:disable-for-next-line
    ext_atom = String.to_atom(ext)

    Map.get(processors, ext_atom, Passthrough)
  end

  defp extract_excerpt(body, config, processor) do
    case extract_range(body, config.range, processor) do
      {excerpt, body} ->
        {excerpt, body}

      nil ->
        case extract_marker(body, config.marker, processor) do
          {nil, body} -> extract_fallback(body, config.fallback, processor)
          {excerpt, body} -> {excerpt, body}
          nil -> extract_fallback(body, config.fallback, processor)
        end
    end
  end

  defp extract_range(_body, false, _processor), do: nil

  defp extract_range(body, config, processor) do
    pattern = Regex.compile!("#{config.start}(.*?)#{config.end}", "s")

    case Regex.run(pattern, body) do
      [_full, excerpt] ->
        cleaned_body =
          if config.remove do
            body
            |> String.replace(config.start_pattern, "", global: false)
            |> String.replace(config.end_pattern, "", global: false)
          else
            body
          end

        {processor.clean(excerpt, cleaned_body), cleaned_body}

      nil ->
        nil
    end
  end

  defp extract_marker(_body, false, _processor), do: nil

  defp extract_marker(body, config, processor) do
    case Regex.split(config.pattern, body, parts: 2) do
      [excerpt, _] ->
        {processor.clean(excerpt, body), clean_body(body, config)}

      _ ->
        nil
    end
  end

  defp extract_fallback(_body, false, _processor), do: nil

  defp extract_fallback(body, %{strategy: :paragraph, count: count}, processor) do
    body
    |> take_paragraphs(count, processor)
    |> clean_excerpt(body, processor)
  end

  defp extract_fallback(body, %{strategy: :sentence, count: count}, processor) do
    paragraph = take_paragraphs(body, 1, processor)

    sentences =
      paragraph
      |> String.split(~r/([.!?‽]["']?)\s+/, include_captures: true, trim: true)
      |> Enum.chunk_every(2)
      |> Enum.map(fn
        [sentence, punct] -> sentence <> punct
        [sentence] -> sentence
      end)
      |> Enum.take(count)
      |> Enum.join(" ")
      |> String.trim()

    clean_excerpt(sentences, body, processor)
  end

  defp extract_fallback(body, %{strategy: :word, count: count, more: more}, processor) do
    paragraph = take_paragraphs(body, 1, processor)

    words =
      paragraph
      |> String.trim()
      |> String.split(~r/\s+/)

    excerpt =
      if length(words) <= count do
        paragraph
      else
        truncated =
          words
          |> Enum.take(count)
          |> Enum.join(" ")

        if Regex.match?(~r/[.!?‽]\p{Pf}?$/u, truncated) do
          truncated
        else
          truncated <> more
        end
      end

    clean_excerpt(excerpt, body, processor)
  end

  defp take_paragraphs(body, count, processor) do
    body
    |> String.trim()
    |> String.split(~r/\n\n+/)
    |> processor.filter_paragraphs()
    |> Enum.take(count)
    |> Enum.join("\n\n")
  end

  defp clean_excerpt(excerpt, body, processor) do
    processor.clean(excerpt, body)
  end

  defp clean_body(body, %{remove: false}), do: body

  defp clean_body(body, %{pattern: pattern}) do
    String.replace(body, pattern, "", global: false)
  end

  defp resolve_config(config) do
    with {:ok, config} <- resolve_range_config(config),
         {:ok, config} <- resolve_marker_config(config),
         {:ok, config} <- resolve_fallback_config(config) do
      finalize_config(config)
    end
  end

  defp resolve_range_config(%{range: false} = config), do: {:ok, config}

  defp resolve_range_config(%{range: %{start: start_pattern, end: end_pattern}} = config) do
    with {:ok, start_regex} <- Regex.compile(start_pattern),
         {:ok, end_regex} <- Regex.compile(end_pattern) do
      config =
        config
        |> put_in([:range, :start_pattern], start_regex)
        |> put_in([:range, :end_pattern], end_regex)

      {:ok, config}
    else
      {:error, _} ->
        {:error, "range.start and range.end must be valid regular expressions"}
    end
  end

  defp resolve_marker_config(%{marker: false} = config), do: {:ok, config}

  defp resolve_marker_config(%{marker: %{pattern: pattern}} = config) do
    case Regex.compile(pattern) do
      {:ok, regex} -> {:ok, put_in(config, [:marker, :pattern], regex)}
      {:error, _} -> {:error, "marker.pattern must be a valid regular expression, got: #{inspect(pattern)}"}
    end
  end

  @fallback_strategy_count %{paragraph: 1, sentence: 2, word: 25}

  defp resolve_fallback_config(%{fallback: false} = config), do: {:ok, config}

  defp resolve_fallback_config(%{fallback: fallback} = config) do
    case fallback do
      %{strategy: bad_strategy} when bad_strategy not in [:paragraph, :sentence, :word] ->
        {:error, "fallback.strategy must be one of :paragraph, :sentence, or :word, got: #{inspect(bad_strategy)}"}

      %{count: nil} ->
        {:ok, put_in(config, [:fallback, :count], Map.fetch!(@fallback_strategy_count, fallback.strategy))}

      %{count: count} when not is_integer(count) or count < 1 ->
        {:error, "fallback.count must be a positive integer, got: #{inspect(count)}"}

      _ ->
        {:ok, config}
    end
  end

  defp finalize_config(%{marker: false, fallback: false, range: false} = config) do
    Logger.warning("[TableauExcerptExtension] Disabled because no extraction method is enabled")
    {:ok, %{config | enabled: false}}
  end

  defp finalize_config(config), do: {:ok, config}
end
