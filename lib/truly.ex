defmodule Truly do
  @moduledoc """
  #{File.cwd!() |> Path.join("README.md") |> File.read!() |> then(&Regex.run(~r/.*<!-- BEGIN MODULEDOC -->(?P<body>.*)<!-- END MODULEDOC -->.*/s, &1, capture: :all_but_first)) |> hd()}
  """
  @type t :: %Truly{header: [atom()], body: map()}
  defstruct [:body, :header]

  @spec evaluate(Truly.t(), keyword()) :: {:error, String.t()} | {:ok, atom()}
  @doc """
  Evaluated the truth table with the given bindings.

  The bindings are any keyword list that have the corresponding column names to the
  truth table, so you can manually pass them or pass `binding()` if the variables are
  defined therein.

  ## Options

  Instead of passing the bindings directly, you can use the following options:

  * `:from_env` - Convenience to directly access the column names from the appropriate environment.
      Can be `:system` or `appname` to get from the corresponding application environment
  * `:in_livebook` - Convenenience option to prepend `LB_` for system env variables
  """
  def evaluate(%__MODULE__{} = table, bindings) do
    row =
      Enum.reduce_while(table.header, [], fn
        {column_name, _members}, acc ->
          bound =
            case bindings[:from_env] do
              nil ->
                bindings[column_name]

              :system ->
                System.fetch_env!(
                  ~s(#{if bindings[:in_livebook], do: "LB_", else: ""}#{column_name |> Atom.to_string()})
                )

              app ->
                Application.get_env(app, column_name)
            end

          if is_nil(bound) do
            {:halt,
             {:error, "Column `#{inspect(column_name)}` not found in #{inspect(bindings)}"}}
          else
            {:cont, [{column_name, bound} | acc]}
          end
      end)

    case row do
      {:error, _reason} ->
        row

      _ ->
        row = Enum.into(row, %{})
        result = table.body[row]

        if is_nil(result) do
          {:error, "#{inspect(row)} not found in #{inspect(Map.keys(table.body))}"}
        else
          {:ok, result}
        end
    end
  end

  @spec evaluate!(Truly.t(), keyword()) :: atom()
  @doc """
  Same as `evaluate/2` but raises on error
  """
  def evaluate!(%__MODULE__{} = table, bindings) do
    case evaluate(table, bindings) do
      {:ok, result} ->
        result

      {:error, reason} ->
        raise reason
    end
  end

  defp get_table_ast(table_str) do
    case Earmark.Parser.as_ast(table_str, gfm_tables: true) do
      {:ok, table_ast, _errors} ->
        table_ast =
          Macro.prewalk(table_ast, fn
            {n, a, c, _} ->
              {n, a, c}

            other ->
              other
          end)

        {:ok, table_ast}

      _ ->
        {:error, "Failed to parse table"}
    end
  end

  defp to_existing_atom(str) do
    try do
      {:ok, String.to_existing_atom(str)}
    rescue
      _ in ArgumentError ->
        {:error, "#{inspect(str)} is not an existing atom"}

      _e ->
        {:error, "Unknown Error ocurred in `String.to_existing_atom/1`"}
    end
  end

  defp find(ast, value) do
    {_ast, acc} =
      Macro.prewalk(ast, [], fn
        {tag, _attrs, children} = node, acc ->
          if tag == value do
            {node, [children | acc]}
          else
            {node, acc}
          end

        node, acc ->
          {node, acc}
      end)

    acc
    |> Enum.reverse()
    |> Enum.map(fn
      [] ->
        nil

      [v] ->
        v
    end)
  end

  defp get_column_heads(table_ast) do
    result =
      find(table_ast, "th")
      |> Enum.slice(0..-2)
      |> Enum.with_index()
      |> Enum.reduce_while([], fn
        {column, idx}, acc ->
          case to_existing_atom(column) do
            {:ok, atom} ->
              {:cont, [{atom, idx} | acc]}

            {:error, _reason} = e ->
              {:halt, e}
          end
      end)

    case result do
      {:error, _reason} = e ->
        e

      _ ->
        {:ok, result}
    end
  end

  defp get_actions_map(table_ast, column_heads, ncols) do
    inverse_column_heads = Enum.into(column_heads, %{}, fn {k, v} -> {v, k} end)

    column_unique_values = Enum.into(column_heads, %{}, fn {k, _v} -> {k, MapSet.new()} end)

    result =
      find(table_ast, "td")
      |> Enum.with_index()
      |> Enum.reduce_while({%{}, [], column_unique_values}, fn
        {value, idx}, {acc, current, cuv} ->
          offset = :math.fmod(idx, ncols + 1) |> round()

          if offset == ncols do
            # We're in the last column -- this is the result
            case value do
              "error" <> message ->
                message =
                  message
                  |> String.split(",")
                  |> Enum.at(-1)
                  |> String.trim()

                current = Enum.into(current, %{})
                acc = Map.put(acc, current, {:error, message})
                {:cont, {acc, [], cuv}}

              _ ->
                case to_existing_atom(value) do
                  {:ok, atom} ->
                    current = Enum.into(current, %{})
                    acc = Map.put(acc, current, atom)
                    {:cont, {acc, [], cuv}}

                  {:error, _reason} = e ->
                    {:halt, e}
                end
            end
          else
            case to_existing_atom(value) do
              {:ok, atom} ->
                column = inverse_column_heads[offset]
                set = Map.get(cuv, column) |> MapSet.put(atom)
                {:cont, {acc, [{column, atom} | current], Map.put(cuv, column, set)}}

              {:error, _reason} = e ->
                {:halt, e}
            end
          end
      end)

    case result do
      {:error, _reason} = e ->
        e

      {actions_map, _, cuv} ->
        {:ok, actions_map, cuv}
    end
  end

  @spec sigil_TRULY(binary()) :: {:error, String.t()} | {:ok, Truly.t()}
  @doc """
  Creates a new `Truly` struct which stores the truth table. This can later be
  evaluated against a list of bindings to get the truth value.

  All cells (header, body, result column) can consist of any existing atom.

  Result columns can also optionally consist of an `error, message` string,
  where `error` is the literal word `error` and `message` refers to an associated
  error message.

  ## Modifiers

  * `r` - This is effectively like a `!` function, that will unpack the return tuple and raise on error
  * `s`  Skip validation -- when this modifier is present, we will not check that the truth table is exhaustive (accounts for each possible combination based on present values).
  """
  def sigil_TRULY(table, modifiers \\ []) do
    result =
      with {:ok, table_ast} <- get_table_ast(table),
           {:ok, column_heads} <- get_column_heads(table_ast),
           ncols = length(column_heads),
           {:ok, actions_map, column_unique_values} <-
             get_actions_map(table_ast, column_heads, ncols) do
        if ?s in modifiers do
          num_cases = length(Map.keys(actions_map))

          expected_cases =
            Enum.reduce(column_unique_values, 1, fn
              {_name, set}, acc ->
                acc * Enum.count(set)
            end)

          unless num_cases == expected_cases do
            {:error, "Not enough unique cases. Expected #{expected_cases}, got #{num_cases}"}
          else
            {:ok, struct(__MODULE__, header: column_unique_values, body: actions_map)}
          end
        else
          {:ok, struct(__MODULE__, header: column_unique_values, body: actions_map)}
        end
      else
        {:error, reason} -> {:error, reason}
      end

    if ?r in modifiers do
      case result do
        {:ok, table} ->
          table

        {:error, error} ->
          raise error
      end
    else
      result
    end
  end
end
