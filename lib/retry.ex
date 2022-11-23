defmodule Retry do
  @moduledoc """

  Provides a convenient interface to retrying behavior. All durations are
  specified in milliseconds.

  Examples

      use Retry
      import Stream

      retry with: exponential_backoff |> randomize |> cap(1_000) |> expiry(10_000) do
      # interact with external service
      end

      retry with: linear_backoff(10, 2) |> cap(1_000) |> take(10) do
      # interact with external service
      end

      retry with: cycle([500]) |> take(10) do
      # interact with external service
      end

  The first retry will exponentially increase the delay, fudging each delay up
  to 10%, until the delay reaches 1 second and then give up after 10 seconds.

  The second retry will linearly increase the retry by a factor of 2 from 10ms giving up after 10 attempts.

  The third example shows how we can produce a delay stream using standard
  `Stream` functionality. Any stream of integers may be used as the value of
  `with:`.

  """

  @default_retry_options [atoms: [:error], rescue_only: [RuntimeError]]
  @required_retry_options [:with]
  @allowed_retry_options @required_retry_options ++ Keyword.keys(@default_retry_options)

  @default_retry_else_clause (quote do error -> raise error end)
  @default_retry_after_clause (quote do result -> result end)
  @default_retry_clauses [after: @default_retry_after_clause, else: @default_retry_else_clause]
  @required_retry_clauses [:do]
  @allowed_retry_clauses @required_retry_clauses ++ Keyword.keys(@default_retry_clauses)

  @retry_usage """
  Invalid Syntax. Usage:

  retry with: ... do
    ...
  end
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

  If the block returns any of the atoms specified in `atoms`, a retry will be attempted.
  Other atoms or atom-result tuples will not be retried. If `atoms` is not specified,
  it defaults to `[:error]`.

  Similary, if the block raises any of the exceptions specified in `rescue_only`, a retry
  will be attempted. Other exceptions will not be retried. If `rescue_only` is
  not specified, it defaults to `[RuntimeError]`.

  The `after` block evaluates only when the `do` block returns a valid value before timeout.

  On the other hand, the `else` block evaluates only when the `do` block remains erroneous after timeout.

  Example

      use Retry

      retry with: exponential_backoff() |> cap(1_000) |> expiry(1_000), rescue_only: [CustomError] do
        # interact with external service
      after
        result -> result
      else
        error -> error
      end

  """
  defmacro retry(opts, clauses) when is_list(opts) and is_list(clauses) do
    opts = parse_opts(opts)
    [do_clause, after_clause, else_clause] = parse_clauses(clauses)
    stream_builder = Keyword.fetch!(opts, :with)
    atoms = Keyword.fetch!(opts, :atoms)

    quote generated: true do
      fun = unquote(block_runner(do_clause, opts))

      unquote(delays_from(stream_builder))
      |> Enum.reduce_while(nil, fn delay, _last_result ->
        :timer.sleep(delay)
        fun.()
      end)
      |> case do
        {:exception, e} ->
          case e do
            unquote(else_clause)
          end

        e = {atom, _} when atom in unquote(atoms) ->
          case e do
            unquote(else_clause)
          end

        e when is_atom(e) and e in unquote(atoms) ->
          case e do
            unquote(else_clause)
          end

        result ->
          case result do
            unquote(after_clause)
          end
      end
    end
  end

  defmacro retry(_, _) do
    raise(ArgumentError, @retry_usage)
  end

  @doc """

  Retry a block of code until `halt` is emitted delaying between each attempt
  the duration specified by the next item in the `with` delay stream.

  The return value for `block` is expected to be `{:cont, result}`, return
  `{:halt, result}` to end the retry early.

  An accumulator can also be specified which might be handy if subsequent
  retries are dependent on the previous ones.

  The initial value of the accumulator is given as a keyword argument `acc:`.
  When the `:acc` key is given, its value is used as the initial accumulator
  and the `do` block must be changed to use `->` clauses, where the left side
  of `->` receives the accumulated value of the previous iteration and
  the expression on the right side must return the `:cont`/`:halt` tuple
  with new accumulator value as the second element.

  Once `:halt` is returned from the block, or there are no more elements,
  the accumulated value is returned.

  Example

      retry_while with: linear_backoff(500, 1) |> take(5) do
        call_service
        |> case do
          result = %{"errors" => true} -> {:cont, result}
          result -> {:halt, result}
        end
      end

  Example with `acc:`

      retry_while acc: 0, with: linear_backoff(500, 1) |> take(5) do
        acc ->
          call_service
          |> case do
            %{"errors" => true} -> {:cont, acc + 1}
            result -> {:halt, result}
          end
      end
  """
  defmacro retry_while([with: stream_builder], do: block) do
    quote generated: true do
      unquote(delays_from(stream_builder))
      |> Enum.reduce_while(nil, fn delay, _last_result ->
        :timer.sleep(delay)
        unquote(block)
      end)
    end
  end

  defmacro retry_while(args = [with: _stream_builder, acc: _acc_initial], do: block),
    do: do_retry_value(Enum.reverse(args), do: block)

  defmacro retry_while(args = [acc: _acc_initial, with: _stream_builder], do: block),
    do: do_retry_value(args, do: block)

  defp do_retry_value([acc: acc_initial, with: stream_builder], do: block) do
    quote generated: true do
      unquote(delays_from(stream_builder))
      |> Enum.reduce_while(unquote(acc_initial), fn delay, acc ->
        :timer.sleep(delay)

        case acc do
          unquote(block)
        end
      end)
    end
  end

  @doc """

  Wait for a block of code to be truthy delaying between each attempt
  the duration specified by the next item in the delay stream.

  The `after` block evaluates only when the `do` block returns a truthy value.

  On the other hand, the `else` block evaluates only when the `do` block remains falsy after timeout.

  Example

      wait linear_backoff(500, 1) |> take(5) do
        we_there_yet?
      after
        _ ->
          {:ok, "We have arrived!"}
      else
        _ ->
          {:error, "We're still on our way :("}
      end

  """
  defmacro wait(stream_builder, do: do_clause, after: after_clause, else: else_clause) do
    quote generated: true do
      unquote(delays_from(stream_builder))
      |> Enum.reduce_while(nil, fn delay, _last_result ->
        :timer.sleep(delay)

        case unquote(do_clause) do
          result when result in [false, nil] -> {:cont, result}
          result -> {:halt, result}
        end
      end)
      |> case do
        x when x in [false, nil] ->
          case x do
            unquote(else_clause)
          end

        x ->
          case x do
            unquote(after_clause)
          end
      end
    end
  end

  defmacro wait(_stream_builder, _clauses) do
    raise(ArgumentError, ~s(invalid syntax, only "wait", "after" and "else" are permitted))
  end

  defp block_runner(block, opts) do
    atoms = Keyword.get(opts, :atoms)
    exceptions = Keyword.get(opts, :rescue_only)

    quote generated: true do
      fn ->
        try do
          case unquote(block) do
            {atom, _} = result ->
              if atom in unquote(atoms) do
                {:cont, result}
              else
                {:halt, result}
              end

            result ->
              if is_atom(result) and result in unquote(atoms) do
                {:cont, result}
              else
                {:halt, result}
              end
          end
        rescue
          e ->
            if e.__struct__ in unquote(exceptions) do
              {:cont, {:exception, e}}
            else
              reraise e, __STACKTRACE__
            end
        end
      end
    end
  end

  defp delays_from(stream_builder) do
    quote generated: true do
      delays = unquote(stream_builder)
      [0] |> Stream.concat(delays)
    end
  end

  defp parse_opts(opts) do
    cond do
      !Keyword.keyword?(opts) ->
        raise(ArgumentError, @retry_usage)

      missing_opt = Enum.find(@required_retry_options, &(&1 not in Keyword.keys(opts))) ->
        raise(ArgumentError, ~s(invalid syntax: you must provide the "#{missing_opt}" option))

      invalid_opt = Enum.find(Keyword.keys(opts), &(&1 not in @allowed_retry_options)) ->
        raise(ArgumentError, ~s(invalid syntax: option "#{invalid_opt}" is not supported))

      true ->
        Keyword.merge(@default_retry_options, opts)
    end
  end

  defp parse_clauses(clauses) do
    cond do
      !Keyword.keyword?(clauses) ->
        raise(ArgumentError, @retry_usage)

      missing_clause = Enum.find(@required_retry_clauses, &(&1 not in Keyword.keys(clauses))) ->
        raise(ArgumentError, ~s(invalid syntax: you must provide a "#{missing_clause}" clause))

      invalid_clause = Enum.find(Keyword.keys(clauses), &(&1 not in @allowed_retry_clauses)) ->
        raise(
          ArgumentError,
          ~s(invalid syntax: clause "#{invalid_clause}" is not supported)
        )

      true ->
        clauses_with_defaults = Keyword.merge(@default_retry_clauses, clauses)
        Enum.map(@allowed_retry_clauses, &Keyword.get(clauses_with_defaults, &1))
    end
  end
end
