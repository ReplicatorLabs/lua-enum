# lua-enum

Lua enumerations.

* Single-file implementation with no third-party dependencies.

## Usage

Load the `enum.lua` file as a module:

```lua
local enum <const> = require('enum')
```

Create and use enums with matching symbol names and values:

```lua
local State <const> = Enum{RUNNING, STOPPED}
assert(enum.Enum.is(State))
assert(enum.Symbol.is(State.RUNNING))
assert(State.RUNNING.name == 'RUNNING')
assert(State.RUNNING.value == 'RUNNING')
assert(State.RUNNING.enum == State)
```

Create and use enums with separate symbol names and values:

```lua
local Color <const> = Enum{RED='#f00', GREEN='#0f0', BLUE='#00f'}
assert(Color.RED.name == 'RED')
assert(Color.RED.value == '#f00')

local symbol_by_name <const> = Color['RED']
local symbol_by_value <const> = Color('#f00')
assert(symbol_by_name == symbol_by_value)
```

See the unit tests for more exhaustive examples.

## Tests

Make sure you have the submodules available and run the `enum.lua` file as a
script to run the tests:

```
git submodule update --init --recursive
lua ./enum.lua -v
```

## Roadmap

Planned:

* [x] Lua 5.4 support.
  * [ ] Integration testing.

Open to consideration:

* [ ] LuaJIT support.
  * [ ] Integration testing.
* [ ] Lua 5.3 support.
  * [ ] Integration testing.
* [ ] Lua 5.2 support.
  * [ ] Integration testing.
* [ ] Lua 5.1 support.
  * [ ] Integration testing.
* [ ] Support for enumerations with non-unique values.
* [ ] Support for enumerations with table values.

## References

* [LuaUnit](https://luaunit.readthedocs.io/en/latest/)
