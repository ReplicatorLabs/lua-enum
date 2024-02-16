-- FIXME: Support other Lua versions.
assert(_VERSION == "Lua 5.4", "Enum: unsupported lua version: " .. tostring(_VERSION))

--[[
Unit test helpers
--]]

local function countTableKeys(value)
  local keys = {}
  for key, _ in pairs(value) do
    table.insert(keys, key)
  end

  return #keys
end

--[[
Symbol
--]]

local symbol_metatable <const> = {}
local symbol_private_data <const> = setmetatable({}, {__mode='k'})

local Symbol <const> = setmetatable({
  create = function (enum, name, value)
    if type(enum) ~= 'table' and not next(enum) then
      error("Symbol enum instance must be an empty table")
    end

    if type(name) ~= 'string' or string.len(name) == 0 then
      error("Symbol name must be a non-empty string")
    end

    -- FIXME: allow tables if we can guarantee they won't be modified?
    local allowed_value_types = {['boolean']=true, ['string']=true, ['number']=true}
    if not allowed_value_types[type(value)] then
      error("Symbol value must be a boolean, string, or number")
    end

    local instance <const> = {}
    local private <const> = {enum=enum, name=name, value=value}
    symbol_private_data[instance] = private

    return setmetatable(instance, {
      __name = 'Symbol',
      __metatable = symbol_metatable,
      __index = function (_, key)
        if key == 'name' or key == 'value' or key == 'enum' then
          return private[key]
        else
          error("Symbol invalid attribute: " .. tostring(key))
        end
      end,
      __newindex = function (_, _, _)
        error("Symbol definition cannot be modified")
      end,
      __eq = function (a, b)
        -- note: implicitly verifies both values are symbol instances since at
        -- least one of them must be for this function to be called
        if getmetatable(a) ~= getmetatable(b) then
          return false
        end

        -- retrieve instance private data
        local pa <const> = assert(symbol_private_data[a], "Symbol instance not recognized: " .. tostring(a))
        local pb <const> = assert(symbol_private_data[b], "Symbol instance not recognized: " .. tostring(b))

        -- must belong to the same enum instance and have the same name
        if pa['enum'] ~= pb['enum'] then
          return false
        end

        -- must have the same name and value
        -- FIXME: implement support for non-unique values
        return (pa['name'] == pb['name'] and pa['value'] == pb['value'])
      end,
      __gc = function (_)
        symbol_private_data[instance] = nil
      end
    })
  end,
  is = function (value)
    return (getmetatable(value) == symbol_metatable)
  end
}, {
  __call = function (module, ...)
    return module.create(...)
  end
})

--[[
Symbol unit tests
--]]

assert(countTableKeys(symbol_private_data) == 0) -- GC

local foo = {}
local test1 = Symbol(foo, 'NAME', 'name')
local test2 = Symbol(foo, 'NAME', 'name')
local test3 = Symbol(foo, 'AGE', 'age')

assert(countTableKeys(symbol_private_data) == 3) -- GC

local test1_string_repr = tostring(test1)
assert(string.find(test1_string_repr, 'Symbol: ') == 1)

assert(Symbol.is(test1))
assert(not Symbol.is({}))
assert(test1.enum == foo)
assert(test1.name == 'NAME')
assert(test1.value == 'name')
assert(test1 == test2)
assert(test1 ~= test3)

test1 = nil
collectgarbage("collect")
assert(countTableKeys(symbol_private_data) == 2) -- GC

test2 = nil
test3 = nil
collectgarbage("collect")
assert(countTableKeys(symbol_private_data) == 0) -- GC

--[[
Enum
--]]

local enum_metatable <const> = {}
local enum_private_data <const> = setmetatable({}, {__mode='k'})

