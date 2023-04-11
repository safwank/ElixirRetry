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

  @retry_meta %{
    options: %{
      required: [:with],
      allowed: [:with, :atoms, :rescue_only],
      default: [
        atoms: [:error],
        rescue_only: [RuntimeError]
      ]
    },
    clauses: %{
      required: [:do],
      allowed: [:do, :after, :else],
      default: [
        else:
          quote do
            e when is_exception(e) -> raise e
            e -> e
          end,
        after:
          quote do
            result -> result
          end
      ]
    },
    usage: """
    Invalid Syntax. Usage:

    retry with: ... do
      ...
    end
    """
  }

  @wait_meta %{
    options: %{required: [], allowed: [], default: []},
    clauses: %{
      required: [:do],
      allowed: [:do, :after, :else],
      default: [
        else:
          quote do
            error -> {:error, error}
          end,
        after:
          quote do
            result -> {:ok, result}
          end
      ]
    },
    usage: """
    Invalid Syntax. Usage:

    wait ... do
      ...
    end
    """
  }

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

  The `after` and `else` clauses are optional. By default, a successful value is just returned. If
  the timeout expires, the last erroneous value is returned or the last exception is re-raised.
  Essentially, this:

      retry with: ... do
        ...
      end

  Is equivalent to:

      retry with: ... do
        ...
      after
        result -> result
      else
        e when is_exception(e) -> raise e
        e -> e
      end
  """
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro retry(opts, clauses) when is_list(opts) and is_list(clauses) do
    opts = parse_opts(opts, @retry_meta)
    [do_clause, after_clause, else_clause] = parse_clauses(clauses, @retry_meta)
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
    raise(ArgumentError, @retry_meta.usage)
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

  The `after` block evaluates only when the `do` block returns a truthy
  value. On the other hand, the `else` block evaluates only when the
  `do` block remains falsy after timeout.Both are optional. By default,
  a success value will be returned as `{:ok, value}` and an erroneous
  value will be returned as `{:error, value}`.

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
  defmacro wait(stream_builder, clauses) do
    [do_clause, after_clause, else_clause] = parse_clauses(clauses, @wait_meta)

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

  defp parse_opts(opts, meta) do
    cond do
      !Keyword.keyword?(opts) ->
        raise(ArgumentError, meta.usage)

      missing_opt = Enum.find(meta.options.required, &(&1 not in Keyword.keys(opts))) ->
        raise(ArgumentError, ~s(invalid syntax: you must provide the "#{missing_opt}" option))

      invalid_opt = Enum.find(Keyword.keys(opts), &(&1 not in meta.options.allowed)) ->
        raise(ArgumentError, ~s(invalid syntax: option "#{invalid_opt}" is not supported))

      true ->
        Keyword.merge(meta.options.default, opts)
    end
  end

  defp parse_clauses(clauses, meta) do
    cond do
      !Keyword.keyword?(clauses) ->
        raise(ArgumentError, meta.usage)

      missing_clause = Enum.find(meta.clauses.required, &(&1 not in Keyword.keys(clauses))) ->
        raise(ArgumentError, ~s(invalid syntax: you must provide a "#{missing_clause}" clause))

      invalid_clause = Enum.find(Keyword.keys(clauses), &(&1 not in meta.clauses.allowed)) ->
        raise(
          ArgumentError,
          ~s(invalid syntax: clause "#{invalid_clause}" is not supported)
        )

      (dup_clauses = Enum.uniq(Keyword.keys(clauses) -- Enum.uniq(Keyword.keys(clauses)))) != [] ->
        raise(
          ArgumentError,
          ~s(invalid syntax: duplicate clauses: #{Enum.join(dup_clauses, ", ")})
        )

      true ->
        clauses_with_defaults = Keyword.merge(meta.clauses.default, clauses)
        Enum.map(meta.clauses.allowed, &Keyword.get(clauses_with_defaults, &1))
    end
  end
end
