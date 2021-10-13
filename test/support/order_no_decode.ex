defmodule OrderNoDecoder do
  @moduledoc false

  @enforce_keys [:id]
  defstruct [:id, :max_total, :items]
end

defmodule LineItemNoEncoder do
  @moduledoc false

  defstruct [:price]
end
