defmodule RetryTest do
  use ExUnit.Case, async: true
  use Retry

  import Stream

  doctest Retry

  defmodule(CustomError, do: defexception(message: "custom error!"))

  test "retry retries execution for specified attempts when result is error tuple" do
    {elapsed, _} =
      :timer.tc(fn ->
        result =
          retry with: lin_backoff(50, 1) |> take(5) do
            {:error, "Error"}
          end

        assert result == {:error, "Error"}
      end)

    assert elapsed / 1_000 >= 250
  end

  test "retry retries execution for specified attempts when result is error atom" do
    {elapsed, _} =
      :timer.tc(fn ->
        result =
          retry with: lin_backoff(50, 1) |> take(5) do
            :error
          end

        assert result == :error
      end)

    assert elapsed / 1_000 >= 250
  end

  test "retry retries execution for specified attempts when result is a specified atom" do
    retry_atom = :not_ok

    {elapsed, _} =
      :timer.tc(fn ->
        result =
          retry with: lin_backoff(50, 1) |> take(5), atoms: [retry_atom] do
            retry_atom
          end

        assert result == retry_atom
      end)

    assert elapsed / 1_000 >= 250
  end

  test "retry retries execution for specified attempts when result is a tuple with a specified atom" do
    retry_atom = :not_ok

    {elapsed, _} =
      :timer.tc(fn ->
        result =
          retry with: lin_backoff(50, 1) |> take(5), atoms: [retry_atom] do
            {retry_atom, "Some error message"}
          end

        assert result == {retry_atom, "Some error message"}
      end)

    assert elapsed / 1_000 >= 250
  end

  test "retry retries execution for specified attempts when error is raised" do
    {elapsed, _} =
      :timer.tc(fn ->
        assert_raise RuntimeError, fn ->
          retry with: lin_backoff(50, 1) |> take(5) do
            raise "Error"
          end
        end
      end)

    assert elapsed / 1_000 >= 250
  end

  test "retry retries execution when a whitelisted exception is raised" do
    custom_error_list = [CustomError]

    {elapsed, _} =
      :timer.tc(fn ->
        assert_raise CustomError, fn ->
          retry with: lin_backoff(50, 1) |> take(5), rescue_only: custom_error_list do
            raise CustomError
          end
        end
      end)

    assert elapsed / 1_000 >= 250
  end

  test "retry does not have to retry execution when there is no error" do
    result =
      retry with: lin_backoff(50, 1) |> take(5) do
        {:ok, "Everything's so awesome!"}
      end

    assert result == {:ok, "Everything's so awesome!"}
  end

  test "retry stream builder works with any Enum" do
    {elapsed, _} =
      :timer.tc(fn ->
        result =
          retry with: [100, 75, 250] do
            {:error, "Error"}
          end

        assert result == {:error, "Error"}
      end)

    assert round(elapsed / 1_000) in 425..450
  end

  test "retry_while retries execution for specified attempts when halt is not emitted" do
    {elapsed, _} =
      :timer.tc(fn ->
        result =
          retry_while with: lin_backoff(50, 1) |> take(5) do
            {:cont, "not finishing"}
          end

        assert result == "not finishing"
      end)

    assert elapsed / 1_000 >= 250
  end

  test "retry_while does not have to retry execution when halt is emitted" do
    result =
      retry_while with: lin_backoff(50, 1) |> take(5) do
        {:halt, "Everything's so awesome!"}
      end

    assert result == "Everything's so awesome!"
  end

  test "wait retries execution for specified attempts when result is false" do
    {elapsed, _} =
      :timer.tc(fn ->
        result =
          wait lin_backoff(50, 1) |> expiry(250) do
            false
          end

        refute result
      end)

    assert elapsed / 1_000 >= 250
  end

  test "wait retries execution for specified attempts when result is nil" do
    {elapsed, _} =
      :timer.tc(fn ->
        result =
          wait lin_backoff(50, 1) |> take(5) do
            nil
          end

        refute result
      end)

    assert elapsed / 1_000 >= 250
  end

  test "wait does not have to retry execution when result is truthy" do
    result =
      wait lin_backoff(50, 1) |> take(2) do
        {:ok, "Everything's so awesome!"}
      end

    assert result == {:ok, "Everything's so awesome!"}
  end

  test "after executes only when result is truthy" do
    result =
      wait lin_backoff(50, 1) |> take(2) do
        {:ok, "Everything's so awesome!"}
      after
        {:ok, "More awesome"}
      end

    assert result == {:ok, "More awesome"}
  end

  test "after does not execute when result remains false" do
    result =
      wait lin_backoff(50, 1) |> take(2) do
        false
      after
        {:ok, "More awesome"}
      end

    refute result
  end

  test "after does not execute when result remains nil" do
    result =
      wait lin_backoff(50, 1) |> take(2) do
        nil
      after
        {:ok, "More awesome"}
      end

    refute result
  end

  test "else does not execute when result is truthy" do
    result =
      wait lin_backoff(50, 1) |> take(2) do
        {:ok, "Everything's so awesome!"}
      after
        {:ok, "More awesome"}
      else
        {:error, "Not awesome"}
      end

    assert result == {:ok, "More awesome"}
  end

  test "else executes when result remains false" do
    result =
      wait lin_backoff(50, 1) |> take(2) do
        false
      after
        {:ok, "More awesome"}
      else
        {:error, "Not awesome"}
      end

    assert result == {:error, "Not awesome"}
  end

  test "else executes when result remains nil" do
    result =
      wait lin_backoff(50, 1) |> take(2) do
        nil
      after
        {:ok, "More awesome"}
      else
        {:error, "Not awesome"}
      end

    assert result == {:error, "Not awesome"}
  end

  test "wait with invalid clauses raises argument error" do
    error_message = ~s/invalid syntax, only "wait", "after" and "else" are permitted/

    assert_raise ArgumentError, error_message, fn ->
      Code.eval_string("wait [1, 2, 3], foo: :invalid", [], __ENV__)
    end

    assert_raise ArgumentError, error_message, fn ->
      Code.eval_string("wait [1, 2, 3], do: :valid, foo: :invalid", [], __ENV__)
    end

    assert_raise ArgumentError, error_message, fn ->
      Code.eval_string("wait [1, 2, 3], do: :valid, do: :duplicate", [], __ENV__)
    end

    assert_raise ArgumentError, error_message, fn ->
      Code.eval_string("wait [1, 2, 3], do: :valid, after: :valid, after: :duplicate", [], __ENV__)
    end

    assert_raise ArgumentError, error_message, fn ->
      Code.eval_string(
        "wait [1, 2, 3], do: :valid, after: :valid, else: :valid, else: :duplicate",
        [],
        __ENV__
      )
    end

    assert_raise ArgumentError, error_message, fn ->
      Code.eval_string("wait [1, 2, 3], do: false, else: :wrong, after: :order", [], __ENV__)
    end
  end
end
