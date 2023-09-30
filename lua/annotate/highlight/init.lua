local M = {}

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
    print(obj[var].value)
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
    local bufnr = vim.api.nvim_get_current_buf()

    M.create_namespace('annotate')

    id = vim.api.nvim_buf_set_extmark(
            bufnr,
            M.ns.value,
            range.start.row,
            range.start.column,
            {
                end_row=range.stop.row,
                end_col=range.stop.column,
                hl_group='@annotate'
            }
        )

    print(vim.inspect(id))

    M.create_extmark_id(id)
end

M.get_hl_id = function ()
    local bufnr = vim.api.nvim_get_current_buf()
    -- get the cursor position
    local pos = {
        vim.api.nvim_win_get_cursor(0)[1] - 1,
        vim.api.nvim_win_get_cursor(0)[2],
    }

    -- get the first extmark id that comes after the cursor
    id = vim.api.nvim_buf_get_extmarks(
        bufnr,
        M.ns,
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
    if id[4].end_row > pos[1] or (
            id[4].end_row == pos[1] and
            id[4].end_col >= pos[2]
    ) then
            return id
    end

    return nil
end

M.del_hl_id = function (id)
    local bufnr = vim.api.nvim_get_current_buf()

    vim.api.nvim_buf_del_extmark(
        bufnr,
        M.ns,
        id
    )

    M.ext[id] = nil
end

M.del_hl_range = function (range)
    local bufnr = vim.api.nvim_get_current_buf()

    ids = vim.api.nvim_buf_get_extmarks(
        bufnr,
        M.ns,
        range.start,
        range.stop,
        {}
    )

    for _, exm in pairs(ids) do
        M.del_hl_id(exm[1])
    end
end


-- The setup function for the highlight module. Accepts:
--
-- ## Arguments:
--
-- {opts}: (table|nil) optional arguments for setup.
--
-- ## Returns:
--
-- None
M.setup = function (opts)
end

return M
