defmodule Retry.DelayStreams do
  @moduledoc """

  This module provide a set of helper functions that produce delay streams for
  use with `retry`.

  """

  @doc """

  Returns a stream of delays that increase exponentially.

  Example

      retry exp_backoff do
        # ...
      end

  """
  def exp_backoff do
    Stream.unfold(1, fn failures ->
      {:erlang.round(10 * :math.pow(2, failures)), failures + 1}
    end)
  end

  @doc """

  Returns a stream of delays that increase linearly.

  Example

      retry lin_backoff(@fibonacci) do
        # ...
      end

  """
  def lin_backoff(initial_delay, factor) do
    Stream.unfold(initial_delay, fn last_delay ->
      next_d = last_delay * factor
      {next_d, next_d}
    end)
  end

  @doc """

  Returns a stream in which each element of `delays` is randomly adjusted no
  more than `proportion` of the delay.

  Example

      retry exp_backoff |> randomize do
        # ...
      end

  Produces an exponentially increasing delay stream where each delay is randomly
  adjusted to be within 10 percent of the original value

  """
  def randomize(delays, proportion \\ 0.1) do
    Stream.map(delays, fn d ->
      max_delta = round(d * proportion)
      shift = :rand.uniform(2 * max_delta) - max_delta
      d + shift
    end)
  end

  @doc """

  Returns a stream that is the same as `delays` except that the delays never
  exceed `max`. This allow capping the delay between attempts to some max value.

  Example

      retry exp_backoff |> cap(10_000) do
        # ...
      end

  Produces an exponentially increasing delay stream until the delay reaches 10
  seconds at which point it stops increasing

  """
  def cap(delays, max) do
    Stream.map(delays,
      fn d when d <= max -> d
        _  -> max
      end
    )
  end

  @doc """

  Returns a delay stream that is the same as `delays` except it limits the total
  life span of the stream to `time_budget`. This calculation takes the execution
  time of the block being retried into account.

  Example

      retry exp_backoff |> expiry(1000) do
        # ...
      end

  Produces a delay stream that ends after 1 second has elapsed since its
  creation.

  """
  def expiry(delays, time_budget) do
    end_t = :os.system_time(:milli_seconds) + time_budget

    Stream.transform(delays, :normal, fn preferred_delay, status ->
      now_t = :os.system_time(:milli_seconds)
      remaining_t = Enum.max([end_t - now_t, 0])

      cond do
        :at_end == status              # time expired!
          -> {:halt, status}
        preferred_delay > remaining_t  # one last try
          -> {[remaining_t], :at_end}
        true
          -> {[preferred_delay], status}
      end
    end)
  end
end
