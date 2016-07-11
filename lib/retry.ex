defmodule Retry do
  @moduledoc """
  Retry functions.
  """

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
  defmacro retry({:in, _, [retries, sleep]}, do: block) do
    quote do
      do_retry(
        fixed_delays(unquote(retries), unquote(sleep)),
        unquote(block_runner(block))
      )
    end
  end

  @doc """

  Retry block of code with a exponential backoff delay between attempts.

  Example

  ```elixir
  backoff 1000, delay_cap: 100 do
    # interact the external service
  end
  ```

  Runs the block repeated until it succeeds or 1 second elapses with an
  exponentially increasing delay between attempts. Execution is deemed a failure
  if the block returns `{:error, _}` or raises a runtime error.

  The `delay_cap` is optional. If specified it will be the max duration of any
  delay. In the example this is saying never delay more than 100ms between
  attempts. Omitting `delay_cap` is the same as setting it to `:infinity`.

  """
  defmacro backoff(time_budget, do: block) do
    quote do
      do_retry(
        exp_backoff_delays(unquote(time_budget), :infinity),
        unquote(block_runner(block))
      )
    end
  end
  defmacro backoff(time_budget, delay_cap: delay_cap, do: block) do
    quote do
      do_retry(
        exp_backoff_delays(unquote(time_budget), unquote(delay_cap)),
        unquote(block_runner(block))
      )
    end
  end

  @doc """

  Executes fun until it succeeds or we have run out of retry_delays. Each retry
  is preceded by a sleep of the specified retry delay.

  """
  def do_retry(retry_delays, fun) do
    delays = [0] |> Stream.concat(retry_delays)

    final_result = delays |> Enum.reduce_while(nil, fn(delay, _last_result) ->
      :timer.sleep(delay)
      fun.()
    end)

    case final_result do
      {:exception, e} -> raise e
      result          -> result
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

  @doc """

  Returns stream of delays that are exponentially increasing. Stream halts once
  the specified budget of milliseconds has elapsed.

  """
  def exp_backoff_delays(budget, delay_cap) do
    Stream.unfold({1, :os.system_time(:milli_seconds) + budget}, fn {failures, end_t} ->
      next_delay = figure_exp_delay(failures, delay_cap)
      now_t = :os.system_time(:milli_seconds)

      cond do
        now_t > end_t ->
          nil   # out of time
        (now_t + next_delay) > end_t ->
          {end_t - now_t, {failures + 1, end_t}}   # one last try
        true ->
          {next_delay, {failures + 1, end_t}}
      end
    end)
  end

  @doc """
  Returns stream that returns specified number of the specified delay.
  """
  def fixed_delays(count, delay) do
    [delay]
    |> Stream.cycle
    |> Stream.take(count)
  end

  defp figure_exp_delay(failures, :infinity) do
    :erlang.round((1 + :random.uniform) * 10 * :math.pow(2, failures))
  end
  defp figure_exp_delay(failures, delay_cap) do
    Enum.min([
      figure_exp_delay(failures, :infinity),
      delay_cap
    ])
  end
end
