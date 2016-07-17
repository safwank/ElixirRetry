defmodule RetryTest do
  use ExUnit.Case, async: true
  import Stream

  use Retry
  doctest Retry

  test "retry(with: _, do: _) retries execution for specified attempts when result is error tuple" do

    {elapsed, _} = :timer.tc fn ->
      import Stream

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
      import Stream

      result = retry with: [100, 75, 250] do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert (elapsed/1000 |> round) in 425..450
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
