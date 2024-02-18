# lua-enum

Lua enumerations.

* Single-file implementation with no third-party dependencies.

## Usage

Load the `enum.lua` file as a module:

```lua
local enum <const> = require('enum')
```

Create and use an enum:

```lua
local State <const> = Enum{RUNNING, STOPPED} -- matching symbol names and values
local Color <const> = Enum{RED='#f00', GREEN='#0f0', BLUE='#00f'} -- different symbol names and values

-- TODO: document the rest
```

## Tests

Make sure you have the submodules available and run the `enum.lua` file as a
script to run the tests:

```
git submodule update --init --recursive
lua ./enum.lua
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
