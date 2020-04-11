[![Build Status](https://travis-ci.org/safwank/ElixirRetry.svg?branch=master)](https://travis-ci.org/safwank/ElixirRetry)

# ElixirRetry

Simple Elixir macros for linear retry, exponential backoff and wait with composable delays.

## Installation

Add `retry` to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [{:retry, "~> 0.14"}]
  end
```

Ensure `retry` is started before your application:

```elixir
  def application do
    [applications: [:retry]]
  end
```

## Documentation

Check out the [API reference](https://hexdocs.pm/retry/api-reference.html) for the latest documentation.

## Features

### Retrying

The `retry([with: _,] do: _, after: _, else: _)` macro provides a way to retry a block of code on failure with a variety of delay and give up behaviors. By default, the execution of a block is considered a failure if it returns `:error`, `{:error, _}` or raises a runtime error.

An optional list of atoms can be specified in `:atoms` if you need to retry anything other than `:error` or `{:error, _}`, e.g. `retry([with: _, atoms: [:not_ok]], do: _, after: _, else: _)`.

Similarly, an optional list of exceptions can be specified in `:rescue_only` if you need to retry anything other than `RuntimeError`, e.g. `retry([with: _, rescue_only: [CustomError]], do: _, after: _, else: _)`.

The `after` block evaluates only when the `do` block returns a valid value before timeout.

On the other hand, the `else` block evaluates only when the `do` block remains erroneous after timeout.

#### Example -- constant backoff

```elixir
result = retry with: constant_backoff(100) |> Stream.take(10) do
  ExternalApi.do_something # fails if other system is down
after
  result -> result
else
  error -> error
end
```

This example retries every 100 milliseconds and gives up after 10 attempts.

#### Example -- linear backoff

```elixir
result = retry with: linear_backoff(10, 2) |> cap(1_000) |> Stream.take(10) do
  ExternalApi.do_something # fails if other system is down
after
  result -> result
else
  error -> error
end
```

This example increases the delay linearly with each retry, starting with 10 milliseconds, caps the delay at 1 second and gives up after 10 attempts.

#### Example -- exponential backoff

```elixir
result = retry with: exponential_backoff() |> randomize |> expiry(10_000), rescue_only: [TimeoutError] do
  ExternalApi.do_something # fails if other system is down
after
  result -> result
else
  error -> error
end
```

This will try the block, and return the result, as soon as it succeeds. On a timeout error, this example will wait an exponentially increasing amount of time (`exponential_backoff/0`). Each delay will be randomly adjusted to remain within +/-10% of its original value (`randomize/2`). Finally, it will stop retrying after 10 seconds have elapsed (`expiry/2`).

#### Example -- retry annotation

```elixir
use Retry.Annotation

@retry with: constant_backoff(100) |> Stream.take(10)
def some_func(arg) do
  ExternalApi.do_something # fails if other system is down
end
```

This example shows how you can annotate a function to retry every 100 milliseconds and gives up after 10 attempts.

#### Delay streams

The `with:` option of `retry` accepts any `Stream` that yields integers. These integers will be interpreted as the amount of time to delay before retrying a failed operation. When the stream is exhausted `retry` will give up, returning the last value of the block.

##### Example

```elixir
result = retry with: Stream.cycle([500]) do
  ExternalApi.do_something # fails if other system is down
after
  result -> result
else
  error -> error  
end
```

This will retry failures forever, waiting 0.5 seconds between attempts.

`Retry.DelayStreams` provides a set of fully composable helper functions for building useful delay behaviors such as the ones in previous examples. See the `Retry.DelayStreams` module docs for full details and addition behavior not covered here. For convenience these functions are imported by `use Retry` so you can, usually, use them without prefixing them with the module name.

### Waiting

Similar to `retry(with: _, do: _)`, the `wait(delay_stream, do: _, after: _, else: _)` macro provides a way to wait for a block of code to be truthy with a variety of delay and give up behaviors. The execution of a block is considered a failure if it returns `false` or `nil`.

```elixir
wait constant_backoff(100) |> expiry(1_000) do
  we_there_yet?
after
  _ ->
    {:ok, "We have arrived!"}
else
  _ ->
    {:error, "We're still on our way :("}
end
```

This example retries every 100 milliseconds and expires after 1 second.

The `after` block evaluates only when the `do` block returns a truthy value.

On the other hand, the `else` block evaluates only when the `do` block remains falsy after timeout.

Pretty nifty for those pesky asynchronous tests and building more reliable systems in general!
