
if not ns
then
    ns = vim.api.nvim_create_namespace('')
end
extid = 0

function get_tree()
    local tree = vim.treesitter.get_parser(bufnr, lang):parse()[1]:root()
    print(tree)
    return tree
end

function capture(str_query)
    local bufnr = vim.api.nvim_get_current_buf()
    local lang = vim.bo.filetype
    local tree = vim.treesitter.get_parser(bufnr, lang):parse()[1]
    local query = vim.treesitter.query.parse(lang, str_query)
    --[[
    -- results structure should be as follows:
    --  {
    --      rows = [...], -- what rows in the file have queries
    --      row# = {
    --          capture_name = {
    --              row1,
    --              row2,
    --              col1,
    --              col2,
    --              type,
    --              text,
    --          },
    --          capture_name = {
    --              ...
    --          },
    --          ...,
    --      },
    --      row# = {
    --          capture_name = {
    --              ...
    --          },
    --          capture_name = {
    --              ...
    --          },
    --          ...,
    --      },
    --      ...,
    --  }
    --]]
    local results = {}

    for id, node, metadata in query:iter_captures(tree:root(), bufnr, 0, -1) do
        -- sort results by the name of the capture
        if results[select(1, node:range())] == nil
        then
            results[select(1, node:range())] = {}
        end

        results[select(1, node:range())][query.captures[id]] = {
            row1 = select(1, node:range()),
            col1 = select(2, node:range()),
            row2 = select(3, node:range()),
            col2 = select(4, node:range()),
            type = node:type(),
            text = vim.treesitter.get_node_text(node, bufnr, nil),
        }

    end

    results['rows'] = {}
    local i = 1

    for k, _ in pairs(results) do
        if k ~= 'rows'
        then
            results['rows'][i] = k
            i = i + 1
        end
    end

    return results
end

-- this only works for python because that's what I'm working with right now
-- I will need to make some generics and a monad class to work with this the
-- way that I want to
function function_details()
    local captures = capture([[
    ((function_definition 
        name: (identifier) @function.name 
        parameters: (parameters) @function.parameters) @function)
    ]])

    return captures
end

function function_headers()
    -- return the function names in a file
    local cap = function_details()
    for _, row in ipairs(cap['rows']) do
        local data = cap[row]
        local text = data['function.name']['text']..data['function.parameters']['text']
        print(text)
    end
end

function hl_funcs()
    -- create custom background highlights for captures
    local bufnr = vim.api.nvim_get_current_buf()
    local cap = function_details()
    local colors = require('gruvbox-baby.colors').config()

    vim.api.nvim_set_hl(ns, "@back_light", {bg = colors.soft_yellow, fg = colors.medium_gray})

    for _, row in ipairs(cap['rows']) do
        local data = cap[row]
        local start = data['function.name']['col1']
        local stop = data['function.parameters']['col2']
        print(
            data['function.name']['row1'],
            data['function.name']['row2'],
            data['function.name']['col1'],
            data['function.name']['col2']
        )
        extid = vim.api.nvim_buf_set_extmark(
            bufnr,
            ns,
            row,
            start,
            {
                end_col=stop,
                hl_group='@back_light',
            }
        )
        print('highlight complete')
    end

    vim.api.nvim_set_hl_ns_fast(ns)
end

function hl_func_del()
    local bufnr = vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_clear_namespace(
        bufnr,
        ns,
        0,
        -1
    )
end
