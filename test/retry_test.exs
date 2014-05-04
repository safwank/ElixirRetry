defmodule RetryTest do
  use ExUnit.Case
  use Retry

  test "should execute function" do
    retry IO.puts "Foo Bar"
  end
end
