local M = {}

---@alias Node {value: any?, next: Node?}

---Wrap any value into a `Node` for a linked list.
---@param value any?
---@param opts table?
---@return Node
M.wrap_node = function(value, opts)
    local T = {
        value = value,
        next = nil,
        is_empty = false,
    }

    if not value then
        T.value = nil
    end

    if opts then
        if opts.next then
            T.next = opts.next
        end
    end

    if not T.value and not T.next then
        T.is_empty = true
    end

    return T
end

---@alias LinkedList table

---Wrap a node into a linked list.
---@param head Node?
---@param tail Node?
---@param cursor Node?
---@param opts table?
---@return LinkedList
M.wrap_linked_list = function (head, tail, cursor, opts)
    local T = {
        -- remember where the head is
        head = head,
        -- remember where the tail is
        tail = tail,
        -- cursor, which keeps track of where we are in the list
        cursor = cursor
    }

    if not head then
        T.head = M.wrap_node()
    end

    if not tail then
        T.tail = T.head.next or T.head or nil
    end

    if not cursor then
        T.cursor = T.head
    end

    return T
end

M.bind_linked_list = function (list, transform, opts)
    local head, tail, cursor = transform(list.head, list.tail, list.cursor, opts)

    return M.wrap_linked_list(
        head,
        tail,
        cursor
    )
end

---Add a node onto an existing linked list
---@param head Node
---@param tail Node
---@param cursor Node
---@param opts table
---@return Node
---@return Node
---@return Node
M.list_funcs.add_node = function (head, tail, cursor, opts)
    if not opts or not opts.next then
        return head, tail, cursor
    end

    tail.next = opts.next

    return head, tail, cursor
end

M.list_funcs.remove_node = function (head, tail, cursor, opts)
    if cursor.next == nil then
        return head, tail, cursor
    end

    cursor.next = cursor.next.next

    return head, tail, cursor
end

M.list_funcs.advance = function (head, tail, cursor, opts)
    local count = opts.count or 1

    if not opts or count < 1 then
        return head, tail, cursor
    end

    local i = 0

    while i < count and cursor.next ~= nil do
        cursor = cursor.next
        i = i + 1
    end

    return head, tail, cursor
end

---A relatively fast method for rewinding a linked list a specified number of
---steps.
---@param head Node
---@param tail Node
---@param cursor Node
---@param opts table
---@return Node
---@return Node
---@return Node
M.list_func.rewind = function (head, tail, cursor, opts)
    local cursor_left, cursor_right = head, head
    local count = opts.count or 1

    local i = 0

    while i < count and cursor_right ~= cursor do
        cursor_right = cursor_right.next
    end

    if cursor_right == cursor then
        return head, tail, head
    end

    -- on the off chance that the cursor is somehow changed to not be a node
    -- in the list, we don't want this to loop forever. Checking against nil
    -- will help prevent that.
    while cursor_right ~= cursor and cursor_right ~= nil do
        cursor_right = cursor_right.next
        cursor_left = cursor_left.next
    end

    return head, tail, cursor_left
end
