if Debug then Debug.beginFile("Cache") end
--[[
    Cache v1.0
    Provides a generic multidimensional table for purpose of caching data for future use.

    Requires: Total Initialization - https://www.hiveworkshop.com/threads/total-initialization.317099/

    How to use:
    1. Find data that could be used multiple times and/or data for it requires time or costly resources
     - e.g. Getting a name from an item-type
    2. Define a function that ultimately fetches this information

        e.g.
        ---@param itemId integer
        ---@return string
        function getItemTypeName(itemId)
            local item = CreateItem(itemId, 0.00, 0.00)
            local name = GetItemName(item)
            RemoveItem(item)
            return name
        end
        Note: function takes 1 parameter

    3. Create a new instance of Cache using the previously defined getter function.

        e.g.
        ---@class ItemNameCache: Cache
        ---@field get fun(self: ItemNameCache, itemId: integer): string
        ---@field invalidate fun(self: ItemNameCache, itemId: integer)
        ItemNameCache = Cache.create(getItemTypeName, 1)
        Notes:
         - constant '1' is determined by how many parameters your getter function takes
         - EmmyLua annotations are not required, and are more of a suggestion if you use VSCode tooling for Lua

    4. Use your newly created cache

        e.g.
        local itemTypeName = ItemNameCache:get(itemId)
        itemTypeName = ItemNameCache:get(itemId) -- doesn't call the getter function, just gives the store value
        ItemNameCache:invalidate(itemId) -- causes cache to forget value for this itemId

        itemTypeName = ItemNameCache:get(itemId) -- uses getter function to fetch name again
        local itemTypeName2 = ItemNameCache:get(itemId2)
        ItemNameCache:invalidateAll() -- deletes both itemId's and itemId2's stored names from cache
        itemTypeName = ItemNameCache:get(itemId) -- uses getter function to fetch name again

    API:
        Cache.create(getterFunc: function, argumentNumber: integer, keyArgs...: integer)
            - Create a cache that uses getterFunc, which requires *argumentNumber* of arguments
            - keyArgs are argumentIndexes whose order determines importance to the cache, it affects invalidate() method

        Cache:get(arguments...: unknown) -> unknown
            - generic method whose signature depends on instance/getterFunction
            - either returns previously stored value for argument-combination or calls the getter function with those arguments

        Cache:invalidate(arguments...: unknown)
            - generic method whose signature depends on instance/getterFunction
            - argument order must be defined as it was by keyArgs in constructor
            - forgets all values of that argument-combination
            - not all arguments are required, last argument (of this invocation) will flush all child argument-value pairs
                of this multidimensional table

        Cache:invalidateAll()
            - refreshes entire cache
    Note:
        Calling Cache.create(function(1, 2, 3) does stuff end, 3, 2, 1, 3)
        causes the newly formed cache to construct it's structure as following:
        cachedData = {
            [secondArgument = {
                [firstArgument = {
                    [thirdArgument = value]
                }]
            }]
        }
        then, by calling cache:invalidate(secondArgument, firstArgument)
        will cause the table to clear every value from that [firstArgument = {...}]
        So be mindful about that when creating a cache
        Can also be left without keyArgs for default order as is defined by the function

    PS: I wrote this before I realized there's a GetObjectName that directly fetches the name...
]]
OnInit.module("Cache", function()
    local NULL = {}

    -- No point writing generics since this could in theory be variadic param and variadic result, which doesn't work with generic
    ---@class Cache
    ---@field getterFunc function
    ---@field argN integer
    ---@field keyArgs integer[]|{n: integer}?
    ---@field cachedData table
    Cache = {}
    Cache.__index = Cache

    -- Create a cache with specified getter, but also indices of which arguments of the getterFunc are supposed to be used as keys (order of arguments also matters)
    ---@param getterFunc function
    ---@param getterFuncArgN integer amount of arguments getter func accepts
    ---@param ... integer keyArgs
    ---@return Cache
    function Cache.create(getterFunc, getterFuncArgN, ...)
        local keyArgs = nil
        local keyArgsN = select("#", ...)
        if keyArgsN > 0 then
            keyArgs = { ..., n = keyArgsN }
        end

        return setmetatable({
            getterFunc = getterFunc,
            argN = getterFuncArgN,
            keyArgs = keyArgs,
            cachedData = {}
        }, Cache)
    end

    -- Fetch cached value or get and cache from getterFunc
    ---@param ... unknown key(s)
    ---@return unknown value(s)
    function Cache:get(...)
        local currentTable = self.cachedData
        local finalKey
        if self.keyArgs == nil then
            for i = 1, self.argN - 1 do
                local arg = select(i, ...) or NULL
                local nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = {}
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
            end
            finalKey = select(self.argN, ...) or NULL
        else
            local argvSize = self.keyArgs.n
            for i = 1, argvSize - 1 do
                local arg = select(self.keyArgs[i], ...) or NULL
                local nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = {}
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
            end
            finalKey = select(self.keyArgs[argvSize], ...) or NULL
        end

        local val = currentTable[finalKey]
        if val == nil then
            val = self.getterFunc(...)
            currentTable[finalKey] = val
        end
        return val
    end

    ---must provide a EmmyLua annotation overriding this implementation
    ---@param ... unknown key(s), order must be the same as defined in keyArgs, if not all keys are present, the last key's children will be invalidated and deleted
    function Cache:invalidate(...)
        local currentTable = self.cachedData
        for i = 1, self.argN - 1 do
            local arg = select(i, ...) or NULL
            local nextTable = currentTable[arg]
            if nextTable == nil then
                return
            end
            currentTable = nextTable
        end
        local finalKey = select(self.argN, ...) or NULL
        currentTable[finalKey] = nil
    end

    -- flush entire cache, any new request will call getterFunc
    function Cache:invalidateAll()
        self.cachedData = {}
    end
end)
if Debug then Debug.endFile() end
