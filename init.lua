function string:ends_with_char(suffix)
    return self:sub(-#suffix) == suffix
end

function string:is_path()
    local i = self:find("/")
    return self == "." or self == ".." or i and i ~= #self
end

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
    elseif cmd == "remove" then
        local selected = {}

        if #cx.active.selected ~= 0 then
            for _, url in pairs(cx.active.selected) do
                table.insert(selected, tostring(url))
            end
        else
            table.insert(selected, tostring(cx.active.current.hovered.url))
        end

        return {
            kind = cmd,
            value = {
                selected = selected,
            },
        }
    elseif cmd == "rename" and #cx.active.selected == 0 then
        return {
            kind = cmd,
            value = {
                hovered = tostring(cx.active.current.hovered.url),
            },
        }
    else
        return {}
    end
end)

local function sudo_cmd()
    return { "sudo", "-k", "--" }
end

local function list_extend(self, iter)
    for _, value in ipairs(iter) do
        table.insert(self, value)
    end
end

local function execute(command)
    ya.manager_emit("shell", {
        table.concat(command, " "),
        block = true,
        confirm = true,
    })
end

local function sudo_paste(value)
    local args = sudo_cmd()
    if value.is_cut then
        list_extend(args, { "mv", "-f" })
    else
        list_extend(args, { "cp", "-rf" })
    end
    list_extend(args, value.yanked)
    list_extend(args, { "-t", "./" })

    execute(args)
end

local function sudo_link(value)
    local args = sudo_cmd()
    list_extend(args, { "ln", "-s" })
    list_extend(args, value.yanked)
    list_extend(args, { "-t", "./" })
    execute(args)
end

local function sudo_create()
    local name, event = ya.input({
        title = "sudo create:",
        position = { "top-center", y = 2, w = 40 },
    })

    -- Input and confirm
    if event == 1 and not name:is_path() then
        local args = sudo_cmd()
        if name:ends_with_char("/") then
            list_extend(args, { "mkdir", "-p" })
        else
            table.insert(args, "touch")
        end
        table.insert(args, ya.quote(name))

        execute(args)
    end
end

local function sudo_rename(value)
    local new_name, event = ya.input({
        title = "sudo rename:",
        position = { "top-center", y = 2, w = 40 },
    })

    -- Input and confirm
    if event == 1 and not new_name:is_path() then
        local args = sudo_cmd()
        list_extend(args, { "mv", value.hovered, ya.quote(new_name) })
        execute(args)
    end
end

local function sudo_remove(value)
    local args = sudo_cmd()
    if value.is_permanent then
        list_extend(args, { "rm", "-rf" })
    else
        table.insert(args, "cnc")
    end
    list_extend(args, value.selected)

    execute(args)
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
        elseif state.kind == "remove" then
            state.value.is_permanent = args[2] == "-P"
            sudo_remove(state.value)
        elseif state.kind == "rename" then
            sudo_rename(state.value)
        end
    end,
}
