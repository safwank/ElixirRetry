[![Build Status](https://travis-ci.org/safwank/ElixirRetry.svg?branch=master)](https://travis-ci.org/safwank/ElixirRetry)

# ElixirRetry

Simple Elixir macros for linear retries and exponential backoffs.

## Installation

Add `retry` to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [{:retry, "~> 0.5.0"}]
  end
```

## Documentation

Check out the [API reference](https://hexdocs.pm/retry/api-reference.html) for the latest documentation.

## Features

### Retrying

The `retry(with: _, do: _)` macro provides a way to retry a block of code on failure with a variety of delay and give up behaviors. The execution of a block is considered a failure if it returns `:error`, `{:error, _}` or raises a runtime error.

#### Example -- exponential backoff

```elixir
result = retry with: exp_backoff |> randomize |> expiry(10_000) do
  ExternalApi.do_something # fails if other system is down
end
```
This will try the block, and return the result, as soon as it succeeds. On a failure this example will wait an exponentially increasing amount of time (`exp_backoff/0`). Each delay will be randomly adjusted to remain within +/-10% of its original value (`randomize/2`). And finally it will give up entirely if the block has not succeeded with in 10 seconds (`expiry/2`).

#### Example -- linear backoff

```elixir
result = retry with: lin_backoff(10, 2) |> cap(1_000) |> Stream.take(10) do
  ExternalApi.do_something # fails if other system is down
end
```

This example doubles the delay with each retry, starting with 10 milliseconds, caps the delay at 1 second and gives up after 10 tries.

#### Delay streams

The `with:` option of `retry` accepts any `Stream` that yields integers. These integers will be interpreted as the amount of time to delay before retrying a failed operation. When the stream is exhausted `retry` will give up, returning the last value of the block.

##### Example

```elixir
result = retry with: Stream.cycle([500]) do
  ExternalApi.do_something # fails if other system is down
end
```

This will retry failures forever, waiting .5 seconds between attempts.


`Retry.DelayStreams` provides a set of fully composable helper functions for building useful delay behaviors such as the ones in previous examples. See the `Retry.DelayStreams` module docs for full details and addition behavior not covered here. For convenience these functions are imported by `use Retry` so you can, usually, use them without prefixing them with the module name.

### Waiting

Similar to `retry(with: _, do: _)`, the `wait(with: _, do: _)` macro provides a way to wait for a block of code to be truthy with a variety of delay and give up behaviors. The execution of a block is considered a failure if it returns `false` or `nil`.

```elixir
result = wait with: lin_backoff(100, 1) |> expiry(1_000) do
  we_there_yet?
end
```

This example retries every 100 milliseconds and caps the delay at 1 second.
