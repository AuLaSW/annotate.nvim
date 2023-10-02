local M = {}
local test = true
local v_api = vim.api

local function has_value(tab, val)
    for _, v in ipairs(tab) do
        if val == v then
            return true
        end
    end

    return false
end

local function has_key(tab, key)
    for k, _ in pairs(tab) do
        if val == v then
            return true
        end
    end

    return false
end

--[[
--The monadic structure is as follows:
--  Wrapper Type:
--      The wrapper type is Highlight, which contains information regarding
--      the position of the highlight and the highlight group associated
--      with the highlight.
--  Wrapper
--      The wrapper is wrapHighlight(). Will require the highlight group and
--      the position in order to generate the type, though the two values
--      can be empty.
--  Run Function
--]]

-- takes a start and stop position and returns a position monad type
M.wrapPosition = function(row, col, it)
    local T = {
        row = row,
        col = col,
        range = {
            row,
            col
        },
        -- (1,1), (1,0), (0,1), or (0,0) indexed, as different variations
        it = it,
        is_complete = true,
    }

    if not row or not type(row) == "number" then
        T.row = nil
        T.is_complete = false
    end
    if not col or not type(col) == "number" then
        col = nil
        T.is_complete = false
    end

    if not T.is_complete then
        T.range = nil
    end

    if not it or not has_value({0, 1, 2, 3}, it) then
        it = nil
    end

    return T
end

local function pos_conv(row, col, old_it, new_it)
    local old_to_new_lookup = {
        -- old_it
        [0] = {
            -- new_it
            [0] = function (in_row, in_col) return in_row, in_col end,
            [1] = function (in_row, in_col) return in_row, in_col + 1 end,
            [2] = function (in_row, in_col) return in_row + 1, in_col end,
            [3] = function (in_row, in_col) return in_row + 1, in_col + 1 end,
        },
        -- old_it
        [1] = {
            -- new_it
            [0] = function (in_row, in_col) return in_row, in_col - 1 end,
            [1] = function (in_row, in_col) return in_row, in_col end,
            [2] = function (in_row, in_col) return in_row + 1, in_col - 1 end,
            [3] = function (in_row, in_col) return in_row + 1, in_col end,
        },
        -- old_it
        [2] = {
            -- new_it
            [0] = function (in_row, in_col) return in_row - 1, in_col end,
            [1] = function (in_row, in_col) return in_row - 1, in_col + 1 end,
            [2] = function (in_row, in_col) return in_row, in_col end,
            [3] = function (in_row, in_col) return in_row, in_col + 1 end,
        },
        -- old_it
        [3] = {
            -- new_it
            [0] = function (in_row, in_col) return in_row - 1, in_col - 1 end,
            [1] = function (in_row, in_col) return in_row - 1, in_col end,
            [2] = function (in_row, in_col) return in_row, in_col - 1 end,
            [3] = function (in_row, in_col) return in_row, in_col end,
        },
    }

    local new_row, new_col = old_to_new_lookup[old_it][new_it](row, col)

    return new_row, new_col, new_it
end

M.bindPosition = function(pos, transform, opts)
    if not pos.is_complete then
        return pos
    end

    if has_key(opts, 'it') then
        if pos.it ~= opts.it then
            -- convert the curront position to work with the 
            -- new positional system needed for the transform
            local row, col, it = pos_conv(
                pos.row,
                pos.col,
                pos.it,
                opts.it
            )

            pos = M.wrapPosition(row, col, it)
        end
    end

    local row, col, it = transform(pos.row, pos.col, pos.it, opts)

    return M.wrapPosition(row, col, it)
end


-- @param start: {Position} a Position Monad (created from wrapPosition)
--               for the start of the highlight
--
-- @param stop:  {Position} a Position Monad (created from wrapPosition)
--               for the end of the highlight
--
-- @param group: {string} a string describing the highlight group
M.wrapHighlight = function(start, stop, group, id, bufnr)
    local T = {
        start = start,
        stop = stop,
        group = group,
        id = id,
        bufnr = bufnr,
        has_full_position = true,
        is_set = true
    }

    if not start.is_complete or not stop.is_complete then
        T.has_full_position = false
        T.is_set = false
    end

    if not group or not type(group) == "string" or group == '' then
        T.group = '@annotate'
    end

    if not bufnr or not type(bufnr) == "number" or bufnr <= 0 then
        T.bufnr = v_api.nvim_get_current_buf()
    end

    -- if there is no associated extmark id with the wrapped highlight, then
    -- we need to create the highlight, so we call the bind function and make
    -- sure that the highlight is created.
    if not id or not type(id) == "number" or id <= 0 then
        -- guarantee that the id is nil so we don't pass a junk value to the
        -- bindHighlight() method
        T.id = nil
        T.is_set = false
    end

    return T
