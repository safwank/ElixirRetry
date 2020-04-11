defmodule Retry.Annotation do
  @moduledoc """
  A @retry annotation that will retry the function according to the retry settings.

  Examples

      use Retry.Annotation

      @retry with: constant_backoff(100) |> Stream.take(10)
      def some_func(arg) do
        # ...
      end

  """

  defmacro __using__(_opts) do
    quote do
      import Retry.DelayStreams
      require Retry
      require Logger

      Module.register_attribute(__MODULE__, :retry_funs, accumulate: true)

      @on_definition {Retry.Annotation, :on_definition}
      @before_compile {Retry.Annotation, :before_compile}
    end
  end

  def on_definition(env, kind, name, args, guards, _body) do
    retry_opts = Module.get_attribute(env.module, :retry) || :no_retry

    unless retry_opts == :no_retry do
      Module.put_attribute(env.module, :retry_funs, %{
        kind: kind,
        name: name,
        args: Enum.map(args, &de_underscore_name/1),
        guards: guards,
        retry_opts: Keyword.update(retry_opts, :with, [], &Enum.to_list/1)
      })

      Module.delete_attribute(env.module, :retry)
    end
  end

  defmacro before_compile(env) do
    retry_funs = Module.get_attribute(env.module, :retry_funs, [])
    Module.delete_attribute(env.module, :retry_funs)

    override_list =
      retry_funs
      |> Enum.map(&gen_override_list/1)
      |> List.flatten()

    overrides =
      quote location: :keep do
        defoverridable unquote(override_list)
      end

    functions =
      Enum.map(retry_funs, fn fun ->
        body = gen_body(fun)
        gen_function(fun, body)
      end)

    [overrides | functions]
  end

  defp gen_override_list(%{name: name, args: args}) do
    no_default_args_length =
      Enum.reduce(args, 0, fn
        {:\\, _, _}, acc -> acc
        _, acc -> acc + 1
      end)

    Enum.map(no_default_args_length..length(args), fn i -> {name, i} end)
  end

  defp gen_function(%{kind: :def, guards: [], name: name, args: args}, body) do
    quote location: :keep do
      def unquote(name)(unquote_splicing(args)) do
        unquote(body)
      end
    end
  end

  defp gen_function(%{kind: :def, guards: guards, name: name, args: args}, body) do
    quote location: :keep do
      def unquote(name)(unquote_splicing(args)) when unquote_splicing(guards) do
        unquote(body)
      end
    end
  end

  defp gen_function(%{kind: :defp, guards: [], name: name, args: args}, body) do
    quote location: :keep do
      defp unquote(name)(unquote_splicing(args)) do
        unquote(body)
      end
    end
  end

  defp gen_function(%{kind: :defp, guards: guards, name: name, args: args}, body) do
    quote location: :keep do
      defp unquote(name)(unquote_splicing(args)) when unquote_splicing(guards) do
        unquote(body)
      end
    end
  end

  defp gen_body(fun) do
    args =
      Enum.map(fun.args, fn
        {:\\, _, [arg_name | _]} -> arg_name
        arg -> arg
      end)

    quote location: :keep do
      Retry.retry unquote(fun.retry_opts) do
        super(unquote_splicing(args))
      after
        result -> result
      else
        error -> error
      end
    end
  end

  defp de_underscore_name({:\\, context, [{name, name_context, name_args} | t]} = arg) do
    case to_string(name) do
      "_" <> real_name ->
        {:\\, context, [{String.to_atom(real_name), name_context, name_args} | t]}

      _ ->
        arg
    end
  end

  defp de_underscore_name({name, context, args} = arg) do
    case to_string(name) do
      "_" <> real_name -> {String.to_atom(real_name), context, args}
      _ -> arg
    end
  end
end
