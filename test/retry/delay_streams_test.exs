defmodule Retry.DelayStreamsTest do
  use ExUnit.Case, async: true
  import Retry.DelayStreams

  test "exponential backoff" do
    exp_backoff
    |> Enum.take(5)
    |> Enum.scan(fn (delay, last_delay) ->
      assert delay > last_delay
      delay
    end)
  end

  test "lin_backoff/2" do
    lin_backoff(10, 1.5)
    |> Enum.take(5)
    |> Enum.scan(fn (delay, last_delay) ->
      assert (last_delay * 1.5) == delay
      delay
    end)
  end

  test "delay streams can be capped" do
    exp_backoff
    |> cap(1000)
    |> Stream.take(10)
    |> Enum.all?(&(&1 <= 1000))
  end

  test "expiry/1 limits life time" do
    {elapsed, _} = :timer.tc fn ->
      Stream.cycle([500])
      |> expiry(1000)
      |> Enum.each(&:timer.sleep(&1))
    end

    assert_in_delta elapsed/1000, 1000, 10
  end

  test "expiry/1 doesn't mess up delays" do
    assert exp_backoff |> Enum.take(5) ==
      exp_backoff |> expiry(1000) |> Enum.take(5)
  end

  test "ramdomize/1 randomizes streams" do
    delays = Stream.cycle([500])
    |> randomize
    |> Enum.take(100)

    Enum.each(delays, fn (delay) ->
      assert_in_delta delay, 500, 500 * 0.1 + 1
      delay
    end)

    assert Enum.any?(delays, &(&1 != 500))
  end

  test "ramdomize/2 randomizes streams" do
    delays = Stream.cycle([500])
    |> randomize(0.2)
    |> Enum.take(100)

    Enum.each(delays, fn (delay) ->
      assert_in_delta delay, 500, 500 * 0.2 + 1
      delay
    end)

    assert Enum.any?(delays, &(abs(&1 - 500) > (500 * 0.1)))
  end
end
