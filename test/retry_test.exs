defmodule RetryTest do
  use ExUnit.Case
  use Retry

  test "should retry execution for specified attempts when result is error tuple" do
    result = retry 5 in 500 do
      {:error, "Error"}
    end

    assert result = {:error, "Error"}
  end

  test "should retry execution for specified attempts when error is raised" do
    assert_raise RuntimeError, fn ->
      retry 5 in 500 do
        raise "Error"
      end
    end
  end
end
