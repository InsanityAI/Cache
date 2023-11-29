if Debug then Debug.beginFile "CacheTest" end
OnInit.final("CacheTest", function(require)
    require "ItemNameCache"
    require "ObjectNameCache"

    ---@param name string
    ---@param func function
    ---@param arg unknown
    local function measureRunTime(name, func, arg, count)
        local clock = os.clock
        local start = clock()
        for i = 1, count do
            func(arg)
        end
        return clock() - start
    end

    local function benchmark(name, func, arg, count)
        local t = measureRunTime(name, func, arg, count)
        if t ~= nil then
            print(count .. ' runs of ' .. name .. ' takes ' .. t .. ' sec to complete')
        else
            print(name .. ' failed to execute')
        end
    end

    ---@param itemId integer
    ---@return string
    local function itemNameCacheGet(itemId)
        return ItemNameCache:get(itemId)
    end

    ---@param objectId integer
    ---@return string
    local function objectNameCacheGet(objectId)
        return ObjectNameCache:get(objectId)
    end

    local t = CreateTimer()
    TimerStart(t, 2.00, false, function()
        DestroyTimer(t)

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 1)
        -- benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 1)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 1)

        -- ItemNameCache:invalidateAll();
        -- ObjectNameCache:invalidateAll();

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 10)
        -- benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 10)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 10)

        -- ItemNameCache:invalidateAll();
        -- ObjectNameCache:invalidateAll();

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 100)
        -- benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 100)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 100)

        -- ItemNameCache:invalidateAll();
        -- ObjectNameCache:invalidateAll();

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 1000)
        -- benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 1000)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 1000)


        -- ItemNameCache:invalidateAll();
        -- ObjectNameCache:invalidateAll();

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 10000)
        -- benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 10000)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 10000)

        -- ItemNameCache:invalidateAll();
        -- ObjectNameCache:invalidateAll();

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 100000)
        -- benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 100000)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 100000)

        -- ItemNameCache:invalidateAll();
        -- ObjectNameCache:invalidateAll();

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 1000000)
        -- benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 1000000)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 1000000)

        -- ItemNameCache:invalidateAll();
        -- ObjectNameCache:invalidateAll();

        -- benchmark("GetObjectName", GetObjectName, FourCC('ratc'), 10000000)
        benchmark("ItemNameCache", itemNameCacheGet, FourCC('ratc'), 10000000)
        -- benchmark("ObjectNameCache", objectNameCacheGet, FourCC('ratc'), 10000000)
    end)
end)
if Debug then Debug.endFile() end
