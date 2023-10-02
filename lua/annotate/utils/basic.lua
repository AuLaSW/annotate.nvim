---@meta
local M = {}

---Returns true if the table contains the specified value
---@param tab table
---@param val any
---@return boolean
M.has_value = function (tab, val)
    for _, v in pairs(tab) do
        if val == v then
            return true
        end
    end

    return false
end

---Returns true if the table contains the specified key.
---@param tab table
---@param key any
---@return boolean
M.has_key = function (tab, key)
    for k, _ in pairs(tab) do
        if key == k then
            return true
        end
    end

    return false
end

return M
