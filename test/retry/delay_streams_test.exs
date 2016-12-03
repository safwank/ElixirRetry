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
    assert exp_backoff
      |> cap(1_000)
      |> Stream.take(10)
      |> Enum.all?(&(&1 <= 1_000))
  end

  test "expiry/1 limits lifetime" do
    {elapsed, _} = :timer.tc fn ->
      [500]
      |> Stream.cycle
      |> expiry(1_000)
      |> Enum.each(&:timer.sleep(&1))
    end

    assert_in_delta elapsed/1_000, 1_000, 10
  end

  test "expiry/1 doesn't mess up delays" do
    assert exp_backoff |> Enum.take(5) == exp_backoff |> expiry(1_000) |> Enum.take(5)
  end

  test "ramdomize/1 randomizes streams" do
    delays = [500]
      |> Stream.cycle()
      |> randomize
      |> Enum.take(100)

    Enum.each(delays, fn (delay) ->
      assert_in_delta delay, 500, 500 * 0.1 + 1
      delay
    end)

    assert Enum.any?(delays, &(&1 != 500))
  end

  test "ramdomize/2 randomizes streams" do
    delays = [500]
      |> Stream.cycle()
      |> randomize(0.2)
      |> Enum.take(100)

    Enum.each(delays, fn (delay) ->
      assert_in_delta delay, 500, 500 * 0.2 + 1
      delay
    end)

    assert Enum.any?(delays, &(abs(&1 - 500) > (500 * 0.1)))
  end
end
