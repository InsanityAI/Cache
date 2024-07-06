if Debug then Debug.beginFile("Cache") end
OnInit.root("Cache", function(require)
    require "Hook"
    local OVERRIDE_NATIVE_EVENT_RESPONSES = true
    local OVERRIDE_NATIVE_STRUCTURE_FUNCTIONS = true -- true if using Lua-Infused GUI
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

        Cache:set(arguments...: unknown, value: unknown)
            - generic method whose signature depends on instance/getterFunction with the last argument being the value to store in the cache
            - used mostly for hooking to setter natives

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
    local weakMetatable = { __mode = "kv" }
    local argv, argvSize, arg, nextTable, currentTable, finalKey -- temp variables, Note: should clean them after function calls to avoid roundabout desyncs?

    -- No point writing generics since this could in theory be variadic param and variadic result, which doesn't work with generic
    ---@class Cache
    ---@field getterFunc function
    ---@field argN integer
    ---@field keyArgs integer[]?
    ---@field cachedData table
    Cache = {}
    Cache.__index = Cache

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
            cachedData = setmetatable({}, weakMetatable)
        }, Cache)
    end

    -- Fetch cached value or get and cache from getterFunc
    ---@param ... unknown key(s)
    ---@return unknown value(s)
    function Cache:get(...)
        argv = { ... }

        currentTable = self.cachedData
        if self.keyArgs == nil then
            for i = 1, self.argN - 1 do
                arg = argv[i] or NULL
                nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = setmetatable({}, weakMetatable)
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
            end
            finalKey = argv[self.argN] or NULL
        else
            argvSize = #self.keyArgs
            for i = 1, argvSize - 1 do
                arg = argv[self.keyArgs[i]] or NULL
                nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = setmetatable({}, weakMetatable)
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
            end
            finalKey = argv[self.keyArgs[argvSize]] or NULL
        end

        local val = currentTable[finalKey]
        if val == nil then
            val = self.getterFunc(...)
            currentTable[finalKey] = val
        end
        return val
    end

    ---@param ... unknown keys with value at the end
    function Cache:set(...)
        argv = { ... }

        currentTable = self.cachedData
        if self.keyArgs == nil then
            for i = 1, self.argN - 1 do
                arg = argv[i] or NULL
                nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = setmetatable({}, weakMetatable)
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
                currentTable[finalKey] = argv[self.argN]
            end
            finalKey = argv[self.argN] or NULL
        else
            argvSize = #self.keyArgs
            for i = 1, argvSize - 2 do
                arg = argv[self.keyArgs[i]] or NULL
                nextTable = currentTable[arg]
                if nextTable == nil then
                    nextTable = setmetatable({}, weakMetatable)
                    currentTable[arg] = nextTable
                end
                currentTable = nextTable
            end
            finalKey = argv[self.keyArgs[argvSize]] or NULL
            currentTable[finalKey] = argv[argvSize]
        end

    end

    ---must provide a EmmyLua annotation overriding this implementation
    ---@param ... unknown key(s), order must be the same as defined in keyArgs, if not all keys are present, the last key's children will be invalidated and deleted
    function Cache:invalidate(...)
        argv = table.pack(...)

        currentTable = self.cachedData
        for i = 1, self.argN - 1 do
            arg = argv[i] or NULL
            nextTable = currentTable[arg]
            if nextTable == nil then
                return
            end
            currentTable = nextTable
        end
        finalKey = argv[self.argN] or NULL
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

    hijackConversionNative("GetHandleId")
    hijackConversionNative("StringHash")
    hijackConversionNative("FourCC")
    hijackConversionNative("GetLocalizedString")
    hijackConversionNative("GetLocalizedHotkey")
    hijackConversionNative("ParseTags")
    hijackConversionNative("ConvertRace")
    hijackConversionNative("ConvertAllianceType")
    hijackConversionNative("ConvertRacePref")
    hijackConversionNative("ConvertIGameState")
    hijackConversionNative("ConvertFGameState")
    hijackConversionNative("ConvertPlayerState")
    hijackConversionNative("ConvertPlayerScore")
    hijackConversionNative("ConvertPlayerGameResult")
    hijackConversionNative("ConvertUnitState")
    hijackConversionNative("ConvertAIDifficulty")
    hijackConversionNative("ConvertGameEvent")
    hijackConversionNative("ConvertPlayerEvent")
    hijackConversionNative("ConvertPlayerUnitEvent")
    hijackConversionNative("ConvertWidgetEvent")
    hijackConversionNative("ConvertDialogEvent")
    hijackConversionNative("ConvertUnitEvent")
    hijackConversionNative("ConvertLimitOp")
    hijackConversionNative("ConvertUnitType")
    hijackConversionNative("ConvertGameSpeed")
    hijackConversionNative("ConvertPlacement")
    hijackConversionNative("ConvertStartLocPrio")
    hijackConversionNative("ConvertGameDifficulty")
    hijackConversionNative("ConvertGameType")
    hijackConversionNative("ConvertMapFlag")
    hijackConversionNative("ConvertMapVisibility")
    hijackConversionNative("ConvertMapSetting")
    hijackConversionNative("ConvertMapDensity")
    hijackConversionNative("ConvertMapControl")
    hijackConversionNative("ConvertPlayerColor")
    hijackConversionNative("ConvertPlayerSlotState")
    hijackConversionNative("ConvertVolumeGroup")
    hijackConversionNative("ConvertCameraField")
    hijackConversionNative("ConvertBlendMode")
    hijackConversionNative("ConvertRarityControl")
    hijackConversionNative("ConvertTexMapFlags")
    hijackConversionNative("ConvertFogState")
    hijackConversionNative("ConvertEffectType")
    hijackConversionNative("ConvertVersion")
    hijackConversionNative("ConvertItemType")
    hijackConversionNative("ConvertAttackType")
    hijackConversionNative("ConvertDamageType")
    hijackConversionNative("ConvertWeaponType")
    hijackConversionNative("ConvertSoundType")
    hijackConversionNative("ConvertPathingType")
    hijackConversionNative("ConvertMouseButtonType")
    hijackConversionNative("ConvertAnimType")
    hijackConversionNative("ConvertSubAnimType")
    hijackConversionNative("ConvertOriginFrameType")
    hijackConversionNative("ConvertFramePointType")
    hijackConversionNative("ConvertTextAlignType")
    hijackConversionNative("ConvertFrameEventType")
    hijackConversionNative("ConvertOsKeyType")
    hijackConversionNative("ConvertAbilityIntegerField")
    hijackConversionNative("ConvertAbilityRealField")
    hijackConversionNative("ConvertAbilityBooleanField")
    hijackConversionNative("ConvertAbilityStringField")
    hijackConversionNative("ConvertAbilityIntegerLevelField")
    hijackConversionNative("ConvertAbilityRealLevelField")
    hijackConversionNative("ConvertAbilityBooleanLevelField")
    hijackConversionNative("ConvertAbilityStringLevelField")
    hijackConversionNative("ConvertAbilityIntegerLevelArrayField")
    hijackConversionNative("ConvertAbilityRealLevelArrayField")
    hijackConversionNative("ConvertAbilityBooleanLevelArrayField")
    hijackConversionNative("ConvertAbilityStringLevelArrayField")
    hijackConversionNative("ConvertUnitIntegerField")
    hijackConversionNative("ConvertUnitRealField")
    hijackConversionNative("ConvertUnitBooleanField")
    hijackConversionNative("ConvertUnitStringField")
    hijackConversionNative("ConvertUnitWeaponIntegerField")
    hijackConversionNative("ConvertUnitWeaponRealField")
    hijackConversionNative("ConvertUnitWeaponBooleanField")
    hijackConversionNative("ConvertUnitWeaponStringField")
    hijackConversionNative("ConvertItemIntegerField")
    hijackConversionNative("ConvertItemRealField")
    hijackConversionNative("ConvertItemBooleanField")
    hijackConversionNative("ConvertItemStringField")
    hijackConversionNative("ConvertMoveType")
    hijackConversionNative("ConvertTargetFlag")
    hijackConversionNative("ConvertArmorType")
    hijackConversionNative("ConvertHeroAttribute")
    hijackConversionNative("ConvertDefenseType")
    hijackConversionNative("ConvertRegenType")
    hijackConversionNative("ConvertUnitCategory")
    hijackConversionNative("ConvertPathingFlag")

    hijackConversionNative("OrderId")
    hijackConversionNative("OrderId2String")
    hijackConversionNative("UnitId")
    hijackConversionNative("UnitId2String")
    hijackConversionNative("AbilityId")
    hijackConversionNative("AbilityId2String")

    local function hijackConstantGetterNative(nativeName)
        local cache = Cache.create(_G[nativeName], 0)
        Hook.add(nativeName, function()
            return cache:get()
        end)
        return cache
    end

    hijackConstantGetterNative("GetBJMaxPlayers")
    hijackConstantGetterNative("GetBJPlayerNeutralVictim")
    hijackConstantGetterNative("GetBJPlayerNeutralExtra")
    hijackConstantGetterNative("GetBJMaxPlayerSlots")
    hijackConstantGetterNative("GetPlayerNeutralPassive")
    hijackConstantGetterNative("GetPlayerNeutralAggressive")

    -- GetObjectName

    ---@param getterNativeName string
    ---@param ... string setter native names
    local function hijackVariableGetterAndSetterNatives(getterArgCount, getterNativeName, ...)
        local cache = Cache.create(_G[getterNativeName], getterArgCount)
        Hook.add(getterNativeName, function(...)
            return cache:get(...)
        end)
        local size = select("#", ...)
        for i = 1, size do
            Hook[select(i, ...)] = function(self, ...)
                cache:set(...)
                self.next()
            end
        end
        return cache
    end

    hijackVariableGetterAndSetterNatives(0, "GetTeams", "SetTeams")
    hijackVariableGetterAndSetterNatives(0, "GetPlayers", "SetPlayers")
    hijackVariableGetterAndSetterNatives(1, "IsGameTypeSupported", "SetGameTypeSupported")
    hijackVariableGetterAndSetterNatives(1, "IsMapFlagSet", "SetMapFlag")
    hijackVariableGetterAndSetterNatives(0, "GetGamePlacement", "SetGamePlacement")
    hijackVariableGetterAndSetterNatives(0, "GetGameSpeed", "SetGameSpeed")
    hijackVariableGetterAndSetterNatives(0, "GetGameDifficulty", "SetGameDifficulty")
    hijackVariableGetterAndSetterNatives(0, "GetResourceDensity", "SetResourceDensity")
    hijackVariableGetterAndSetterNatives(0, "GetCreatureDensity", "SetCreatureDensity")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerTeam", "SetPlayerTeam")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerColor", "SetPlayerColor")
    hijackVariableGetterAndSetterNatives(3, "GetPlayerTaxRate", "SetPlayerTaxRate")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerController", "SetPlayerController")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")

    hijackVariableGetterAndSetterNatives(1, "TimerGetTimeout", "TimerStart") -- TimerStart's next argument after whichTimer is timeout, so it checks out.

    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")
    hijackVariableGetterAndSetterNatives(1, "GetPlayerName", "SetPlayerName")

