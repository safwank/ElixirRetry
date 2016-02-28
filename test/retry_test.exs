defmodule RetryTest do
  use ExUnit.Case
  use Retry
  doctest Retry

  test "retry should retry execution for specified attempts when result is error tuple" do
    {elapsed, _} = :timer.tc fn ->
      result = retry 5 in 500 do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert elapsed/1000 >= 2500
  end

  test "retry should retry execution for specified attempts when error is raised" do
    {elapsed, _} = :timer.tc fn ->
      assert_raise RuntimeError, fn ->
        retry 5 in 500 do
          raise "Error"
        end
      end
    end

    assert elapsed/1000 >= 2500
  end

  test "retry should not have to retry execution when there is no error" do
    result = retry 5 in 500 do
      {:ok, "Everything's so awesome!"}
    end

    assert result == {:ok, "Everything's so awesome!"}
  end

  test "backoff should retry execution for specified period when result is error tuple" do
    {elapsed, _} = :timer.tc fn ->
      result = backoff 1000 do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert elapsed/1000 <= 1000
  end

  test "backoff should retry execution for specified period when error is raised" do
    {elapsed, _} = :timer.tc fn ->
      assert_raise RuntimeError, fn ->
        backoff 1000 do
          raise "Error"
        end
      end
    end

    assert elapsed/1000 <= 1000
  end

  test "backoff should not have to retry execution when there is no error" do
    result = backoff 1000 do
      {:ok, "Everything's so awesome!"}
    end

    assert result == {:ok, "Everything's so awesome!"}
  end
end
