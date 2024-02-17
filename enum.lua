-- FIXME: Support other Lua versions.
assert(_VERSION == "Lua 5.4", "Enum: unsupported lua version: " .. tostring(_VERSION))

--[[
Symbol
--]]

local symbol_metatable <const> = {}
local symbol_private_data <const> = setmetatable({}, {__mode='k'})

local Symbol <const> = setmetatable({
  create = function (enum, name, value)
    if type(enum) ~= 'table' or next(enum) then
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
      for _, name in ipairs(symbols) do
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

    return setmetatable(instance, {
      __name = 'Enum',
      __metatable = enum_metatable,
      __index = function (_, key)
        return symbols_by_name[key]
      end,
      __newindex = function (_, _, _)
        error("Enum definition cannot be modified")
      end,
      __pairs = function (_)
        -- note: lua table iteration is in arbitrary order whereas this always
        -- iterates in the same order which is technically backwards compatible
        -- for loops: https://www.lua.org/manual/5.4/manual.html#3.3.5
        local function iterate(names, name) -- state variable, initial or previous control value
          -- note: not strictly necessary as table.remove({}, 1) and inner[nil]
          -- both return nil so the loop ends on it's own but this is safer
          if #names == 0 then
            return
          end

          local name <const> = table.remove(names, 1)
          local value <const> = symbols_by_name[name].value
          return name, value -- control value, remaining loop values
        end

        local names <const> = {}
        for name, _ in pairs(symbols_by_name) do
          table.insert(names, name)
        end

        -- iterator function, state variable, initial control value, closing variable
        return iterate, names, names[1], nil
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
Module Interface
--]]

-- check if we're being loaded as a module
-- https://stackoverflow.com/a/49376823
if pcall(debug.getlocal, 4, 1) then
  return {Symbol=Symbol, Enum=Enum}
end

--[[
Utilities
--]]

local function countTableKeys(value)
  local keys = {}
  for key, _ in pairs(value) do
    table.insert(keys, key)
  end

  return #keys
end

--[[
Command Line Interface
--]]

local lu <const> = require('luaunit/luaunit')

-- symbol tests
test_symbol = {}

function test_symbol.test_lifecycle()
  collectgarbage('collect')
  local initial_count = countTableKeys(symbol_private_data)

  local symbol = Symbol({}, 'test', 'test')
  lu.assertEquals(countTableKeys(symbol_private_data), initial_count + 1)

  symbol = nil
  collectgarbage('collect')
  lu.assertEquals(countTableKeys(symbol_private_data), initial_count)
end

function test_symbol.test_type_name()
  local symbol <const> = Symbol({}, 'test', 'test')
  local repr <const> = tostring(symbol)

  lu.assertTrue(string.find(repr, 'Symbol: ') == 1)
end

function test_symbol.test_create()
  local enum <const> = {}

  local symbol = Symbol.create(enum, 'explicit', 'create')
  lu.assertEquals(symbol.enum, enum)
  lu.assertEquals(symbol.name, 'explicit')
  lu.assertEquals(symbol.value, 'create')

  local symbol = Symbol(enum, 'shortcut', 'create')
  lu.assertEquals(symbol.enum, enum)
  lu.assertEquals(symbol.name, 'shortcut')
  lu.assertEquals(symbol.value, 'create')

  lu.assertErrorMsgContains(
    "Symbol enum instance must be an empty table",
    Symbol.create,
    {something='not empty'}
  )

  lu.assertErrorMsgContains(
    "Symbol name must be a non-empty string",
    Symbol.create,
    {}
  )

  lu.assertErrorMsgContains(
    "Symbol name must be a non-empty string",
    Symbol.create,
    {},
    ''
  )

  lu.assertErrorMsgContains(
    "Symbol value must be a boolean, string, or number",
    Symbol.create,
    {},
    'name'
  )

  lu.assertErrorMsgContains(
    "Symbol value must be a boolean, string, or number",
    Symbol.create,
    {},
    'name',
    {}
  )
end

function test_symbol.test_equality()
  local enum <const> = {}
  local symbol1 <const> = Symbol(enum, 'name', 'value')
  local symbol2 <const> = Symbol(enum, 'name', 'value')
  local symbol3 <const> = Symbol(enum, 'something', 'else')

  lu.assertTrue(symbol1 == symbol1)
  lu.assertTrue(symbol1 == symbol2)
  lu.assertTrue(symbol1 ~= symbol3)
  lu.assertTrue(symbol2 ~= symbol3)
end

function test_symbol.test_is_instance()
  local symbol <const> = Symbol({}, 'name', 'value')
  lu.assertTrue(Symbol.is(symbol))
  lu.assertFalse(Symbol.is({}))
end

-- enum tests
test_enum = {}

function test_enum.test_lifecycle()
  collectgarbage('collect')
  local initial_count = countTableKeys(enum_private_data)

  local enum = Enum{'RED', 'GREEN', 'BLUE'}
  lu.assertEquals(countTableKeys(enum_private_data), initial_count + 1)

  enum = nil
  collectgarbage('collect')
  lu.assertEquals(countTableKeys(enum_private_data), initial_count)
end

function test_enum.test_type_name()
  local enum <const> = Enum{'RED', 'GREEN', 'BLUE'}
  local repr <const> = tostring(enum)

  lu.assertTrue(string.find(repr, 'Enum: ') == 1)
end

function test_enum.test_create_names()
  local names <const> = {'RED', 'GREEN', 'BLUE'}

  local enum = Enum.create(names)
  for _, name in ipairs(names) do
    local symbol_by_name = enum[name]
    local symbol_by_value = enum(name)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  local enum = Enum(names)
  for _, name in ipairs(names) do
    local symbol_by_name = enum[name]
    local symbol_by_value = enum(name)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  lu.assertErrorMsgContains(
    "Enum symbols must be a non-empty table",
    Enum.create,
    {}
  )

  lu.assertErrorMsgContains(
    "Enum symbol name is not unique: RED",
    Enum.create,
    {'RED', 'RED'}
  )
end

function test_enum.test_create_names_values()
  local names_values <const> = {NAME='name', AGE='age'}

  local enum = Enum.create(names_values)
  for name, value in pairs(names_values) do
    local symbol_by_name = enum[name]
    local symbol_by_value = enum(value)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  local enum = Enum(names_values)
  for name, value in pairs(names_values) do
    local symbol_by_name = enum[name]
    local symbol_by_value = enum(value)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  lu.assertErrorMsgContains(
    "Enum symbols must be a non-empty table",
    Enum.create,
    {}
  )

  lu.assertErrorMsgContains(
    "Enum symbol value is not unique: red",
    Enum.create,
    {RED='red', FOO='red'}
  )
end

function test_enum.test_enumerate_pairs()
  local names_values = {NAME='name', AGE='age'}
  local enum = Enum(names_values)

  for name, value in pairs(enum) do
    lu.assertEquals(names_values[name], value)
    names_values[name] = nil
  end

  lu.assertEquals(countTableKeys(names_values), 0)
end

-- TODO: implement this interface
--[[
function test_enum.test_enumerate_ipairs()
  local names_values = {NAME='name', AGE='age'}
  local enum = Enum(names_values)

  for _, symbol in ipairs(enum) do
    lu.assertEquals(names_values[symbol.name], symbol.value)
    names_values[symbol.name] = nil
  end

  lu.assertEquals(countTableKeys(names_values), 0)
end
--]]

function test_enum.test_equality()
  local enum1 = Enum{'RED', 'GREEN', 'BLUE'}
  local enum2 = Enum{'RED', 'GREEN', 'BLUE'}

  lu.assertTrue(enum1 == enum1)
  lu.assertFalse(enum1 == enum2)
end

function test_enum.test_is_instance()
  local enum <const> = Enum{'RED', 'GREEN'}
  lu.assertTrue(Enum.is(enum))
  lu.assertFalse(Enum.is({}))
end

-- run tests
os.exit(lu.LuaUnit.run())
