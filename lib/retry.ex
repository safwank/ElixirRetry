defmodule Retry do
  @doc false
  defmacro __using__(_opts) do
    quote do
      import Retry

      def retry(function) do
        quote do: unquote(function)
      end
    end
  end
end