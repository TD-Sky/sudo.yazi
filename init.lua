local get_state = ya.sync(function(_, cmd)
    if cmd == "paste" or cmd == "link" then
        local yanked = {}
        for _, url in pairs(cx.yanked) do
            table.insert(yanked, tostring(url))
        end

        if #yanked == 0 then
            return {}
        end

        return {
            kind = cmd,
            value = {
                is_cut = cx.yanked.is_cut,
                yanked = yanked,
            },
        }
    elseif cmd == "create" then
        return { kind = cmd }
    else
        return {}
    end
end)

local function list_extend(self, iter)
    for _, value in ipairs(iter) do
        table.insert(self, value)
    end
end

function string:ends_with_char(suffix)
    return self:sub(-#suffix) == suffix
end

local function sudo_execute(command)
    ya.manager_emit("shell", {
        table.concat(command, " "),
        block = true,
        confirm = true,
    })
end

local function sudo_paste(state)
    local args = { "sudo", "-k", "--" }
    if state.is_cut then
        list_extend(args, { "mv", "-f" })
    else
        list_extend(args, { "cp", "-rf" })
    end
    list_extend(args, state.yanked)
    list_extend(args, { "-t", "./" })

    sudo_execute(args)
end

local function sudo_link(state)
    local args = { "sudo", "-k", "--" }
    list_extend(args, { "ln", "-s" })
    list_extend(args, state.yanked)
    list_extend(args, { "-t", "./" })

    sudo_execute(args)
end

local function sudo_create()
    local path, event = ya.input({
        title = "sudo create:",
        position = { "top-center", y = 2, w = 40 },
    })

    -- Input and confirm
    if event == 1 then
        local args = { "sudo", "-k", "--" }
        if path:ends_with_char("/") then
            list_extend(args, { "mkdir", "-p" })
        else
            table.insert(args, "touch")
        end
        table.insert(args, ya.quote(path))

        sudo_execute(args)
    end
end

return {
    entry = function(_, args)
        local state = get_state(args[1])

        if state.kind == "paste" then
            sudo_paste(state.value)
        elseif state.kind == "link" then
            sudo_link(state.value)
        elseif state.kind == "create" then
            sudo_create()
        end
    end,
}
