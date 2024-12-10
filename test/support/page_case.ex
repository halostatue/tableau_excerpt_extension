defmodule TableauExcerptExtension.PageCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  using do
    quote do
      import TableauExcerptExtension.PageCase
    end
  end

  def page_with_permalink?(page, permalink) do
    is_struct(page, Tableau.Page) and page.permalink == permalink
  end

  def process_page(page_body, opts \\ []) do
    page = build_page(page_body, Keyword.take(opts, [:permalink, :frontmatter]))

    config = build_config(Keyword.drop(opts, [:permalink, :frontmatter, :parse]))

    token = %{
      posts: [page],
      extensions: %{excerpt: %{config: config}}
    }

    result = TableauExcerptExtension.pre_build(token)

    if Keyword.get(opts, :parse, true) do
      assert {:ok, %{posts: [%{excerpt: excerpt}]}} = result
      excerpt
    else
      result
    end
  end

  def build_config(opts \\ []) do
    config_map = Map.merge(%{enabled: true}, Map.new(opts))

    case TableauExcerptExtension.config(config_map) do
      {:ok, config} -> config
      {:error, reason} -> raise "Failed to build config: #{reason}"
    end
  end

  defp build_page(body, opts) do
    page = %{
      body: body,
      permalink: Keyword.get(opts, :permalink, "/test")
    }

    case Keyword.fetch(opts, :frontmatter) do
      {:ok, frontmatter} when is_map(frontmatter) ->
        Map.merge(page, frontmatter)

      {:ok, frontmatter} ->
        Map.put(page, :frontmatter, frontmatter)

      :error ->
        page
    end
  end
end
