--[[
Lua Version Check
--]]

local supported_lua_versions <const> = {['Lua 5.4']=true}
if not supported_lua_versions[_VERSION] then
  warn("lua-enum: detected unsupported lua version: " .. tostring(_VERSION))
end

--[[
Symbol
--]]

local symbol_metatable <const> = {}
local symbol_private <const> = setmetatable({}, {__mode='k'})

-- private constructor
local Symbol_create <const> = function (enum, name, value)
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
  symbol_private[instance] = {enum=enum, name=name, value=value}

  return setmetatable(instance, {
    __name = 'Symbol',
    __metatable = symbol_metatable,
    __index = function (self, key)
      local private <const> = assert(symbol_private[self], "Symbol instance not recognized: " .. tostring(self))
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
      local pa <const> = assert(symbol_private[a], "Symbol instance not recognized: " .. tostring(a))
      local pb <const> = assert(symbol_private[b], "Symbol instance not recognized: " .. tostring(b))

      -- must belong to the same enum instance and have the same name
      if pa['enum'] ~= pb['enum'] then
        return false
      end

      -- must have the same name and value
      -- FIXME: implement support for non-unique values
      return (pa['name'] == pb['name'] and pa['value'] == pb['value'])
    end,
    __gc = function (_)
      symbol_private[instance] = nil
    end
  })
end

-- public interface
local Symbol <const> = {
  is = function (value)
    return (getmetatable(value) == symbol_metatable)
  end
}

--[[
Enum
--]]

local enum_metatable <const> = {}
local enum_private <const> = setmetatable({}, {__mode='k'})
local enum_reserved_keys <const> = {['has']=true}

-- private implementation
local enum_internal_has <const> = function (self, symbol)
  local private <const> = assert(enum_private[self], "Enum instance not recognized: " .. tostring(self))
  assert(Symbol.is(symbol), "symbol parameter must be a Symbol instance")
  return private.symbols_by_name[symbol.name] == symbol
end

local enum_internal_metatable <const> = {
  __name = 'Enum',
  __metatable = enum_metatable,
  __len = function (self)
    local private <const> = assert(enum_private[self], "Enum instance not recognized: " .. tostring(self))

    -- expose symbols as dense array to support ipairs() enumeration
    return #private.symbols
  end,
  __index = function (self, key)
    local private <const> = assert(enum_private[self], "Enum instance not recognized: " .. tostring(self))

    -- export symbols as dense array to support ipairs() enumeration
    if math.type(key) == 'integer' then
      return private.symbols[key]
    -- enum symbol membership test
    elseif key == 'has' then
      return enum_internal_has
    -- export symbols as map with names as keys
    else
      assert(enum_reserved_keys[key] == nil, "failed to handle all reserved keys")
      return private.symbols_by_name[key]
    end
  end,
  __newindex = function (_, _, _)
    error("Enum definition cannot be modified")
  end,
  __pairs = function (self)
    local private <const> = assert(enum_private[self], "Enum instance not recognized: " .. tostring(self))

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
      local value <const> = private.symbols_by_name[name].value
      return name, value -- control value, remaining loop values
    end

    local names <const> = {}
    for name, _ in pairs(private.symbols_by_name) do
      table.insert(names, name)
    end

    -- iterator function, state variable, initial control value, closing variable
    return iterate, names, names[1], nil
  end,
  __call = function (self, value)
    local private <const> = assert(enum_private[self], "Enum instance not recognized: " .. tostring(self))

    -- look up symbols by value
    return private.symbols_by_value[value]
  end,
  __eq = function (a, b)
    -- note: implicitly verifies both values are symbol instances since at
    -- least one of them must be for this function to be called
    if getmetatable(a) ~= getmetatable(b) then
      return false
    end

    -- retrieve instance private data
    local pa <const> = assert(enum_private[a], "Enum instance not recognized: " .. tostring(a))
    local pb <const> = assert(enum_private[b], "Enum instance not recognized: " .. tostring(b))

    -- must be the same instance but we compare private data tables to
    -- avoid a stack overflow when comparing instance tables (ex: a == b)
    return (pa == pb)
  end,
  __gc = function (self)
    enum_private[self] = nil
  end
}

-- public interface
local Enum <const> = setmetatable({
  create = function (symbol_data)
    if type(symbol_data) ~= 'table' or not next(symbol_data) then
      error("Enum symbols must be a non-empty table")
    end

    -- detect if the symbol data is a dense array or a map
    local symbol_data_is_array = true
    local symbol_data_count = 0
    for key, value in pairs(symbol_data) do
      symbol_data_count = symbol_data_count + 1
      if math.type(key) ~= 'integer' then
        symbol_data_is_array = false
      end
    end

    if symbol_data_count ~= #symbol_data then
      symbol_data_is_array = false
    end

    -- create instance here because we need to pass it to symbol instances
    local instance <const> = {}
    local symbols <const> = {}
    local symbols_by_name <const> = {}
    local symbols_by_value <const> = {}

    -- use the symbol data array values as symbol names and values
    if symbol_data_is_array then
      for _, name in ipairs(symbol_data) do
        if enum_reserved_keys[name] then
          error("Enum symbol name conflicts with reserved key: " .. name)
        end

        local symbol <const> = Symbol_create(instance, name, name)
        if symbols_by_name[symbol.name] then
          error("Enum symbol name is not unique: " .. tostring(symbol.name))
        end

        table.insert(symbols, symbol)
        symbols_by_name[symbol.name] = symbol
        symbols_by_value[symbol.value] = symbol
      end
    -- use the symbol data map entries as name and value pairs
    else
      for name, value in pairs(symbol_data) do
        if enum_reserved_keys[name] then
          error("Enum symbol name conflicts with reserved key: " .. name)
        end

        local symbol <const> = Symbol_create(instance, name, value)
        if symbols_by_name[symbol.name] then
          error("Enum symbol name is not unique: " .. tostring(symbol.name))
        end

        if symbols_by_value[symbol.value] then
          error("Enum symbol value is not unique: " .. tostring(symbol.value))
        end

        table.insert(symbols, symbol)
        symbols_by_name[symbol.name] = symbol
        symbols_by_value[symbol.value] = symbol
      end
    end

    enum_private[instance] = {
      symbols=symbols,
      symbols_by_name=symbols_by_name,
      symbols_by_value=symbols_by_value
    }

    return setmetatable(instance, enum_internal_metatable)
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

local module = {Symbol=Symbol, Enum=Enum}

if os.getenv('LUA_ENUM_LEAK_INTERNALS') == 'TRUE' then
  -- leak internal variables and methods in order to unit test them from outside
  -- of this module but at least we can use an obvious environment variable
  -- and issue a warning to prevent someone from relying on this
  warn("lua-enum: LUA_ENUM_LEAK_INTERNALS is set and internals are exported in module")

  -- stating the obvious but these are not part of the public interface
  module['symbol_metatable'] = symbol_metatable
  module['symbol_private'] = symbol_private
  module['Symbol_create'] = Symbol_create
  module['enum_metatable'] = enum_metatable
  module['enum_private'] = enum_private
  module['enum_reserved_keys'] = enum_reserved_keys
end

return module
