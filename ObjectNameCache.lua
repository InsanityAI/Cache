if Debug then Debug.beginFile("ObjectNameCache") end
OnInit.final("ObjectNameCache", function(require)
    require "Cache"

    ---@class ObjectNameCache: Cache
    ---@field get fun(self: ObjectNameCache, itemId: integer): string
    ---@field invalidate fun(self: ObjectNameCache, itemId: integer)
    ObjectNameCache = Cache.create(GetObjectName, 1) --[[@as ObjectNameCache]]
end)
if Debug then Debug.endFile() end
