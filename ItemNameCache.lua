if Debug then Debug.beginFile("ItemNameCache") end
OnInit.final("ItemNameCache", function(require)
    require "Cache"

    ---@class ItemNameCache: Cache
    ---@field get fun(self: ItemNameCache, itemId: integer): string
    ---@field invalidate fun(self: ItemNameCache, itemId: integer)
    ItemNameCache = Cache.create(
        ---@param itemId integer
        ---@return string
        function(itemId)
            local item = CreateItem(itemId, 0.00, 0.00)
            local name = GetItemName(item)
            RemoveItem(item)
            return name
        end, 1) --[[@as ItemNameCache]]
end)
if Debug then Debug.endFile() end