local Enum <const> = setmetatable({
  create = function (symbols)
    if type(symbols) ~= 'table' or not next(symbols) then
      error("Enum symbols must be a non-empty table")
    end

    -- XXX
    local symbols_is_array = true
    local symbols_count = 0
    for key, value in pairs(symbols) do
      symbols_count = symbols_count + 1
      if math.type(key) ~= 'integer' then
        symbols_is_array = false
      end
    end

    if symbols_count ~= #symbols then
      symbols_is_array = false
    end

    -- XXX
    local instance <const> = {}
    local symbols_by_name <const> = {}
    local symbols_by_value <const> = {}

    -- use the array values as symbol names
    if symbols_is_array then
      for _, name in pairs(symbols) do
        local symbol <const> = Symbol(instance, name, name)
        if symbols_by_name[symbol.name] then
          error("Enum symbol name is not unique: " .. tostring(symbol.name))
        end

        symbols_by_name[symbol.name] = symbol
        symbols_by_value[symbol.value] = symbol
      end
    -- use the table entries as (name, value) pairs
    else
      for name, value in pairs(symbols) do
        local symbol <const> = Symbol(instance, name, value)
        if symbols_by_name[symbol.name] then
          error("Enum symbol name is not unique: " .. tostring(symbol.name))
        end

        if symbols_by_value[symbol.value] then
          error("Enum symbol value is not unique: " .. tostring(symbol.value))
        end

        symbols_by_name[symbol.name] = symbol
        symbols_by_value[symbol.value] = symbol
      end
    end

    local private <const> = {symbols_by_name=symbols_by_name, symbols_by_value=symbols_by_value}
    enum_private_data[instance] = private

    -- XXX
    return setmetatable(instance, {
      __name = 'Enum',
      __metatable = enum_metatable,
      __index = function (_, key)
        return symbols_by_name[key]
      end,
      __newindex = function (_, _, _)
        error("Enum definition cannot be modified")
      end,
      __call = function (_, value)
        return symbols_by_value[value]
      end,
      __eq = function (a, b)
        -- note: implicitly verifies both values are symbol instances since at
        -- least one of them must be for this function to be called
        if getmetatable(a) ~= getmetatable(b) then
          return false
        end

        -- retrieve instance private data
        local pa <const> = assert(enum_private_data[a], "Enum instance not recognized: " .. tostring(a))
        local pb <const> = assert(enum_private_data[b], "Enum instance not recognized: " .. tostring(b))

        -- must be the same instance but we compare private data tables to
        -- avoid a stack overflow when comparing instance tables (ex: a == b)
        return (pa == pb)
      end,
      __gc = function (_)
        enum_private_data[instance] = nil
      end
    })
  end,
  is = function (value)
    return (getmetatable(value) == enum_metatable)
  end
}, {
  __call = function (module, ...)
    return module.create(...)
  end
})

--[[
Enum unit tests
--]]

assert(countTableKeys(enum_private_data) == 0) -- GC

local test1 = Enum({'RED', 'GREEN', 'BLUE'})
local test2 = Enum{'RED', 'GREEN', 'BLUE'}
assert(Enum.is(test1))
assert(not Enum.is({}))

assert(test1.RED == Symbol(test1, 'RED', 'RED')) -- FIXME: consider this
-- assert(test1.contains(Symbol(test1, 'RED', 'RED'))) -- FIXME: consider this

local test1_string_repr = tostring(test1)
assert(string.find(test1_string_repr, 'Enum: ') == 1)

assert(test1 == test1)
assert(test1 ~= test2)
assert(test1.RED == test1('RED'))
assert(test1.RED ~= test1.GREEN)
assert(test1.RED ~= test2.RED)
assert(test1.RED.enum == test1)
assert(test1.RED.name == 'RED')
assert(test1.RED.value == 'RED')

test2 = nil
local test2 = Enum{RED='#f00', GREEN='#0f0', BLUE='#00f'}

assert(test1 ~= test2)
assert(test1.RED ~= test2.RED)
assert(test2.RED.name == 'RED')
assert(test2.RED.value == '#f00')
assert(test2.RED == test2('#f00'))

collectgarbage('collect')
assert(countTableKeys(enum_private_data) == 2) -- GC

test1 = nil
test2 = nil
collectgarbage('collect')
assert(countTableKeys(enum_private_data) == 0) -- GC

--[[
Module Interface
--]]

-- check if we're being loaded as a module
-- https://stackoverflow.com/a/49376823
if pcall(debug.getlocal, 4, 1) then
  return {Symbol=Symbol, Enum=Enum}
end

--[[
Command Line Interface
--]]

-- TODO: implement a command line interface?
-- run unit and integration tests? run benchmarks?
print("Hello, world!")
