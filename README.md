[![Build Status](https://travis-ci.org/safwank/ElixirRetry.svg?branch=master)](https://travis-ci.org/safwank/ElixirRetry)

# ElixirRetry

## Installation

Add `retry` to your list of dependencies in `mix.exs`:

```elixir
  def deps do
    [{:retry, "~> 0.2.0"}]
  end
```

## Documentation

Check out the [API reference](https://hexdocs.pm/retry/Retry.html) for the latest documentation.

## Features

#### Linear retry

```
result = retry 5 in 500 do
  SomeModule.flaky_function # Either raises a transient runtime error or returns an error tuple
end
```
The first argument (5) is the number of retries and the second (500) is the period between attempts in milliseconds.

#### Exponential backoff

```
result = backoff 1000 do
  SomeModule.flaky_function # Either raises a transient runtime error or returns an error tuple
end
```
The argument is the timeout (in milliseconds) before giving up. `backoff` accepts a optional argument `delay_cap` which is the maximum delay (in milliseconds) between attempts.

#### Circuit breaker
Work in progress.
