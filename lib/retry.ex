defmodule Retry do
  @doc false
  defmacro __using__(_opts) do
    quote do
      import Retry

      defmacro retry(retries, do: block) do
        quote do
          run = fn(attempt, self) ->
            if attempt <= unquote(retries) do
              IO.puts "attempt #{attempt}"

              case unquote(block) do
                {:error, _} -> self.(attempt + 1, self)
              end
            end
          end

          run.(1, run)
        end
      end
    end
  end
end