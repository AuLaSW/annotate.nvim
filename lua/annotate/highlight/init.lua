local M = {}
local test = true
local v_api = vim.api

local function has_value(tab, val)
    for _, v in pairs(tab) do
        if val == v then
            return true
        end
    end

    return false
end

local function has_key(tab, key)
    for k, _ in pairs(tab) do
        if key == k then
            return true
        end
    end

    return false
end

---Determine if the cursor is between start and stop.
---@param start Position
---@param stop Position
---@param cursor Position
---@return boolean
local function cursor_in_range(start, stop, cursor)
    if (
        start.row < cursor.row and cursor.row < stop.row
    ) or (
        start.row < cursor.row and cursor.row == stop.row and cursor.col <= stop.col
    ) or (
        start.row == cursor.row and cursor.row == stop.row and cursor.col >= start.col and cursor.col <= stop.col
    ) or (
        start.row == cursor.row and cursor.row < stop.row and cursor.col >= start.col
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

---@enum index_types
M.INDEX_TYPES = {
    none = 0,
    col = 1,
    row = 2,
    row_col = 3,
}

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

---@alias Position { row: number?, col: number?, range: { row: number, col: number }?, it: index_types, is_complete: boolean? }

---@param row number? row number
---@param col number? column number
---@param it index_types? number specifying index type
---@return Position
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

    if not row or type(row) ~= "number" then
        T.row = nil
        T.is_complete = false
    end
    if not col or type(col) ~= "number" then
        T.col = nil
        T.is_complete = false
    end

    if not T.is_complete then
        T.range = nil
    end

    if not has_value(M.INDEX_TYPES, it) then
        T.it = nil
    end

    return T
end

---@param row number row number
---@param col number column number
---@param old_it index_types current index type of Position object
---@param new_it index_types new index type of Position object
---@return number new row number
---@return number new column number
---@return index_types new index type
local function pos_conv(row, col, old_it, new_it)
    local old_to_new_lookup = {
        -- old_it
        [M.INDEX_TYPES.none] = {
            -- new_it
            [M.INDEX_TYPES.none] = function (in_row, in_col) return in_row, in_col end,
            [M.INDEX_TYPES.col] = function (in_row, in_col) return in_row, in_col + 1 end,
            [M.INDEX_TYPES.row] = function (in_row, in_col) return in_row + 1, in_col end,
            [M.INDEX_TYPES.row_col] = function (in_row, in_col) return in_row + 1, in_col + 1 end,
        },
        -- old_it
        [M.INDEX_TYPES.col] = {
            -- new_it
            [M.INDEX_TYPES.none] = function (in_row, in_col) return in_row, in_col - 1 end,
            [M.INDEX_TYPES.col] = function (in_row, in_col) return in_row, in_col end,
            [M.INDEX_TYPES.row] = function (in_row, in_col) return in_row + 1, in_col - 1 end,
            [M.INDEX_TYPES.row_col] = function (in_row, in_col) return in_row + 1, in_col end,
        },
        -- old_it
        [M.INDEX_TYPES.row] = {
            -- new_it
            [M.INDEX_TYPES.none] = function (in_row, in_col) return in_row - 1, in_col end,
            [M.INDEX_TYPES.col] = function (in_row, in_col) return in_row - 1, in_col + 1 end,
            [M.INDEX_TYPES.row] = function (in_row, in_col) return in_row, in_col end,
            [M.INDEX_TYPES.row_col] = function (in_row, in_col) return in_row, in_col + 1 end,
        },
        -- old_it
        [M.INDEX_TYPES.row_col] = {
            -- new_it
            [M.INDEX_TYPES.none] = function (in_row, in_col) return in_row - 1, in_col - 1 end,
            [M.INDEX_TYPES.col] = function (in_row, in_col) return in_row - 1, in_col end,
            [M.INDEX_TYPES.row] = function (in_row, in_col) return in_row, in_col - 1 end,
            [M.INDEX_TYPES.row_col] = function (in_row, in_col) return in_row, in_col end,
        },
    }

    local new_row, new_col = old_to_new_lookup[old_it][new_it](row, col)

    return new_row, new_col, new_it
end

---Binds a `transform` to a `Position` object and runs the transform. If the position
---object does not meet certain standards (is not complete), then the transform
---is not run and the object is returned. The `bindPosition()` function can 
---automatically handle changing between different row-column index types so long
---as the new index type is described in the `opts` table as `it`, e.g.:
---`
---opts = {
---   ...,
---   it = INDEX_TYPES.none,
---   ...,
---}
---`
---@param pos Position
---@param transform fun(pos: number, col: number, it: index_types, opts: table): pos: number, col: number, it: index_types
---@param opts table
---@return Position
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
    local cursor = M.wrapPosition(
        v_api.nvim_win_get_cursor(0)[1],
        v_api.nvim_win_get_cursor(0)[2],
        M.INDEX_TYPES.row
    )

    local doc_beg = M.wrapPosition(
        0,
        0,
        M.INDEX_TYPES.none
    )

    -- this will dynamically change the position type to match the position type
    -- of doc_beg
    cursor = M.bindPosition(
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

    local hl_begin = M.wrapPosition(
        ext[2],
        ext[3],
        M.INDEX_TYPES.none
    )

    local hl_end = M.wrapPosition(
        ext[4].end_row,
        ext[4].end_col,
        M.INDEX_TYPES.col
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
    if cursor_in_range(hl_begin, hl_end, cursor) then
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
    local start = M.wrapPosition(
        0,
        0,
        M.INDEX_TYPES.none
    )

    local stop = M.wrapPosition(
        1,
        0,
        M.INDEX_TYPES.none
    )

    M.set_hl(
        start,
        stop,
        {}
    )

    M.get_hl_at_cursor()

    M.del_hl_at_cursor()
end

return M
