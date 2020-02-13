defmodule Retry.AnnotationTest do
  use ExUnit.Case

  defmodule Example do
    use Retry.Annotation

    @retry with: constant_backoff(100) |> take(10)
    def default_params(x, _opts \\ []) do
      {:ok, x}
    end

    @retry with: constant_backoff(100) |> take(10)
    def process(pid) do
      Agent.get_and_update(:test_store, fn s ->
        {s, max(0, s - 1)}
      end)
      |> case do
        0 ->
          {:ok, 0}

        n ->
          send(pid, {:attempt, n})
          {:error, "attempts remaining #{n}"}
      end
    end

    @retry with: constant_backoff(100) |> take(10)
    def process_with_guard(pid, x) when is_pid(pid) and is_binary(x) do
      Agent.get_and_update(:test_store, fn s ->
        {s, max(0, s - 1)}
      end)
      |> case do
        0 ->
          {:ok, x}

        n ->
          send(pid, {:attempt, n})
          {:error, "attempts remaining #{n}"}
      end
    end

    def no_retry(pid) do
      send(pid, :no_retry)
      {:error, "no_retry"}
    end

    def wrapper(pid) do
      internal(pid)
    end

    @retry with: constant_backoff(100) |> take(10)
    defp internal(pid) do
      Agent.get_and_update(:test_store, fn s ->
        {s, max(0, s - 1)}
      end)
      |> case do
        0 ->
          {:ok, 0}

        n ->
          send(pid, {:attempt, n})
          {:error, "attempts remaining #{n}"}
      end
    end
  end

  setup do
    {:ok, pid} = Agent.start_link(fn -> 0 end, name: :test_store)
    on_exit(fn -> assert_down(pid) end)

    :ok
  end

  test "will not retry function when ok tuple returned" do
    assert {:ok, 0} = Example.process(self())
    refute_receive {:attempt, _}
  end

  test "will retry on error tuple until ok tuple is received" do
    Agent.update(:test_store, fn _ -> 6 end)
    assert {:ok, 0} = Example.process(self())

    Enum.each(1..6, fn i ->
      assert_receive {:attempt, ^i}
    end)
  end

  test "should not retry function that are not annotated" do
    assert {:error, "no_retry"} = Example.no_retry(self())
    assert_receive :no_retry
    refute_receive :no_retry
  end

  test "guard clauses are still enforced on override function" do
    Agent.update(:test_store, fn _ -> 4 end)
    assert {:ok, "hello"} == Example.process_with_guard(self(), "hello")

    Enum.each(1..4, fn i -> assert_receive {:attempt, ^i} end)

    assert_raise FunctionClauseError, fn ->
      Example.process_with_guard(self(), 1)
    end
  end

  test "retries private functions as well" do
    Agent.update(:test_store, fn _ -> 7 end)
    assert {:ok, 0} = Example.wrapper(self())
    Enum.each(1..7, fn i -> assert_receive {:attempt, ^i} end)

    assert_raise UndefinedFunctionError, fn ->
      Example.internal(self())
    end
  end

  defp assert_down(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :kill)
    assert_receive {:DOWN, ^ref, _, _, _}
  end
end
