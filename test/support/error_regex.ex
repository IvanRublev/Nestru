defmodule ErrorRegex do
  @moduledoc false

  def regex_substring(string) do
    Regex.compile!(Regex.escape(string))
  end
end
