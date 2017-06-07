defmodule Retry do
  @moduledoc """

  Provides a convenient interface to retrying behavior. All durations are
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

  If the block raises any of the exceptions specified in `exceptions` a retry will
  be attempted, other exceptions will not be rescued or retried.
  default is `[RuntimeError]`.

  Example

      use Retry
      import Stream

      retry [CustomError], with: exp_backoff |> cap(1_000) |> expiry(1_000) do
      # interact with external service
      end

  """
  defmacro retry(exceptions \\ [RuntimeError], [with: stream_builder], do: block) do
    quote do
      fun = unquote(block_runner(block, exceptions))

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

  Wait for a block of code to be truthy delaying between each attempt
  the duration specified by the next item in the delay stream.

  ## `wait` example

      use Retry
      import Stream

      wait exp_backoff |> expiry(1_000) do
        we_there_yet?
      end

  An optional `then` block can be given as a continuation which will
  evaluate only when the `do` block evaluates to a truthy value.

  ## `wait-then` example

      wait lin_backoff(500, 1) |> take(5) do
        we_there_yet?
      then
        {:ok, "We have arrived!"}
      end

  It's also possible to specify an `else` block which evaluates
  when the `do` block remains falsy after timeout.

  ### `wait-then-else` example

      wait lin_backoff(500, 1) |> take(5) do
        we_there_yet?
      then
        {:ok, "We have arrived!"}
      else
        {:error, "We're still on our way :("}
      end

  """
  defmacro wait(stream_builder, clauses) do
    build_wait(stream_builder, clauses)
  end

  defp build_wait(stream_builder, do: {:__block__, _, [do_clause, {:then, _, nil}, then_clause]}, else: else_clause) do
    build_wait(stream_builder, do: do_clause, then: then_clause, else: else_clause)
  end

  defp build_wait(stream_builder, do: {:__block__, _, [do_clause, {:then, _, nil}, then_clause]}) do
    build_wait(stream_builder, do: do_clause, then: then_clause, else: nil)
  end

  defp build_wait(stream_builder, do: do_clause) do
    build_wait(stream_builder, do: do_clause, then: nil, else: nil)
  end

  defp build_wait(stream_builder, do: do_clause, then: then_clause, else: else_clause) do
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
        x when x in [false, nil] ->
          case unquote(else_clause) do
            nil -> x
            e -> e
          end
        x ->
          case unquote(then_clause) do
            nil -> x
            t -> t
          end
      end
    end
  end

  defp build_wait(_stream_builder, _clauses) do
    raise(ArgumentError, "invalid syntax, only \"wait\", \"then\" and \"else\" are permitted")
  end

  defp block_runner(block, exceptions) do
    quote do
      fn ->
        try do
          case unquote(block) do
            {:error, _} = result -> {:cont, result}
            :error = result      -> {:cont, result}
            result               -> {:halt, result}
          end
        rescue
          e in unquote(exceptions) -> {:cont, {:exception, e}}
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
