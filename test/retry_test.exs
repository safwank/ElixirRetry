defmodule RetryTest do
  use ExUnit.Case, async: true
  import Stream

  use Retry
  doctest Retry

  test "retry(with: _, do: _) retries execution for specified attempts when result is error tuple" do
    {elapsed, _} = :timer.tc fn ->
      result = retry with: lin_backoff(500, 1) |> take(5) do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert elapsed/1000 >= 2500
  end

  test "retry should retry execution for specified attempts when error is raised" do
    {elapsed, _} = :timer.tc fn ->
      assert_raise RuntimeError, fn ->
        retry with: lin_backoff(500, 1) |> take(5) do
          raise "Error"
        end
      end
    end

    assert elapsed/1000 >= 2500
  end

  test "retry should not have to retry execution when there is no error" do
    result = retry with: lin_backoff(500, 1) |> take(5) do
      {:ok, "Everything's so awesome!"}
    end

    assert result == {:ok, "Everything's so awesome!"}
  end

  test "retry(with: _, do: _) works with any Enum" do
    {elapsed, _} = :timer.tc fn ->
      result = retry with: [100, 75, 250] do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert round(elapsed/1000) in 425..450
  end

  test "retry_while should retry execution for specified attempts when halt is not emitted" do
    {elapsed, _} = :timer.tc fn ->
      result = retry_while with: lin_backoff(500, 1) |> take(5) do
        {:cont, "not finishing"}
      end

      assert result == "not finishing"
    end

    assert elapsed/1000 >= 2500
  end

  test "retry_while should not have to retry execution when halt is emitted" do
    result = retry_while with: lin_backoff(500, 1) |> take(5) do
      {:halt, "Everything's so awesome!"}
    end

    assert result == "Everything's so awesome!"
  end

  test "wait should retry execution for specified attempts when result is false" do
    {elapsed, _} = :timer.tc fn ->
      result = wait with: lin_backoff(500, 1) |> expiry(2_500) do
        false
      end

      refute result
    end

    assert elapsed/1000 >= 2500
  end

  test "wait should retry execution for specified attempts when result is nil" do
    {elapsed, _} = :timer.tc fn ->
      result = wait with: lin_backoff(500, 1) |> take(5) do
        nil
      end

      refute result
    end

    assert elapsed/1000 >= 2500
  end

  test "wait should not have to retry execution when result is truthy" do
    result = wait with: lin_backoff(500, 1) |> take(5) do
      {:ok, "Everything's so awesome!"}
    end

    assert result == {:ok, "Everything's so awesome!"}
  end

  # backward compatibility tests
  # -----

  test "retry should retry execution for specified attempts when result is error tuple" do
    {elapsed, _} = :timer.tc fn ->
      result = retry 5 in 500 do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert elapsed/1000 >= 2500
  end

  test "backoff should retry execution for specified period when result is error tuple" do
    {elapsed, _} = :timer.tc fn ->
      result = backoff 1000 do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert_in_delta elapsed/1000, 1000, 10
  end

  test "backoff should retry execution for specified period when error is raised" do
    {elapsed, _} = :timer.tc fn ->
      assert_raise RuntimeError, fn ->
        backoff 1000 do
          raise "Error"
        end
      end
    end

    assert_in_delta elapsed/1000, 1000, 10
  end

  test "backoff should not have to retry execution when there is no error" do
    result = backoff 1000 do
      {:ok, "Everything's so awesome!"}
    end

    assert result == {:ok, "Everything's so awesome!"}
  end
end