---@param whichGroup group
---@param whichUnit unit
---@return boolean
function GroupAddUnit(whichGroup, whichUnit) end	-- (native)

---@param whichGroup group
---@param whichUnit unit
---@return boolean
function GroupRemoveUnit(whichGroup, whichUnit) end	-- (native)

---@param whichGroup group
---@param addGroup group
---@return integer
function BlzGroupAddGroupFast(whichGroup, addGroup) end	-- (native)

---@param whichGroup group
---@param removeGroup group
---@return integer
function BlzGroupRemoveGroupFast(whichGroup, removeGroup) end	-- (native)

---@param whichGroup group
function GroupClear(whichGroup) end	-- (native)

---@param whichGroup group
---@return integer
function BlzGroupGetSize(whichGroup) end	-- (native)

---@param whichGroup group
---@param index integer
---@return unit
function BlzGroupUnitAt(whichGroup, index) end	-- (native)

---@param whichGroup group
---@param unitname string
---@param filter? boolexpr
function GroupEnumUnitsOfType(whichGroup, unitname, filter) end	-- (native)

---@param whichGroup group
---@param whichPlayer player
---@param filter? boolexpr
function GroupEnumUnitsOfPlayer(whichGroup, whichPlayer, filter) end	-- (native)

---@param whichGroup group
---@param unitname string
---@param filter? boolexpr
---@param countLimit integer
function GroupEnumUnitsOfTypeCounted(whichGroup, unitname, filter, countLimit) end	-- (native)

