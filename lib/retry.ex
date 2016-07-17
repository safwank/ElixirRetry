defmodule Retry do
  @moduledoc """

  Provides a convenient interface to retrying behavior. All durations a
  specified in milliseconds.

  Examples

      use Retry
      import Stream

      retry with: exp_backoff |> randomize |> cap(1000) |> expiry(10000) do
      # interact with external service
      end

      retry with: lin_backoff(10, @fibonacci) |> cap(1000) |> take(10) do
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

      retry with: exp_backoff |> cap(1000) |> expiry(1000) do
      # interact with external service
      end

      retry with: linear_backoff(@fibonacci) |> cap(1000) |> take(10) do
      # interact with external service
      end

      retry with: cycle([500]) |> take(10) do
      # interact with external service
      end

  """
  defmacro retry([with: stream_builder], do: block) do
    quote do
      fun = unquote(block_runner(block))
      retry_delays = unquote(stream_builder)
      delays = [0] |> Stream.concat(retry_delays)

      delays
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

  Retry block of code a maximum number of times with a fixed delay between
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

  Retry block of code with a exponential backoff delay between attempts.

  Example

      backoff 1000, delay_cap: 100 do
      # interact the external service
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
end
