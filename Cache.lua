if Debug then Debug.beginFile("Cache") end
OnInit.root("Cache", function(require)
    require "Hook"
    local OVERRIDE_CONVERSION_NATIVES = true
    local OVERRIDE_NATIVE_EVENT_RESPONSES = true
    local OVERRIDE_NATIVE_STRUCTURE_FUNCTIONS = false -- true if using Lua-Infused GUI
    --[[
    Cache v2.0
    Caches stuff depending on what stuff you want to cache!

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

        Cache:invalidate(arguments: unknown)
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

    local NULL = {}

    -- No point writing generics since this could in theory be variadic param and variadic result, which doesn't work with generic
    ---@class Cache
    ---@field getterFunc function
    ---@field argN integer
    ---@field keyArgs integer[]?
    ---@field cachedData table
    Cache = {}
    Cache.__index = Cache

    local weakTable = { __mode = "kv" }

    -- Create a cache with specified getter, but also indices of which arguments of the getterFunc are supposed to be used as keys (order of arguments also matters)
    ---@param getterFunc function
    ---@param getterFuncArgN integer amount of arguments getter func accepts
    ---@param ... integer keyArgs
    ---@return Cache
    function Cache.create(getterFunc, getterFuncArgN, ...)
        local keyArgs = { ... } ---@type integer[]?
        if #keyArgs == 0 then
            keyArgs = nil
        end
        return setmetatable({
            getterFunc = getterFunc,
            argN = getterFuncArgN,
            keyArgs = keyArgs,
            cachedData = setmetatable({}, weakTable)
        }, Cache)
    end

    ---@param self Cache
    ---@param ... unknown key(s)
    ---@return table finalTable, unknown finalKey
    local function fetchFromCache(self, ...)
        local argv = { ... }

        local currentTable = self.cachedData
        local finalKey
        if self.keyArgs == nil then
            for i = 1, self.argN - 1 do
                local arg = argv[i] or NULL
                local nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = setmetatable({}, weakTable)
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
            end
            finalKey = argv[self.argN] or NULL
        else
            local argvSize = #self.keyArgs
            for i = 1, argvSize - 1 do
                local arg = argv[self.keyArgs[i]] or NULL
                local nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = setmetatable({}, weakTable)
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
            end
            finalKey = argv[self.keyArgs[argvSize]] or NULL
        end

        return currentTable, finalKey
    end

    -- Fetch cached value or get and cache from getterFunc
    ---@param ... unknown key(s)
    ---@return unknown value(s)
    function Cache:get(...)
        local finalTable, finalKey = fetchFromCache(self, ...)
        local val = finalTable[finalKey]
        if val == nil then
            val = self.getterFunc(...)
            finalTable[finalKey] = val
        end
        return val
    end

    ---@param ... unknown key(s)
    ---@return boolean
    function Cache:hasCached(...)
        local finalTable, finalKey = fetchFromCache(self, ...)
        return finalTable[finalKey] ~= nil
    end

    ---must provide a EmmyLua annotation overriding this implementation
    ---@param ... unknown key(s), order must be the same as defined in keyArgs, if not all keys are present, the last key's children will be invalidated and deleted
    function Cache:invalidate(...)
        local argv = table.pack(...)

        local currentTable = self.cachedData
        for i = 1, self.argN - 1 do
            local arg = argv[i] or NULL
            local nextTable = currentTable[arg]
            if nextTable == nil then
                return
            end
            currentTable = nextTable
        end
        local finalKey = argv[self.argN] or NULL
        currentTable[finalKey] = nil
    end

    -- flush entire cache, any new request will call getterFunc
    function Cache:invalidateAll()
        self.cachedData = {}
    end

    -- Cache conversion natives

    local function hijackConversionNative(nativeName)
        local cache = Cache.create(_G[nativeName], 1)
        Hook.add(nativeName, function(arg)
            return cache:get(arg)
        end)
        return cache
    end

    if OVERRIDE_CONVERSION_NATIVES then
        hijackConversionNative("GetHandleId")
        hijackConversionNative("StringHash")
        hijackConversionNative("FourCC")
        hijackConversionNative("GetLocalizedString")
        hijackConversionNative("GetLocalizedHotkey")
        hijackConversionNative("ParseTags")
    end

    -- Cache Native Event-Responses

    ---@param eventResponseGetterFunctionName string
    ---@return Cache
    local function hijackNativeEventResponse(eventResponseGetterFunctionName)
        local cache = Cache.create(_G[eventResponseGetterFunctionName], 1)
        Hook.add(eventResponseGetterFunctionName, function()
            return cache:get(coroutine.running())
        end)

        return cache
    end

    ---@param eventResponseGetterFunctionName string
    ---@param ... string invalidatorFunctionNames
    ---@return Cache
    local function hijackEditableNativeEventResponse(eventResponseGetterFunctionName, ...)
        local cache = hijackNativeEventResponse(eventResponseGetterFunctionName)

        local size = select("#", ...)
        for i = 1, size do
            ---@param self Hook.property
            Hook[select("#", i)] = function(self)
                cache:invalidate(coroutine.running())
                self.next()
            end
        end

        return cache
    end

    if OVERRIDE_NATIVE_EVENT_RESPONSES then
        -- would these work? is coroutine different in ForGroup/ForForce?
        hijackNativeEventResponse("GetFilterUnit")
        hijackNativeEventResponse("GetEnumUnit")
        hijackNativeEventResponse("GetFilterDestructable")
        hijackNativeEventResponse("GetEnumDestructable")
        hijackNativeEventResponse("GetFilterItem")
        hijackNativeEventResponse("GetEnumItem")
        hijackNativeEventResponse("GetFilterPlayer")
        hijackNativeEventResponse("GetEnumPlayer")

        hijackNativeEventResponse("GetTriggeringTrigger")
        hijackNativeEventResponse("GetTriggerEventId")
        hijackNativeEventResponse("GetTriggeringRegion")
        hijackNativeEventResponse("GetEnteringUnit")
        hijackNativeEventResponse("GetLeavingUnit")
        hijackNativeEventResponse("GetTriggeringTrackable")
        hijackNativeEventResponse("GetClickedButton")
        hijackNativeEventResponse("GetClickedDialog")
        hijackNativeEventResponse("GetSaveBasicFilename")
        hijackNativeEventResponse("GetTriggerPlayer")
        hijackNativeEventResponse("GetLevelingUnit")
        hijackNativeEventResponse("GetLearningUnit")
        hijackNativeEventResponse("GetLearnedSkill")
        hijackNativeEventResponse("GetLearnedSkillLevel")
        hijackNativeEventResponse("GetRevivableUnit")
        hijackNativeEventResponse("GetRevivingUnit")
        hijackNativeEventResponse("GetAttacker")
        hijackNativeEventResponse("GetRescuer")
        hijackNativeEventResponse("GetDyingUnit")
        hijackNativeEventResponse("GetKillingUnit")
        hijackNativeEventResponse("GetDecayingUnit")
        hijackNativeEventResponse("GetConstructingStructure")
        hijackNativeEventResponse("GetCancelledStructure")
        hijackNativeEventResponse("GetConstructedStructure")
        hijackNativeEventResponse("GetResearchingUnit")
        hijackNativeEventResponse("GetResearched")
        hijackNativeEventResponse("GetTrainedUnitType")
        hijackNativeEventResponse("GetTrainedUnit")
        hijackNativeEventResponse("GetDetectedUnit")
        hijackNativeEventResponse("GetSummoningUnit")
        hijackNativeEventResponse("GetSummonedUnit")
        hijackNativeEventResponse("GetTransportUnit")
        hijackNativeEventResponse("GetLoadedUnit")
        hijackNativeEventResponse("GetSellingUnit")
        hijackNativeEventResponse("GetSoldUnit")
        hijackNativeEventResponse("GetBuyingUnit")
        hijackNativeEventResponse("GetSoldItem")
        hijackNativeEventResponse("GetChangingUnit")
        hijackNativeEventResponse("GetChangingUnitPrevOwner")
        hijackNativeEventResponse("GetManipulatingUnit")
        hijackNativeEventResponse("GetManipulatedItem")
        hijackNativeEventResponse("BlzGetAbsorbingItem")
        hijackNativeEventResponse("BlzGetManipulatedItemWasAbsorbed")
        hijackNativeEventResponse("BlzGetStackingItemSource")
        hijackNativeEventResponse("BlzGetStackingItemTarget")
        hijackNativeEventResponse("BlzGetStackingItemTargetPreviousCharges")
        hijackNativeEventResponse("GetOrderedUnit")
        hijackNativeEventResponse("GetIssuedOrderId")
        hijackNativeEventResponse("GetOrderPointX")
        hijackNativeEventResponse("GetOrderPointY")
        hijackNativeEventResponse("GetOrderTarget")
        hijackNativeEventResponse("GetOrderTargetDestructable")
        hijackNativeEventResponse("GetOrderTargetItem")
        hijackNativeEventResponse("GetOrderTargetUnit")
        hijackNativeEventResponse("GetSpellAbilityUnit")
        hijackNativeEventResponse("GetSpellAbilityId")
        hijackNativeEventResponse("GetSpellAbility")
        hijackNativeEventResponse("GetSpellTargetX")
        hijackNativeEventResponse("GetSpellTargetY")
        hijackNativeEventResponse("GetSpellTargetDestructable")
        hijackNativeEventResponse("GetSpellTargetItem")
        hijackNativeEventResponse("GetSpellTargetUnit")
        hijackNativeEventResponse("GetEventPlayerState")
        hijackNativeEventResponse("GetEventPlayerChatString")
        hijackNativeEventResponse("GetEventPlayerChatStringMatched")
        hijackNativeEventResponse("GetTriggerUnit")
        hijackNativeEventResponse("GetEventUnitState")
        hijackNativeEventResponse("GetEventDamageSource")
        hijackNativeEventResponse("GetEventDetectingPlayer")
        hijackNativeEventResponse("GetEventTargetUnit")
        hijackNativeEventResponse("GetTriggerWidget")
        hijackNativeEventResponse("BlzGetEventDamageTarget")
        hijackEditableNativeEventResponse("GetEventDamage", "BlzSetEventDamage")
        hijackEditableNativeEventResponse("BlzGetEventAttackType", "BlzSetEventAttackType")
        hijackEditableNativeEventResponse("BlzGetEventDamageType", "BlzSetEventDamageType")
        hijackEditableNativeEventResponse("BlzGetEventWeaponType", "BlzSetEventWeaponType")
        hijackNativeEventResponse("BlzGetEventIsAttack")
        hijackNativeEventResponse("BlzGetTriggerFrame")
        hijackNativeEventResponse("BlzGetTriggerFrameEvent")
        hijackNativeEventResponse("BlzGetTriggerFrameValue")
        hijackNativeEventResponse("BlzGetTriggerPlayerKey")
        hijackNativeEventResponse("BlzGetTriggerPlayerMetaKey")
        hijackNativeEventResponse("BlzGetTriggerPlayerIsKeyDown")
        hijackNativeEventResponse("BlzGetTriggerPlayerMouseX")
        hijackNativeEventResponse("BlzGetTriggerPlayerMouseY")
        if OVERRIDE_NATIVE_STRUCTURE_FUNCTIONS then
            hijackNativeEventResponse("BlzGetTriggerPlayerMousePosition")
            hijackNativeEventResponse("GetOrderPointLoc")
            hijackNativeEventResponse("GetSpellTargetLoc")
            hijackNativeEventResponse("BlzGetTriggerPlayerMousePosition")
        end
    end
end)
if Debug then Debug.endFile() end
