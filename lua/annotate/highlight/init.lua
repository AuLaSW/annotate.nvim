local posit = require('annotate.utils.position')
local M = {}
local test = true
local v_api = vim.api

---Determine if the cursor is between start and stop.
---@param start Position
---@param stop Position
---@param pos Position
---@return boolean
local function position_in_range(start, stop, pos)
    if (
        start.row < pos.row and pos.row < stop.row
    ) or (
        start.row < pos.row and pos.row == stop.row and pos.col <= stop.col
    ) or (
        start.row == pos.row and pos.row == stop.row and pos.col >= start.col and pos.col <= stop.col
    ) or (
        start.row == pos.row and pos.row < stop.row and pos.col >= start.col
    )
    then
        return true
    end

    return false
end

---@alias namespace number
---Generate the namespace only if `M` does not already have a
---namespace attached.
---@param name string?
---@return namespace
local function namespace(name)
    if not name or type(name) ~= "string" then
        name = 'annotate_nvim'
    end

    if not M.ns then
        return v_api.nvim_create_namespace(name)
    end

    return M.ns
end


local DEFAULT_CONFIG = {
    ns = namespace()
}

-- a list of nodes
M.list = {
    node = {
        next = nil,
        value = nil
    },
    add = function(node)
    end,
}

---@alias Highlight {start: Position?, stop: Position?, group: string | '@annotate', id: index_types, bufnr: number?, has_full_position: boolean, is_set: boolean}
--
---@param start Position? a Position Monad for the start of the highlight.
--
---@param stop Position? a Position Monad for the end of the highlight.
--
---@param group string? a string describing the highlight group.
--
---@param id number? extmark id number.
--
---@param bufnr number? the buffer to create the highlight in
--
---@return Highlight
M.wrapHighlight = function(start, stop, group, id, bufnr)
    local T = {
        start = start,
        stop = stop,
        group = group,
        id = id,
        bufnr = bufnr,
        has_full_position = true,
        is_set = true,
    }

    -- TODO[DONE]: double-check this set of checks to make sure it is correct
    if (not start or not start.is_complete) or (not stop or not stop.is_complete) then
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

    if not T.is_set and T.has_full_position then
        T.id = v_api.nvim_buf_set_extmark(
            T.bufnr,
            M.ns,
            T.start.row,
            T.start.col,
            {
                end_row = T.stop.row,
                end_col = T.stop.row,
                hl_group = T.group
            }
        )
    end

    return T
end

---@param hl Highlight
--
---@param transform fun(start: Position, stop: Position, group: string, id: index_types, bufnr: number, opts: table): start: Position?, stop: Position?, group: string?, id: index_types?, bufnr: number?
-- 
---@param opts table
M.bindHighlight = function(hl, transform, opts)
    if not hl.has_full_position then
        return hl
    end

    local start, stop, group, id, bufnr = transform(hl.start, hl.stop, hl.group, hl.id, hl.bufnr, opts)

    return M.wrapHighlight(start, stop, group, id, bufnr)
end

---@param start Position start of highlight
---@param stop Position end of highlight
---@param opts table a table of options
M.set_hl = function(start, stop, opts)
    local vals = {
        bufnr = nil,
        group = nil,
    }

    for k, v in pairs(opts) do
        if vals[k] then
            vals[k] = v
        end
    end

    -- create the highlight in the current buffer
    local hl = M.wrapHighlight(
        start,
        stop,
        vals.group,
        nil,
        vals.bufnr
    )

    -- TODO: create this list
    M.list.add(hl)
end

M.get_hl_at_cursor = function()
    -- get the cursor position
    local cursor = posit.wrapPosition(
        v_api.nvim_win_get_cursor(0)[1],
        v_api.nvim_win_get_cursor(0)[2],
        posit.INDEX_TYPES.row
    )

    local doc_beg = posit.wrapPosition(
        0,
        0,
        posit.INDEX_TYPES.none
    )

    -- this will dynamically change the position type to match the position type
    -- of doc_beg
    cursor = posit.bindPosition(
        cursor,
        -- in-place identity function
---@diagnostic disable-next-line: unused-local
        function (r, c, i, opts)
            return r, c, i
        end,
        {
            it = doc_beg.it
        }
    )

    -- get the first extmark id that comes after the cursor
    local ext = v_api.nvim_buf_get_extmarks(
        0,
        M.ns,
        cursor.range,
        doc_beg.range,
        {
            details = true,
            limit = 1
        }
    )[1]

    local hl_begin = posit.wrapPosition(
        ext[2],
        ext[3],
        posit.INDEX_TYPES.none
    )

    local hl_end = posit.wrapPosition(
        ext[4].end_row,
        ext[4].end_col,
        posit.INDEX_TYPES.col
    )

    local hl = M.wrapHighlight(
        hl_begin,
        hl_end,
        ext[4].hl_group,
        ext[1],
        0
    )

    -- check that the id ends after the cursor
    -- if it is, then return the associated highlight
    if position_in_range(hl_begin, hl_end, cursor) then
        return hl
    end

    -- return an empty highlight
    return M.wrapHighlight()
end

M.del_hl_at_cursor = function ()
    local hl = M.get_hl_at_cursor()

    M.bindHighlight(
        hl,
        function (start, stop, group, id, bufnr, opts)
            v_api.nvim_buf_del_extmark(
                bufnr,
                M.ns,
                id
            )

            return nil, nil, nil, nil, nil
        end,
        {}
    )
end

M.setup = function(config)
    if not config or type(config) ~= "table" then
        config = DEFAULT_CONFIG
    end
    M.ns = config.ns
end

if test then
    M.setup()
    local start = posit.wrapPosition(
        0,
        0,
        posit.INDEX_TYPES.none
    )

    local stop = posit.wrapPosition(
        1,
        0,
        posit.INDEX_TYPES.none
    )

    M.set_hl(
        start,
        stop,
        {}
    )

    M.get_hl_at_cursor()
    print('Creating highlight...')

    M.del_hl_at_cursor()
    print('Deleting highlight...')
end

return M
