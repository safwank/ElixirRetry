defmodule RetryTest do
  use ExUnit.Case, async: true
  use Retry

  import Stream

  doctest Retry

  defmodule(CustomError, do: defexception(message: "custom error!"))

  describe "retry" do
    test "retries execution for specified attempts when result is error tuple" do
      {elapsed, _} =
        :timer.tc(fn ->
          result =
            retry with: linear_backoff(50, 1) |> take(5) do
              {:error, "Error"}
            after
              _ -> :ok
            else
              error -> error
            end

          assert result == {:error, "Error"}
        end)

      assert elapsed / 1_000 >= 250
    end

    test "retries execution for specified attempts when result is error atom" do
      {elapsed, _} =
        :timer.tc(fn ->
          result =
            retry with: linear_backoff(50, 1) |> take(5) do
              :error
            after
              _ -> :ok
            else
              error -> error
            end

          assert result == :error
        end)

      assert elapsed / 1_000 >= 250
    end

    test "retries execution for specified attempts when result is a specified atom" do
      retry_atom = :not_ok

      {elapsed, _} =
        :timer.tc(fn ->
          result =
            retry with: linear_backoff(50, 1) |> take(5), atoms: [retry_atom] do
              retry_atom
            after
              _ -> :ok
            else
              error -> error
            end

          assert result == retry_atom
        end)

      assert elapsed / 1_000 >= 250
    end

    test "retries execution for specified attempts when result is a tuple with a specified atom" do
      retry_atom = :not_ok

      {elapsed, _} =
        :timer.tc(fn ->
          result =
            retry with: linear_backoff(50, 1) |> take(5), atoms: [retry_atom] do
              {retry_atom, "Some error message"}
            after
              _ -> :ok
            else
              error -> error
            end

          assert result == {retry_atom, "Some error message"}
        end)

      assert elapsed / 1_000 >= 250
    end

    test "retries execution for specified attempts when error is raised" do
      {elapsed, _} =
        :timer.tc(fn ->
          assert_raise RuntimeError, fn ->
            retry with: linear_backoff(50, 1) |> take(5) do
              raise "Error"
            after
              _ -> :ok
            else
              error -> raise error
            end
          end
        end)

      assert elapsed / 1_000 >= 250
    end

    test "retries execution when a whitelisted exception is raised" do
      custom_error_list = [CustomError]

      {elapsed, _} =
        :timer.tc(fn ->
          assert_raise CustomError, fn ->
            retry with: linear_backoff(50, 1) |> take(5), rescue_only: custom_error_list do
              raise CustomError
            after
              _ -> :ok
            else
              error -> raise error
            end
          end
        end)

      assert elapsed / 1_000 >= 250
    end

    test "does not retry execution when an unknown exception is raised" do
      {elapsed, _} =
        :timer.tc(fn ->
          assert_raise CustomError, fn ->
            retry with: linear_backoff(50, 1) |> take(5) do
              raise CustomError
            after
              _ -> :ok
            else
              error -> raise error
            end
          end
        end)

      assert elapsed / 1_000 < 250
    end

    test "does not have to retry execution when there is no error" do
      result =
        retry with: linear_backoff(50, 1) |> take(5) do
          {:ok, "Everything's so awesome!"}
        after
          result -> result
        else
          _ -> :error
        end

      assert result == {:ok, "Everything's so awesome!"}
    end

    test "stream builder works with any Enum" do
      {elapsed, _} =
        :timer.tc(fn ->
          result =
            retry with: [100, 75, 250] do
              {:error, "Error"}
            after
              _ -> :ok
            else
              error -> error
            end

          assert result == {:error, "Error"}
        end)

      assert round(elapsed / 1_000) in 425..450
    end

    test "with invalid clauses raises argument error" do
      error_message = ~s/invalid syntax, only "retry", "after" and "else" are permitted/

      assert_raise ArgumentError, error_message, fn ->
        Code.eval_string("retry [1, 2, 3], foo: :invalid, bar: :not_ok", [], __ENV__)
      end
    end
  end

  describe "retry_while" do
    test "retries execution for specified attempts when halt is not emitted" do
      {elapsed, _} =
        :timer.tc(fn ->
          result =
            retry_while with: linear_backoff(50, 1) |> take(5) do
              {:cont, "not finishing"}
            end

          assert result == "not finishing"
        end)

      assert elapsed / 1_000 >= 250
    end

    test "does not have to retry execution when halt is emitted" do
      result =
        retry_while with: linear_backoff(50, 1) |> take(5) do
          {:halt, "Everything's so awesome!"}
        end

      assert result == "Everything's so awesome!"
    end

    test "allows an accumulator to be passed through" do
      result =
        retry_while acc: 0, with: linear_backoff(50, 1) |> take(5) do
          acc -> {:cont, acc + 1}
        end

      assert result == 6
    end

    test "accepts any order of parameters" do
      result =
        retry_while with: linear_backoff(50, 1) |> take(5), acc: 0 do
          acc -> {:cont, acc + 1}
        end

      assert result == 6
    end

    test "pattern-match in accumulator works" do
      result =
        retry_while acc: 0, with: linear_backoff(50, 1) |> take(5) do
          3 -> {:halt, :ok}
          acc -> {:cont, acc + 1}
        end

      assert result == :ok
    end

    test "responds with a meaningful error when clauses are not given" do
      assert_raise CompileError, ~r/expected -> clauses for :do in "case"$/, fn ->
        defmodule BadRetryWhileSyntax do
          def retry_while do
            retry_while with: linear_backoff(50, 1) |> take(5), acc: 0 do
              {:cont, acc + 1}
            end
          end
        end
      end
    end
  end

  describe "wait" do
    test "retries execution for specified attempts when result is false" do
      {elapsed, _} =
        :timer.tc(fn ->
          result =
            wait linear_backoff(50, 1) |> expiry(250) do
              false
            after
              result -> result
            else
              result -> result
            end

          refute result
        end)

      assert elapsed / 1_000 >= 250
    end

    test "retries execution for specified attempts when result is nil" do
      {elapsed, _} =
        :timer.tc(fn ->
          result =
            wait linear_backoff(50, 1) |> take(5) do
              nil
            after
              result -> result
            else
              result -> result
            end

          refute result
        end)

      assert elapsed / 1_000 >= 250
    end

    test "does not have to retry execution when result is truthy" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          {:ok, "Everything's so awesome!"}
        after
          result -> result
        else
          result -> result
        end

      assert result == {:ok, "Everything's so awesome!"}
    end

    test "after executes only when result is truthy" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          {:ok, "Everything's so awesome!"}
        after
          _ ->
            {:ok, "More awesome"}
        else
          result -> result
        end

      assert result == {:ok, "More awesome"}
    end

    test "after does not execute when result remains false" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          false
        after
          _ ->
            {:ok, "More awesome"}
        else
          result -> result
        end

      refute result
    end

    test "after does not execute when result remains nil" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          nil
        after
          _ ->
            {:ok, "More awesome"}
        else
          result -> result
        end

      refute result
    end

    test "else does not execute when result is truthy" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          {:ok, "Everything's so awesome!"}
        after
          _ ->
            {:ok, "More awesome"}
        else
          _ ->
            {:error, "Not awesome"}
        end

      assert result == {:ok, "More awesome"}
    end

    test "else executes when result remains false" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          false
        after
          _ ->
            {:ok, "More awesome"}
        else
          _ ->
            {:error, "Not awesome"}
        end

      assert result == {:error, "Not awesome"}
    end

    test "else executes when result remains nil" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          nil
        after
          _ ->
            {:ok, "More awesome"}
        else
          _ ->
            {:error, "Not awesome"}
        end

      assert result == {:error, "Not awesome"}
    end

    test "handles multiple lines in wait and multiple matches in else" do
      result =
        wait linear_backoff(50, 1) |> take(2) do
          val = nil
          val
        after
          result ->
            {:ok, result}
        else
          nil ->
            {:error, "Not awesome"}

          false ->
            {:error, "Not awesome"}
        end

      assert result == {:error, "Not awesome"}
    end

    test "with invalid clauses raises argument error" do
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
        Code.eval_string(
          "wait [1, 2, 3], do: :valid, after: :valid, after: :duplicate",
          [],
          __ENV__
        )
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
end
