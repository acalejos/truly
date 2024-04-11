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
    {:truly, "~> 0.1"}
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

## Basic Example

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

## Practical Example

Imagine you're writing the backend for your social media app
called `PitterPatter`. You want to allow users to direct message
each other, but you want to enforce certain rules around this.

You have the following struct representing your `User`:

```elixir
defmodule User do
  defstruct [:dms_open, :locked]
end
```

You want to control when messages are allowed to be sent according to
the sender's `:locked` account status, the receiver's `:dms_open` setting,
as well as if the two are friends.

Different combinations of these result in different behavior.

We can define the truth table, and since the result column
can be any atom, we can directly pass the function that we want
to call:

```elixir
defmodule PitterPatter do
  import Truly

  def are_friends(_user1, _user2), do: Enum.random([true,false]) |> IO.inspect(label: "Are friends?")

  # We must specify these atoms before the truth table since the atoms must exist already
  @flags  [:dms_open, :locked]

  # Have different functions for different behaviors. You could imagine there
  # can be any number of these <= # rows
  def send_message(_sender,_receiver,_message), do: "Message Sent!"
  def deny_message(_sender,_receiver,_message), do: "Sorry, you can't send that message!"


  # Specify our truth table
  # For the sake of simplicity we stick to 3 variables
  # Also notice that you can use `true, false, 1, 0` in the cells
  @tt ~TRULY"""
  | dms_open |  are_friends |  locked  |                   |   
  |----------|--------------|----------|-------------------|
  |     0    |       0      |     0    |    deny_message   |
  |     0    |     false    |     1    |    deny_message   |
  |     0    |       1      |     0    |    send_message   |
  |     0    |       1      |     1    |    deny_message   |
  |     1    |       0      |     0    |    send_message   |
  |     1    |       0      |     1    |    deny_message   |
  |     1    |       true   |     0    |    send_message   |
  |     1    |       1      |     1    |    deny_message   |
  """r # <- Notice the `r` modifier after the table
       # This is effectively like a `!` function, that will
       # unpack the return tuple and raise on error
  def direct_message(sender, receiver, message) do
    table = @tt 
    flags = 
      [
        dms_open: receiver.dms_open, 
        are_friends: are_friends(sender,receiver),
        locked: sender.locked
      ]
    apply(__MODULE__,Truly.evaluate!(table,flags),[sender,receiver,message])
  end
end
```

And just like that, a call to `Truly.evaluate!` performs all of the various checks
needed as well as routes to the appropriate function depending on the state passed in.

Let's see how we would use this Let's set up some `User`s:

```elixir
sender = %User{dms_open: true, locked: false}
receiver = %User{dms_open: true, locked: false}
```

And now you can run `PitterPatter.direct_message`, and you will see that
as the `:are_friends` status changes (since it's determined randomly above),
the result changes according to the rows in the truth table.

```elixir
PitterPatter.direct_message(sender, receiver, "Hey, can you talk?")
```
<!-- END MODULEDOC -->