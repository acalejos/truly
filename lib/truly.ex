defmodule Truly do
  @moduledoc """
  #{File.cwd!() |> Path.join("README.md") |> File.read!() |> then(&Regex.run(~r/.*<!-- BEGIN MODULEDOC -->(?P<body>.*)<!-- END MODULEDOC -->.*/s, &1, capture: :all_but_first)) |> hd()}
  """
  import Bitwise

  @type t :: %Truly{column_heads: keyword(integer()), actions_map: map()}
  defstruct [:column_heads, :actions_map]

  defp to_bit(value) when value in [false, 0, nil], do: 0
  defp to_bit(_value), do: 1

  @spec evaluate(Truly.t(), keyword()) :: {:error, String.t()} | {:ok, atom()}
  @doc """
  Evaluated the truth table with the given bindings.

  The bindings are any keyword list that have the corresponding column names to the
  truth table, so you can manually pass them or pass `binding()` if the variables are
  defined therein.
  """
  def evaluate(%__MODULE__{} = table, bindings) do
    decimal =
      Enum.reduce_while(table.column_heads, 0, fn
        {variable_name, shift}, acc ->
          bound = bindings[variable_name]

          if is_nil(bound) do
            {:halt,
             {:error, "Column `#{inspect(variable_name)}` not found in #{inspect(bindings)}"}}
          else
            {:cont, acc + (to_bit(bound) <<< shift)}
          end
      end)

    case decimal do
      {:error, _reason} ->
        decimal

      _ ->
        result = table.actions_map[decimal]

        if is_nil(result) do
          {:error, "#{inspect(decimal)} not found in #{inspect(Map.keys(table.actions_map))}"}
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
      e in ArgumentError ->
        {:error, e.message}

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
      |> Enum.reverse()
      |> tl()
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
    result =
      find(table_ast, "td")
      |> Enum.with_index()
      |> Enum.reduce_while({%{}, 0}, fn
        {value, idx}, {acc, current} ->
          offset = :math.fmod(idx + 1, length(column_heads) + 1) |> round()

          if offset == 0 && idx != 0 do
            # We're in the last column -- this is the result
            case to_existing_atom(value) do
              {:ok, atom} ->
                acc = Map.put(acc, current, atom)
                {:cont, {acc, 0}}

              {:error, _reason} = e ->
                {:halt, e}
            end
          else
            bit =
              case value do
                v when v in ["true", "1"] ->
                  1

                v when v in ["false", "0"] ->
                  0

                _ ->
                  {:error,
                   "Bad value #{inspect(value)} in truth table -- all values must be in ['true','false','0','1']"}
              end

            case bit do
              {:error, _reason} = e ->
                {:halt, e}

              _ ->
                shift = (ncols - 1 - :math.fmod(idx, ncols + 1)) |> round()
                decimal = bit <<< shift
                {:cont, {acc, current + decimal}}
            end
          end
      end)

    case result do
      {:error, _reason} = e ->
        e

      {actions_map, _} ->
        {:ok, actions_map}
    end
  end

  @spec sigil_TRULY(binary()) :: {:error, String.t()} | {:ok, Truly.t()}
  @doc """
  Creates a new `Truly` struct which stores the truth table. This can later be
  evaluated against a list of bindings to get the truth value.

  ## Modifiers

  * `r` - This is effectively like a `!` function, that will unpack the return tuple and raise on error
  """
  def sigil_TRULY(table, modifiers \\ [])

  def sigil_TRULY(table, []) do
    with {:ok, table_ast} <- get_table_ast(table),
         {:ok, column_heads} <- get_column_heads(table_ast),
         ncols = length(column_heads),
         {:ok, actions_map} <- get_actions_map(table_ast, column_heads, ncols) do
      num_cases = length(Map.keys(actions_map))
      expected_cases = 2 ** ncols

      unless num_cases == expected_cases do
        {:error, "Not enough unique cases. Expected #{expected_cases}, got #{num_cases}"}
      else
        {:ok, struct(__MODULE__, column_heads: column_heads, actions_map: actions_map)}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def sigil_TRULY(table_str, [?r]) do
    case sigil_TRULY(table_str, []) do
      {:ok, table} ->
        table

      {:error, error} ->
        raise error
    end
  end
end
