local M = {}
local test = true

-- @param value: any
local wrapMaybe = function (value)
    local T = {
        value = nil,
        empty = false
    }

    if not value then
        T.empty = true
    else
        T.value = value
        T.empty = false
    end

    return T
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
local existing = function (obj, var, val)
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
M.create_namespace = function (name)
    local space = function()
            return vim.api.nvim_create_namespace(name)
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
M.create_extmark_id = function (id)
    existing(M, 'ext', id)
end


M.set_hl = function(range)
    M.create_namespace('annotate')
    local bufnr = vim.api.nvim_get_current_buf()

    local id = vim.api.nvim_buf_set_extmark(
            bufnr,
            M.ns.value,
            range.start.row,
            range.start.col,
            {
                end_row=range.stop.row,
                end_col=range.stop.col,
                hl_group='@annotate'
            }
        )

    M.create_extmark_id(id)
end

M.get_hl_extmarks = function ()
    M.create_namespace('annotate')
    local bufnr = vim.api.nvim_get_current_buf()
    -- get the cursor position
    local pos = {
        vim.api.nvim_win_get_cursor(0)[1] - 1,
        vim.api.nvim_win_get_cursor(0)[2],
    }

    -- get the first extmark id that comes after the cursor
    local ext_id = vim.api.nvim_buf_get_extmarks(
        bufnr,
        M.ns.value,
        pos,
        {0,0},
        {
            details=true,
            limit=1
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

M.del_hl_id = function (id)
    local bufnr = vim.api.nvim_get_current_buf()

    print(bufnr, M.ns.value, id)
    vim.api.nvim_buf_del_extmark(
        bufnr,
        M.ns.value,
        id
    )

    M.ext = nil
end

M.setup = function (opts)
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
