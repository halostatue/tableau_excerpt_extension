defmodule TableauExcerptExtension do
  @moduledoc """
  Tableau extension to extracts excerpts from posts.

  ## Extraction Rules

  1. If the post frontmatter already has an `:excerpt` field, it is preserved unchanged;
  2. If the content contains the excerpt marker (default `<!--more-->`), extract
     everything before it;
  3. Otherwise, use the configured fallback strategy to extract content.

  The post frontmatter is updated to add an `:excerpt` field and the post body may be
  updated to remove the excerpt marker (depending on configuration).

  ## Configuration

  ```elixir
  config :tableau, TableauExcerptExtension,
    enabled: true,
    marker: %{
      pattern: "<!--\\s*more\\s*-->",
      remove: true
    },
    fallback: %{
      count: 1,
      more: "…",
      strategy: :paragraph
    }
  ```

  ### Configuration Options

  - `:enabled` (default `false`): Enable or disable the extension

  - `:marker`: Excerpt marker configuration. Set to `false` to disable marker matching

    - `:pattern` (default `"<!--\\s*more\\s*-->"`): A string converted into a Regex
      pattern for excerpt marker matching

    - `:remove` (default `true`): Remove the marker from the post body

  - `:fallback`: Excerpt fallback strategy. Set to `false` to disable fallback.

    - `:more` (default `…`): If using `:word` mode and the excerpt is truncated
      mid-sentence, this string will be appended

    - `:count`: The count of paragraphs, sentences or words to extract; the default depends
      on the strategy selected

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

  The definition of `word`, `sentence`, and `paragraph` is based on normal English usage
  and full stop punctuation. The heuristics for sentence detection are simple.

  ## Markdown Processing

  As the content of the excerpt is extracted from markdown content, it should be rendered
  as markdown. Reference links (`[text][ref]`) are converted to inline links
  (`[text](url)`) and footnotes (`[^1]`) are removed.
  """

  use Tableau.Extension, key: :excerpt, priority: 140

  require Logger

  @defaults %{
    enabled: false,
    marker: %{
      pattern: "<!--\\s*more\\s*-->",
      remove: true
    },
    fallback: %{
      count: nil,
      more: "…",
      strategy: :paragraph
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
    case extract_excerpt(post.body, config) do
      nil -> post
      excerpt when is_binary(excerpt) -> Map.put(post, :excerpt, excerpt)
      {excerpt, body} -> Map.merge(post, %{excerpt: excerpt, body: body})
    end
  end

  defp extract_excerpt(body, config) do
    case extract_marker(body, config.marker) do
      {nil, body} -> extract_fallback(body, config.fallback)
      {excerpt, body} -> {excerpt, body}
      nil -> extract_fallback(body, config.fallback)
    end
  end

  defp extract_marker(_body, false), do: nil

  defp extract_marker(body, config) do
    case Regex.split(config.pattern, body, parts: 2) do
      [excerpt, _] ->
        {clean_excerpt(excerpt, body), clean_body(body, config)}

      _ ->
        nil
    end
  end

  defp extract_fallback(_body, false), do: nil

  defp extract_fallback(body, %{strategy: :paragraph, count: count}) do
    body
    |> take_paragraphs(count)
    |> clean_excerpt(body)
  end

  defp extract_fallback(body, %{strategy: :sentence, count: count}) do
    paragraph = take_paragraphs(body, 1)

    ~r/(?<=[.!?‽]\p{Pf}?)\s+(?=[A-Z])/u
    |> Regex.split(paragraph)
    |> Enum.take(count)
    |> Enum.join(" ")
    |> String.trim()
    |> clean_excerpt(body)
  end

  defp extract_fallback(body, %{strategy: :word, count: count, more: more}) do
    paragraph = take_paragraphs(body, 1)
    words = String.split(paragraph, ~r/\s+/)

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

    clean_excerpt(excerpt, body)
  end

  defp clean_excerpt(excerpt, body) do
    cleaned =
      excerpt
      |> strip_leading_headings()
      |> strip_footnotes()
      |> clean_reference_links(body)

    case String.trim(cleaned) do
      "" -> nil
      _ -> cleaned
    end
  end

  defp clean_body(body, %{remove: false}), do: body

  defp clean_body(body, %{pattern: pattern}) do
    String.replace(body, pattern, "", global: false)
  end

  defp strip_leading_headings(content) do
    content
    |> String.split(~r/\n\n+/)
    |> Enum.drop_while(&heading_or_rule?/1)
    |> Enum.join("\n\n")
    |> String.trim()
  end

  defp heading_or_rule?(block) do
    trimmed = String.trim_leading(block)
    Regex.match?(~r/\A(?:\#{1,6}\s|---+\s*$|\*\*\*+\s*$|___+\s*$)/m, trimmed)
  end

  defp paragraph?(block) do
    not heading_or_rule?(block)
  end

  defp strip_footnotes(excerpt) do
    excerpt
    |> String.replace(~r/^\[\^[^\]]+\]:.*(?:\n(?:[ \t]+.*)?)*/m, "")
    |> String.replace(~r/\[\^[^\]]+\]/, "")
    |> String.replace(~r/  +/, " ")
    |> String.replace(~r/\n{3,}/, "\n\n")
    |> String.trim()
  end

  defp clean_reference_links(excerpt, content) do
    refs = parse_reference_definitions(content)

    Regex.replace(~r/\[([^\]]+)\]\[([^\]]*)\]/, excerpt, fn _full_match, text, ref ->
      key = String.downcase(if ref == "", do: text, else: ref)

      case Map.get(refs, key) do
        {url, title} -> "[#{text}](#{url} \"#{title}\")"
        url when is_binary(url) -> "[#{text}](#{url})"
        nil -> text
      end
    end)
  end

  defp parse_reference_definitions(content) do
    ~r/^\[([^\]]+)\]:\s*<?([^\s>]+)>?(?:\s+["'(]([^"')]+)["')])?$/m
    |> Regex.scan(content)
    |> Map.new(fn
      [_, ref, url] -> {String.downcase(ref), url}
      [_, ref, url, title] -> {String.downcase(ref), {url, title}}
    end)
  end

  defp resolve_config(config) do
    with {:ok, config} <- resolve_marker_config(config),
         {:ok, config} <- resolve_fallback_config(config) do
      finalize_config(config)
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

  defp finalize_config(%{marker: false, fallback: false} = config) do
    Logger.warning("[TableauExcerptExtension] Disabling because both marker and fallback
      are disabled")
    {:ok, %{config | enabled: false}}
  end

  defp finalize_config(config), do: {:ok, config}

  defp take_paragraphs(text, count) do
    text
    |> String.split(~r/\n\n+/)
    |> Enum.filter(&paragraph?/1)
    |> Enum.take(count)
    |> Enum.join("\n\n")
    |> String.trim()
  end
end
