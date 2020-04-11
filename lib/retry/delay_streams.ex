defmodule Retry.DelayStreams do
  @moduledoc """

  This module provide a set of helper functions that produce delay streams for
  use with `retry`.

  """

  @doc """

  Returns a stream of delays that increase exponentially.

  Example

      retry with: exponential_backoff do
        # ...
      end

  """
  @spec exponential_backoff(pos_integer(), pos_integer()) :: Enumerable.t()
  def exponential_backoff(initial_delay \\ 10, factor \\ 2) do
    Stream.unfold(initial_delay, fn last_delay ->
      {last_delay, round(last_delay * factor)}
    end)
  end

  @doc """

  Returns a stream in which each element of `delays` is randomly adjusted to a number
  between 1 and the original delay.

  Example

      retry with: exponential_backoff() |> jitter() do
        # ...
      end

  """
  @spec jitter(Enumerable.t()) :: Enumerable.t()
  def jitter(delays) do
    Stream.map(delays, fn delay ->
      delay
      |> trunc
      |> random_uniform
    end)
  end

  @doc """

  Returns a stream of delays that increase linearly.

  Example

      retry with: linear_backoff(50, 2) do
        # ...
      end

  """
  @spec linear_backoff(pos_integer(), pos_integer()) :: Enumerable.t()
  def linear_backoff(initial_delay, factor) do
    Stream.unfold(0, fn failures ->
      next_d = initial_delay + failures * factor
      {next_d, failures + 1}
    end)
  end

  @doc """

  Returns a constant stream of delays.

  Example

      retry with: constant_backoff(50) do
        # ...
      end

  """
  @spec constant_backoff(pos_integer()) :: Enumerable.t()
  def constant_backoff(delay \\ 100) do
    Stream.repeatedly(fn -> delay end)
  end

  @doc """

  Returns a stream in which each element of `delays` is randomly adjusted no
  more than `proportion` of the delay.

  Example

      retry with: exponential_backoff() |> randomize do
        # ...
      end

  Produces an exponentially increasing delay stream where each delay is randomly
  adjusted to be within 10 percent of the original value

  """
  @spec randomize(Enumerable.t(), float()) :: Enumerable.t()
  def randomize(delays, proportion \\ 0.1) do
    Stream.map(delays, fn d ->
      max_delta = round(d * proportion)
      shift = random_uniform(2 * max_delta) - max_delta

      case d + shift do
        n when n <= 0 -> 0
        n -> n
      end
    end)
  end

  @doc """

  Returns a stream that is the same as `delays` except that the delays never
  exceed `max`. This allow capping the delay between attempts to some max value.

  Example

      retry with: exponential_backoff() |> cap(10_000) do
        # ...
      end

  Produces an exponentially increasing delay stream until the delay reaches 10
  seconds at which point it stops increasing

  """
  @spec cap(Enumerable.t(), pos_integer()) :: Enumerable.t()
  def cap(delays, max) do
    Stream.map(
      delays,
      fn
        d when d <= max -> d
        _ -> max
      end
    )
  end

  @doc """

  Returns a delay stream that is the same as `delays` except it limits the total
  life span of the stream to `time_budget`. This calculation takes the execution
  time of the block being retried into account.

  The execution of the code within the block will not be interrupted, so
  the total time of execution may run over the `time_budget` depending on how
  long a single try will take.

  Optionally, you can specify a minimum delay so the smallest value doesn't go
  below the threshold.

  Example

      retry with: exponential_backoff() |> expiry(1_000) do
        # ...
      end

  Produces a delay stream that ends after 1 second has elapsed since its
  creation.

  """
  @spec expiry(Enumerable.t(), pos_integer(), pos_integer()) :: Enumerable.t()
  def expiry(delays, time_budget, min_delay \\ 100) do
    end_t = :os.system_time(:milli_seconds) + time_budget

    Stream.transform(delays, :normal, fn preferred_delay, status ->
      now_t = :os.system_time(:milli_seconds)
      remaining_t = Enum.max([end_t - now_t, min_delay])

      cond do
        # time expired!
        :at_end == status ->
          {:halt, status}

        # one last try
        preferred_delay >= remaining_t or remaining_t == min_delay ->
          {[remaining_t], :at_end}

        true ->
          {[preferred_delay], status}
      end
    end)
  end

  defp random_uniform(n) when n <= 0, do: 0
  defp random_uniform(n), do: :rand.uniform(n)
end
