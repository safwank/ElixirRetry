defmodule Retry do
  @moduledoc """

  Provides a convenient interface to retrying behavior. All durations a
  specified in milliseconds.

  Examples

      use Retry
      import Stream

      retry with: exp_backoff |> randomize |> cap(1_000) |> expiry(10_000) do
      # interact with external service
      end

      retry with: lin_backoff(10, @fibonacci) |> cap(1_000) |> take(10) do
      # interact with external service
      end

      retry with: cycle([500]) |> take(10) do
      # interact with external service
      end

  The first retry will exponentially increase the delay, fudging each delay up
  to 10%, until the delay reaches 1 second and then give up after 10 seconds.

  The second retry will linearly increase the retry from 10ms following a
  Fibonacci pattern giving up after 10 attempts.

  The third example shows how we can produce a delay stream using standard
  `Stream` functionality. Any stream of integers may be used as the value of
  `with:`.

  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      import Retry
      import Retry.DelayStreams
    end
  end

  @doc """

  Retry a block of code delaying between each attempt the duration specified by
  the next item in the `with` delay stream.

  Example

      use Retry
      import Stream

      retry with: exp_backoff |> cap(1_000) |> expiry(1_000) do
      # interact with external service
      end

      retry with: linear_backoff(@fibonacci) |> cap(1_000) |> take(10) do
      # interact with external service
      end

      retry with: cycle([500]) |> take(10) do
      # interact with external service
      end

  """
  defmacro retry([with: stream_builder], do: block) do
    quote do
      fun = unquote(block_runner(block))

      unquote(delays_from(stream_builder))
      |> Enum.reduce_while(nil, fn(delay, _last_result) ->
        :timer.sleep(delay)
        fun.()
      end)
      |> case do
        {:exception, e} -> raise e
        result          -> result
      end
    end
  end

  @doc """

  Retry a block of code a maximum number of times with a fixed delay between
  attempts.

  Example

      retry 5 in 500 do
      # interact with external service
      end

  Runs the block up to 5 times with a half second sleep between each
  attempt. Execution is deemed a failure if the block returns `{:error, _}` or
  raises a runtime error.

  """
  defmacro retry({:in, _, [retries, sleep]}, do: block) do
    quote do
      import Stream

      retry([with: [unquote(sleep)]
      |> cycle
      |> take(unquote(retries))], do: unquote(block))
    end
  end

  @doc """

  Retry a block of code until `halt` is emitted delaying between each attempt
  the duration specified by the next item in the `with` delay stream.

  The return value for `block` is expected to be `{:cont, result}`, return
  `{:halt, result}` to end the retry early.

  Example

      retry_while with: lin_backoff(500, 1) |> take(5) do
        call_service
        |> case do
          result = %{"errors" => true} -> {:cont, result}
          result -> {:halt, result}
        end
      end

  """
  defmacro retry_while([with: stream_builder], do: block) do
    quote do
      unquote(delays_from(stream_builder))
      |> Enum.reduce_while(nil, fn(delay, _last_result) ->
        :timer.sleep(delay)
        unquote(block)
      end)
    end
  end

  @doc """

  Retry a block of code with a exponential backoff delay between attempts.

  Example

      backoff 1000, delay_cap: 100 do
      # interact with external service
      end

  Runs the block repeated until it succeeds or 1 second elapses with an
  exponentially increasing delay between attempts. Execution is deemed a failure
  if the block returns `{:error, _}` or raises a runtime error.

  The `delay_cap` is optional. If specified it will be the max duration of any
  delay. In the example this is saying never delay more than 100ms between
  attempts. Omitting `delay_cap` is the same as setting it to `:infinity`.

  """
  defmacro backoff(time_budget, do: block) do
    quote do
      import Stream

      retry(
        [with: exp_backoff
               |> randomize
               |> expiry(unquote(time_budget))],
        do: unquote(block)
      )
    end
  end
  defmacro backoff(time_budget, delay_cap: delay_cap, do: block) do
    quote do
      import Stream

      retry(
        [with: exp_backoff
               |> randomize
               |> cap(unquote(delay_cap))
               |> expiry(unquote(time_budget))],
        do: unquote(block)
      )
    end
  end

  @doc """

  Wait for a block of code to be truthy delaying between each attempt
  the duration specified by the next item in the `with` delay stream.

  Example

      use Retry
      import Stream

      wait with: exp_backoff |> expiry(1_000) do
        we_there_yet?
      end

  """
  defmacro wait([with: stream_builder], do: block) do
    quote do
      result =
        unquote(delays_from(stream_builder))
        |> Enum.reduce_while(nil, fn(delay, _last_result) ->
          :timer.sleep(delay)

          case unquote(block) do
            false = result  -> {:cont, result}
            nil = result    -> {:cont, result}
            result          -> {:halt, result}
          end
        end)
    end
  end

  # Retry.do_waits(true, [do: {:__block__, [line: 151], [{:ok, "Everything's so awesome!"}, {:then, [line: 154], nil}, {:ok, "More awesome"}]}])
  defmacro wait(stream_builder, do: {:__block__, _, [do_clause, {:then, _, nil}, then_clause]}) do
    quote do
      unquote(delays_from(stream_builder))
      |> Enum.reduce_while(nil, fn(delay, _last_result) ->
        :timer.sleep(delay)

        case unquote(do_clause) do
          false = result  -> {:cont, result}
          nil = result    -> {:cont, result}
          result          -> {:halt, result}
        end
      end)
      |> case do
        x when x in [false, nil] -> x
        _ -> unquote(then_clause)
      end
    end
  end

  # def then({:error, _} = result, do: _block), do: result
  # def then(:error, do: _block), do: :error
  # def then(nil, do: _block), do: nil
  # def then(false, do: _block), do: false
  # def then(_result, do: block) do
  #   quote do
  #     unquote(block)
  #   end
  # end

  defp block_runner(block) do
    quote do
      fn ->
        try do
          case unquote(block) do
            {:error, _} = result -> {:cont, result}
            :error = result      -> {:cont, result}
            result               -> {:halt, result}
          end
        rescue
          e in RuntimeError      -> {:cont, {:exception, e}}
        end
      end
    end
  end

  defp delays_from(stream_builder) do
    quote do
      delays = unquote(stream_builder)
      [0] |> Stream.concat(delays)
    end
  end
end