---@param whichGroup group
---@param r rect
---@param filter? boolexpr
function GroupEnumUnitsInRect(whichGroup, r, filter) end	-- (native)

---@param whichGroup group
---@param r rect
---@param filter? boolexpr
---@param countLimit integer
function GroupEnumUnitsInRectCounted(whichGroup, r, filter, countLimit) end	-- (native)

---@param whichGroup group
---@param x number
---@param y number
---@param radius number
---@param filter? boolexpr
function GroupEnumUnitsInRange(whichGroup, x, y, radius, filter) end	-- (native)

---@param whichGroup group
---@param whichLocation location
---@param radius number
---@param filter? boolexpr
function GroupEnumUnitsInRangeOfLoc(whichGroup, whichLocation, radius, filter) end	-- (native)

---@param whichGroup group
---@param x number
---@param y number
---@param radius number
---@param filter? boolexpr
---@param countLimit integer
function GroupEnumUnitsInRangeCounted(whichGroup, x, y, radius, filter, countLimit) end	-- (native)

---@param whichGroup group
---@param whichLocation location
---@param radius number
---@param filter? boolexpr
---@param countLimit integer
function GroupEnumUnitsInRangeOfLocCounted(whichGroup, whichLocation, radius, filter, countLimit) end	-- (native)

