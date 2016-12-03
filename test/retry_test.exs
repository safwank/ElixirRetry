defmodule RetryTest do
  use ExUnit.Case, async: true
  import Stream

  use Retry
  doctest Retry

  test "retry retries execution for specified attempts when result is error tuple" do
    {elapsed, _} = :timer.tc fn ->
      result = retry with: lin_backoff(500, 1) |> take(5) do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert elapsed/1000 >= 2500
  end

  test "retry retries execution for specified attempts when result is error atom" do
    {elapsed, _} = :timer.tc fn ->
      result = retry with: lin_backoff(500, 1) |> take(5) do
        :error
      end

      assert result == :error
    end

    assert elapsed/1000 >= 2500
  end

  test "retry retries execution for specified attempts when error is raised" do
    {elapsed, _} = :timer.tc fn ->
      assert_raise RuntimeError, fn ->
        retry with: lin_backoff(500, 1) |> take(5) do
          raise "Error"
        end
      end
    end

    assert elapsed/1000 >= 2500
  end

  test "retry does not have to retry execution when there is no error" do
    result = retry with: lin_backoff(500, 1) |> take(5) do
      {:ok, "Everything's so awesome!"}
    end

    assert result == {:ok, "Everything's so awesome!"}
  end

  test "retry stream builder works with any Enum" do
    {elapsed, _} = :timer.tc fn ->
      result = retry with: [100, 75, 250] do
        {:error, "Error"}
      end

      assert result == {:error, "Error"}
    end

    assert round(elapsed/1000) in 425..450
  end

  test "retry_while retries execution for specified attempts when halt is not emitted" do
    {elapsed, _} = :timer.tc fn ->
      result = retry_while with: lin_backoff(500, 1) |> take(5) do
        {:cont, "not finishing"}
      end

      assert result == "not finishing"
    end

    assert elapsed/1000 >= 2500
  end

  test "retry_while does not have to retry execution when halt is emitted" do
    result = retry_while with: lin_backoff(500, 1) |> take(5) do
      {:halt, "Everything's so awesome!"}
    end

    assert result == "Everything's so awesome!"
  end

  test "wait retries execution for specified attempts when result is false" do
    {elapsed, _} = :timer.tc fn ->
      result = wait lin_backoff(500, 1) |> expiry(2_500) do
        false
      end

      refute result
    end

    assert elapsed/1000 >= 2500
  end

  test "wait retries execution for specified attempts when result is nil" do
    {elapsed, _} = :timer.tc fn ->
      result = wait lin_backoff(500, 1) |> take(5) do
        nil
      end

      refute result
    end

    assert elapsed/1000 >= 2500
  end

  test "wait does not have to retry execution when result is truthy" do
    result = wait lin_backoff(500, 1) |> take(5) do
      {:ok, "Everything's so awesome!"}
    end

    assert result == {:ok, "Everything's so awesome!"}
  end

  test "then executes only when result is truthy" do
    result = wait lin_backoff(500, 1) |> take(5) do
      {:ok, "Everything's so awesome!"}
    then
      {:ok, "More awesome"}
    end

    assert result == {:ok, "More awesome"}
  end

  test "then does not execute when result remains false" do
    result = wait lin_backoff(500, 1) |> take(5) do
      false
    then
      {:ok, "More awesome"}
    end

    refute result
  end

  test "then does not execute when result remains nil" do
    result = wait lin_backoff(500, 1) |> take(5) do
      nil
    then
      {:ok, "More awesome"}
    end

    refute result
  end

  test "else does not execute when result is truthy" do
    result = wait lin_backoff(500, 1) |> take(5) do
      {:ok, "Everything's so awesome!"}
    then
      {:ok, "More awesome"}
    else
      {:error, "Not awesome"}
    end

    assert result == {:ok, "More awesome"}
  end

  test "else executes when result remains false" do
    result = wait lin_backoff(500, 1) |> take(5) do
      false
    then
      {:ok, "More awesome"}
    else
      {:error, "Not awesome"}
    end

    assert result == {:error, "Not awesome"}
  end

  test "else executes when result remains nil" do
    result = wait lin_backoff(500, 1) |> take(5) do
      nil
    then
      {:ok, "More awesome"}
    else
      {:error, "Not awesome"}
    end

    assert result == {:error, "Not awesome"}
  end
end
