defmodule TableauExcerptExtension.Processor.Passthrough do
  @moduledoc """
  Passthrough processor for unknown formats.

  Returns content unchanged - no filtering or cleaning applied.
  """

  @behaviour TableauExcerptExtension.Processor

  @impl TableauExcerptExtension.Processor
  def filter_paragraphs(blocks), do: blocks

  @impl TableauExcerptExtension.Processor
  def clean(excerpt, _body), do: excerpt
end
