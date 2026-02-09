defmodule TableauExcerptExtension.Processor.Markdown do
  @moduledoc """
  Markdown-specific excerpt processor.

  Filters out headings and horizontal rules, and cleans up markdown-specific
  syntax like footnotes and reference links.
  """

  @behaviour TableauExcerptExtension.Processor

  @impl TableauExcerptExtension.Processor
  def filter_paragraphs(blocks) do
    Enum.reject(blocks, &heading_or_rule?/1)
  end

  @impl TableauExcerptExtension.Processor
  def clean(excerpt, body) do
    cleaned =
      excerpt
      |> strip_footnotes()
      |> clean_reference_links(body)

    case String.trim(cleaned) do
      "" -> nil
      _ -> cleaned
    end
  end

  defp heading_or_rule?(block) do
    trimmed = String.trim_leading(block)
    Regex.match?(~r/\A(?:\#{1,6}\s|---+\s*$|\*\*\*+\s*$|___+\s*$)/m, trimmed)
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
end
