# ElixirRetry

## Linear retry

```
result = retry 5 in 500 do
  SomeModule.flaky_function # Either raises a transient runtime error or returns error tuple
end
```
The first argument (5) is the number of retries and the second (500) is the period between attempts in milliseconds.

## Exponential backoff

```
result = backoff 1000 do
  SomeModule.return_or_raise_transient_error # Either raises a transient runtime error or returns error tuple
end
```
The argument is the timeout (in milliseconds) before giving up.

## Circuit breaker
Work in progress.