end

M.bindHighlight = function(hl, transform, opts)
    if not hl.is_set and hl.has_full_position then
        local id = v_api.nvim_buf_set_extmark(
            hl.bufnr,
            hl.start.row,
            hl.start.col,
            {
                end_row = hl.stop.row,
                end_col = hl.stop.row,
                hl_group = hl.group
            }
        )

        hl = M.wrapHighlight(hl.start, hl.stop, hl.group, id, hl.bufnr)
    end

    if not hl.has_full_position then
        return hl
    end

    local start, stop, group, id, bufnr = transform(hl.start, hl.stop, hl.group, hl.id, hl.bufnr, opts)

    return M.wrapHighlight(start, stop, group, id, bufnr)
end

-- @param obj: table we are testing the existence of
--             var against.
--
-- @param var: string, name of obj parameter we are
--             testing the existence of.
--
-- @param val: callable that returns a value.
--             Callability is optional; if it is not
--             callable, then the value is wrapped
--             in a function automatically.
local existing = function(obj, var, val)
    if not pcall(val) then
        val = function()
            return val
        end
    end

    if not obj[var] or obj[var].empty then
        obj[var] = wrapMaybe(val())
    end
end

-- Create a namespace for the highlight module. Sets the value into M.ns
-- as a Maybe type.
--
-- ## Arguments:
--
-- name: (string) the name for the namespace
--
-- ## Returns:
--
-- Nothing
M.create_namespace = function(name)
    local space = function()
        return v_api.nvim_create_namespace(name)
    end

    existing(M, 'ns', space)
end

-- Create an extmark id for the highlight module. Sets the value into M.ext
-- as a Maybe type.
--
-- ## Arguments:
--
-- id: (number) the number for the extmark
--
-- ## Returns:
--
-- Nothing
M.create_extmark_id = function(id)
    existing(M, 'ext', id)
end


M.set_hl = function(range)
    M.create_namespace('annotate')
    local bufnr = v_api.nvim_get_current_buf()

    local id = v_api.nvim_buf_set_extmark(
        bufnr,
        M.ns.value,
        range.start.row,
        range.start.col,
        {
            end_row = range.stop.row,
            end_col = range.stop.col,
            hl_group = '@annotate'
        }
    )

    M.create_extmark_id(id)
end

M.get_hl_extmarks = function()
    M.create_namespace('annotate')
    local bufnr = v_api.nvim_get_current_buf()
    -- get the cursor position
    local pos = {
        v_api.nvim_win_get_cursor(0)[1] - 1,
        v_api.nvim_win_get_cursor(0)[2],
    }

    -- get the first extmark id that comes after the cursor
    local ext_id = v_api.nvim_buf_get_extmarks(
        bufnr,
        M.ns.value,
        pos,
        { 0, 0 },
        {
            details = true,
            limit = 1
        }
    )[1]

    -- check that the id ends after the cursor
    -- if it is, then return it
    -- otherwise, return nil
    if ext_id[4].end_row > pos[1] or (
            ext_id[4].end_row == pos[1] and
            ext_id[4].end_col >= pos[2]
        ) then
        return ext_id
    end

    return nil
end

M.del_hl_id = function(id)
    local bufnr = v_api.nvim_get_current_buf()

    print(bufnr, M.ns.value, id)
    v_api.nvim_buf_del_extmark(
        bufnr,
        M.ns.value,
        id
    )

    M.ext = nil
end

M.setup = function(opts)
end

if test then
    M.set_hl({
        start = {
            row = 0,
            col = 0
        },
        stop = {
            row = 2,
            col = 0
        }
    })

    local id = M.get_hl_extmarks()
    print(id)

    M.del_hl_id(id[1])
end

return M
