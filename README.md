# Truly

[![Truly version](https://img.shields.io/hexpm/v/truly.svg)](https://hex.pm/packages/truly)
[![Hex Docs](https://img.shields.io/badge/hex-docs-lightgreen.svg)](https://hexdocs.pm/truly/)
[![Hex Downloads](https://img.shields.io/hexpm/dt/truly)](https://hex.pm/packages/truly)
[![Twitter Follow](https://img.shields.io/twitter/follow/ac_alejos?style=social)](https://twitter.com/ac_alejos)
<!-- BEGIN MODULEDOC -->
Create a truth table to consolidate complex boolean conditional logic.

`Truly` provides a convenient and human-readable way to store complex conditional logic trees.
You can immediately use `Truly.evaluate/2` to evaluate the truth table or pass the truth table
around for repeat use.

You might find this useful for things like feature flags, where depending on the combination
of boolean flags you want different behaviors or paths.

This can also make the design much more self-documented, where the intent behind a large
logic ladder becomes quite clear.

## Installation

The package can be installed
by adding `truly` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:truly, "~> 0.1.0"}
  ]
end
```

## Usage

First, you must `import Truly`. Then you have the
`~TRULY` sigil available.

All column names and result values must be valid (and existing) atoms.

Table cells can only be boolean values.

You must provide an exhaustive truth table, meaning that you provide
each combination of column values.

## Example

```elixir
import Truly
columns = [:flag_a, :flag_b, :flag_c]
categories = [:cat1, :cat2, :cat3]

{:ok, tt} = ~TRULY"""
| flag_a |  flag_b | flag_c   |          |  
|--------|---------|----------|----------|
|   0    |    0    |     0    |   cat1   |
|   0    |    0    |     1    |   cat1   |
|   0    |    1    |     0    |   cat2   |
|   0    |    1    |     1    |   cat1   |
|   1    |    0    |     0    |   cat3   |
|   1    |    0    |     1    |   cat1   |
|   1    |    1    |     0    |   cat2   |
|   1    |    1    |     1    |   cat3   |
"""

Truly.evaluate!(tt,[flag_a: 1, flag_b: 1, flag_c: 1])

flag_a = 0
flag_b = 1
flag_c = 0

Truly.evaluate(tt,binding())
```
<!-- END MODULEDOC -->