defmodule RetryTest do
  use ExUnit.Case
  use Retry

  test "retry should retry execution for specified attempts when result is error tuple" do
    result = retry 5 in 500 do
      {:error, "Error"}
    end

    assert result = {:error, "Error"}
  end

  test "retry should retry execution for specified attempts when error is raised" do
    assert_raise RuntimeError, fn ->
      retry 5 in 500 do
        raise "Error"
      end
    end
  end

  test "backoff should retry execution for specified period when result is error tuple" do
    result = backoff 1000 do
      {:error, "Error"}
    end

    assert result = {:error, "Error"}
  end

  test "backoff should retry execution for specified period when error is raised" do
    assert_raise RuntimeError, fn ->
      backoff 1000 do
        raise "Error"
      end
    end
  end
end
