---@meta
local basic = require('annotate.utils.basic')
local M = {}

---@enum index_types
M.INDEX_TYPES = {
    none = 0,
    col = 1,
    row = 2,
    row_col = 3,
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

    if not basic.has_value(M.INDEX_TYPES, it) then
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

    if basic.has_key(opts, 'it') then
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

return M
