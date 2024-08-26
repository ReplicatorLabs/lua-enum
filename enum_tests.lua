local lu <const> = require('luaunit/luaunit')
local enum <const> = require('enum')

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
Unit Tests
--]]

-- symbol tests
test_symbol = {}

function test_symbol.test_lifecycle()
  collectgarbage('collect')
  local initial_count = countTableKeys(enum.symbol_private)

  local instance = enum.Symbol_create({}, 'test', 'test')
  lu.assertEquals(countTableKeys(enum.symbol_private), initial_count + 1)

  instance = nil
  collectgarbage('collect')
  lu.assertEquals(countTableKeys(enum.symbol_private), initial_count)
end

function test_symbol.test_type_name()
  local instance <const> = enum.Symbol_create({}, 'test', 'test')
  local repr <const> = tostring(instance)

  lu.assertTrue(string.find(repr, 'Symbol: ') == 1)
end

function test_symbol.test_create()
  local dummy_enum <const> = {}
  local symbol <const> = enum.Symbol_create(dummy_enum, 'explicit', 'create')
  lu.assertEquals(symbol.enum, dummy_enum)
  lu.assertEquals(symbol.name, 'explicit')
  lu.assertEquals(symbol.value, 'create')

  lu.assertErrorMsgContains(
    "Symbol enum instance must be an empty table",
    enum.Symbol_create,
    {something='not empty'}
  )

  lu.assertErrorMsgContains(
    "Symbol name must be a non-empty string",
    enum.Symbol_create,
    {}
  )

  lu.assertErrorMsgContains(
    "Symbol name must be a non-empty string",
    enum.Symbol_create,
    {},
    ''
  )

  lu.assertErrorMsgContains(
    "Symbol value must be a boolean, string, or number",
    enum.Symbol_create,
    {},
    'name'
  )

  lu.assertErrorMsgContains(
    "Symbol value must be a boolean, string, or number",
    enum.Symbol_create,
    {},
    'name',
    {}
  )
end

function test_symbol.test_equality()
  local dummy_enum <const> = {}
  local symbol1 <const> = enum.Symbol_create(dummy_enum, 'name', 'value')
  local symbol2 <const> = enum.Symbol_create(dummy_enum, 'name', 'value')
  local symbol3 <const> = enum.Symbol_create(dummy_enum, 'something', 'else')

  lu.assertTrue(symbol1 == symbol1)
  lu.assertTrue(symbol1 == symbol2)
  lu.assertTrue(symbol1 ~= symbol3)
  lu.assertTrue(symbol2 ~= symbol3)
end

function test_symbol.test_is_instance()
  local symbol <const> = enum.Symbol_create({}, 'name', 'value')
  lu.assertTrue(enum.Symbol.is(symbol))
  lu.assertFalse(enum.Symbol.is({}))
end

-- enum tests
test_enum = {}

function test_enum.test_lifecycle()
  collectgarbage('collect')
  local initial_count = countTableKeys(enum.enum_private)

  local instance = enum.Enum{'RED', 'GREEN', 'BLUE'}
  lu.assertEquals(countTableKeys(enum.enum_private), initial_count + 1)

  instance = nil
  collectgarbage('collect')
  lu.assertEquals(countTableKeys(enum.enum_private), initial_count)
end

function test_enum.test_type_name()
  local instance <const> = enum.Enum{'RED', 'GREEN', 'BLUE'}
  local repr <const> = tostring(instance)

  lu.assertTrue(string.find(repr, 'Enum: ') == 1)
end

function test_enum.test_reserved_keys()
  for key, _ in pairs(enum.enum_reserved_keys) do
    lu.assertErrorMsgContains(
      "Enum symbol name conflicts with reserved key: " .. key,
      enum.Enum.create,
      {key}
    )
  end
end

function test_enum.test_create_names()
  local names <const> = {'RED', 'GREEN', 'BLUE'}

  local instance = enum.Enum.create(names)
  lu.assertEquals(#instance, #names)

  for _, name in ipairs(names) do
    local symbol_by_name = instance[name]
    local symbol_by_value = instance(name)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  local instance = enum.Enum(names)
  lu.assertEquals(#instance, #names)

  for _, name in ipairs(names) do
    local symbol_by_name = instance[name]
    local symbol_by_value = instance(name)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  lu.assertErrorMsgContains(
    "Enum symbols must be a non-empty table",
    enum.Enum.create,
    {}
  )

  lu.assertErrorMsgContains(
    "Enum symbol name is not unique: RED",
    enum.Enum.create,
    {'RED', 'RED'}
  )
end

function test_enum.test_create_names_values()
  local names_values <const> = {NAME='name', AGE='age'}

  local instance = enum.Enum.create(names_values)
  lu.assertEquals(countTableKeys(names_values), #instance)

  for name, value in pairs(names_values) do
    local symbol_by_name = instance[name]
    local symbol_by_value = instance(value)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  local instance = enum.Enum(names_values)
  lu.assertEquals(countTableKeys(names_values), #instance)

  for name, value in pairs(names_values) do
    local symbol_by_name = instance[name]
    local symbol_by_value = instance(value)

    lu.assertTrue(symbol_by_name ~= nil)
    lu.assertTrue(symbol_by_value ~= nil)
    lu.assertTrue(symbol_by_name == symbol_by_value)
  end

  lu.assertErrorMsgContains(
    "Enum symbols must be a non-empty table",
    enum.Enum.create,
    {}
  )

  lu.assertErrorMsgContains(
    "Enum symbol value is not unique: red",
    enum.Enum.create,
    {RED='red', FOO='red'}
  )
end

function test_enum.test_enumerate_ipairs()
  local names_values <const> = {NAME='name', AGE='age'}
  local instance <const> = enum.Enum(names_values)
  lu.assertEquals(countTableKeys(names_values), #instance)

  for _, symbol in ipairs(instance) do
    lu.assertEquals(names_values[symbol.name], symbol.value)
    names_values[symbol.name] = nil
  end

  lu.assertEquals(countTableKeys(names_values), 0)
end

function test_enum.test_enumerate_pairs()
  local names_values <const> = {NAME='name', AGE='age'}
  local instance <const> = enum.Enum(names_values)
  lu.assertEquals(countTableKeys(names_values), #instance)

  for name, value in pairs(instance) do
    lu.assertEquals(names_values[name], value)
    names_values[name] = nil
  end

  lu.assertEquals(countTableKeys(names_values), 0)
end

function test_enum.test_equality()
  local instance1 = enum.Enum{'RED', 'GREEN', 'BLUE'}
  local instance2 = enum.Enum{'RED', 'GREEN', 'BLUE'}

  lu.assertTrue(instance1 == instance1)
  lu.assertFalse(instance1 == instance2)
end

function test_enum.test_is_instance()
  local instance <const> = enum.Enum{'RED', 'GREEN'}
  lu.assertTrue(enum.Enum.is(instance))
  lu.assertFalse(enum.Enum.is({}))
end

function test_enum.test_has_symbol()
  local instance1 <const> = enum.Enum{'RED', 'GREEN'}
  local instance2 <const> = enum.Enum{'RED', 'BLUE'}

  lu.assertTrue(instance1:has(instance1('RED')))
  lu.assertTrue(instance1:has(instance1['GREEN']))
  lu.assertFalse(instance1:has(instance2.RED))

  lu.assertTrue(instance2:has(instance2('RED')))
  lu.assertTrue(instance2:has(instance2['BLUE']))
  lu.assertFalse(instance2:has(instance1.RED))
end

--[[
Module Interface
--]]

return {
  test_symbol=test_symbol,
  test_enum=test_enum,
}
