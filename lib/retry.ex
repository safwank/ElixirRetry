defmodule Retry do
  @doc false
  defmacro __using__(_opts) do
    quote do
      import Retry
    end
  end


  @doc """

  Retry block of code a maximum number of times with a fixed delay between
  attempts.

  Example

  ```elixir
  retry 5 in 500 do
    # interact with external service
  end
  ```

  Runs the block up to 5 times with a half second sleep between each
  attempt. Execution is deemed a failure if the block returns `{:error, _}` or
  raises a runtime error.

  """
  defmacro retry({ :in, _, [retries, sleep] }, do: block) do
    quote do
      run = fn(attempt, self) ->
        if attempt <= unquote(retries) do
          try do
            case unquote(block) do
              {:error, _} ->
                :timer.sleep(unquote(sleep))
                self.(attempt + 1, self)
              result -> result
            end
          rescue
            e in RuntimeError ->
              :timer.sleep(unquote(sleep))
            self.(attempt + 1, self)
          end
        else
          unquote(block)
        end
      end

      run.(1, run)
    end
  end

  @doc """

  Retry block of code with a exponential backoff delay between attempts.

  Example

  ```elixir
  backoff 1000 do
    # interact the external service
  end
  ```

  Runs the block repeated until it succeeds or 1 second elapses with an
  exponentially increasing delay between attempts. Execution is deemed a failure
  if the block returns `{:error, _}` or raises a runtime error.

  """
  defmacro backoff(timeout, do: block) do
    quote do
      run = fn(attempt, self) ->
        # http://dthain.blogspot.com.au/2009/02/exponential-backoff-in-distributed.html
        sleep = :erlang.round((1 + :random.uniform) * 10 * :math.pow(2, attempt))

        if sleep <= unquote(timeout) do
          try do
            case unquote(block) do
              {:error, _} ->
                :timer.sleep(sleep)
                self.(attempt + 1, self)
              result -> result
            end
          rescue
            e in RuntimeError ->
              :timer.sleep(sleep)
            self.(attempt + 1, self)
          end
        else
          unquote(block)
        end
      end

      run.(1, run)
    end
  end
end