---@param whichGroup group
---@param whichPlayer player
---@param filter? boolexpr
function GroupEnumUnitsSelected(whichGroup, whichPlayer, filter) end	-- (native)

---@param whichGroup group
---@param order string
---@return boolean
function GroupImmediateOrder(whichGroup, order) end	-- (native)

---@param whichGroup group
---@param order integer
---@return boolean
function GroupImmediateOrderById(whichGroup, order) end	-- (native)

---@param whichGroup group
---@param order string
---@param x number
---@param y number
---@return boolean
function GroupPointOrder(whichGroup, order, x, y) end	-- (native)

---@param whichGroup group
---@param order string
---@param whichLocation location
---@return boolean
function GroupPointOrderLoc(whichGroup, order, whichLocation) end	-- (native)

---@param whichGroup group
---@param order integer
---@param x number
---@param y number
---@return boolean
function GroupPointOrderById(whichGroup, order, x, y) end	-- (native)

---@param whichGroup group
---@param order integer
---@param whichLocation location
---@return boolean
function GroupPointOrderByIdLoc(whichGroup, order, whichLocation) end	-- (native)

---@param whichGroup group
---@param order string
---@param targetWidget widget
---@return boolean
function GroupTargetOrder(whichGroup, order, targetWidget) end	-- (native)

---@param whichGroup group
---@param order integer
---@param targetWidget widget
---@return boolean
function GroupTargetOrderById(whichGroup, order, targetWidget) end	-- (native)

--  This will be difficult to support with potentially disjoint, cell-based regions
--  as it would involve enumerating all the cells that are covered by a particularregion
--  a better implementation would be a trigger that adds relevant units as they enter
--  and removes them if they leave...
---@param whichGroup group
---@param callback function
function ForGroup(whichGroup, callback) end	-- (native)

---@param whichGroup group
---@return unit
function FirstOfGroup(whichGroup) end	-- (native)


