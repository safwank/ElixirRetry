defmodule RetryTest do
  use ExUnit.Case
  use Retry

  test "should retry execution for specified attempts when result is an error tuple" do
    retry 5 do
      {:error, "Error"}
    end
  end

  test "should retry execution for specified attempts when result is an error" do
    retry 5 do
      raise "Error"
    end
  end
end
