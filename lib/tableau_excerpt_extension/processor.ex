defmodule TableauExcerptExtension.Processor do
  @moduledoc """
  Behaviour for format-specific excerpt processing.

  Processors handle format-specific logic for filtering and cleaning excerpts.
  """

  @doc """
  Filters a list of blocks to keep only paragraph-like content.

  Receives blocks split on `\n\n` and returns filtered blocks. Used during fallback
  extraction to identify actual paragraphs.
  """
  @callback filter_paragraphs(blocks :: [String.t()]) :: [String.t()]

  @doc """
  Cleans an excerpt with format-specific processing.

  Receives the raw excerpt and the full body content. Returns the cleaned excerpt or nil
  if the excerpt becomes empty.
  """
  @callback clean(excerpt :: String.t(), body :: String.t()) :: String.t() | nil
end