-- ---@param whichStartLoc integer
-- ---@param x number
-- ---@param y number
-- function DefineStartLocation(whichStartLoc, x, y) end	-- (native)

-- ---@param whichStartLoc integer
-- ---@param whichLocation location
-- function DefineStartLocationLoc(whichStartLoc, whichLocation) end	-- (native)

-- ---@param whichStartLoc integer
-- ---@param prioSlotIndex integer
-- ---@param otherStartLocIndex integer
-- ---@param priority startlocprio
-- function SetStartLocPrio(whichStartLoc, prioSlotIndex, otherStartLocIndex, priority) end	-- (native)

-- ---@param whichStartLoc integer
-- ---@param prioSlotIndex integer
-- ---@return integer
-- function GetStartLocPrioSlot(whichStartLoc, prioSlotIndex) end	-- (native)

-- ---@param whichStartLoc integer
-- ---@param prioSlotIndex integer
-- ---@return startlocprio
-- function GetStartLocPrio(whichStartLoc, prioSlotIndex) end	-- (native)

-- ---@param whichStartLoc integer
-- ---@param prioSlotCount integer
-- function SetEnemyStartLocPrioCount(whichStartLoc, prioSlotCount) end	-- (native)

-- ---@param whichStartLoc integer
-- ---@param prioSlotIndex integer
-- ---@param otherStartLocIndex integer
-- ---@param priority startlocprio
-- function SetEnemyStartLocPrio(whichStartLoc, prioSlotIndex, otherStartLocIndex, priority) end	-- (native)



-- ---@param whichStartLocation integer
-- ---@return number
-- function GetStartLocationX(whichStartLocation) end	-- (native)

-- ---@param whichStartLocation integer
-- ---@return number
-- function GetStartLocationY(whichStartLocation) end	-- (native)

-- ---@param whichStartLocation integer
-- ---@return location
-- function GetStartLocationLoc(whichStartLocation) end	-- (native)

-- ---@param whichPlayer player
-- ---@param startLocIndex integer
-- function SetPlayerStartLocation(whichPlayer, startLocIndex) end	-- (native)

-- --  forces player to have the specified start loc and marks the start loc as occupied
-- --  which removes it from consideration for subsequently placed players
-- --  ( i.e. you can use this to put people in a fixed loc and then
-- --    use random placement for any unplaced players etc )
-- ---@param whichPlayer player
-- ---@param startLocIndex integer
-- function ForcePlayerStartLocation(whichPlayer, startLocIndex) end	-- (native)

-- ---@param sourcePlayer player
-- ---@param otherPlayer player
-- ---@param whichAllianceSetting alliancetype
-- ---@param value boolean
-- function SetPlayerAlliance(sourcePlayer, otherPlayer, whichAllianceSetting, value) end	-- (native)

-- ---@param whichPlayer player
-- ---@param whichRacePreference racepreference
-- function SetPlayerRacePreference(whichPlayer, whichRacePreference) end	-- (native)

-- ---@param whichPlayer player
-- ---@param value boolean
-- function SetPlayerRaceSelectable(whichPlayer, value) end	-- (native)


-- ---@param whichPlayer player
-- ---@param flag boolean
-- function SetPlayerOnScoreScreen(whichPlayer, flag) end	-- (native)

-- ---@param whichPlayer player
-- ---@return integer
-- function GetPlayerStartLocation(whichPlayer) end	-- (native)

-- ---@param whichPlayer player
-- ---@return boolean
-- function GetPlayerSelectable(whichPlayer) end	-- (native)

-- ---@param whichPlayer player
-- ---@return playerslotstate
-- function GetPlayerSlotState(whichPlayer) end	-- (native)

-- ---@param whichPlayer player
-- ---@param pref racepreference
-- ---@return boolean
-- function IsPlayerRacePrefSet(whichPlayer, pref) end	-- (native)


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
            Hook[select(i, ...)] = function(self)
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

        hijackNativeEventResponse("GetExpiredTimer")

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
