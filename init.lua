local get_state = ya.sync(function()
    local yanked = {}
    for _, url in pairs(cx.yanked) do
        table.insert(yanked, tostring(url))
    end
    return {
        cwd = tostring(cx.active.current.cwd),
        is_cut = cx.yanked.is_cut,
        yanked = yanked,
    }
end)

local function list_extend(self, iter)
    for _, value in pairs(iter) do
        table.insert(self, value)
    end
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
    list_extend(args, { "-t", state.cwd })

    sudo_execute(args)
end

local function sudo_link(state)
    local args = { "sudo", "-k", "--" }
    list_extend(args, { "ln", "-s" })
    list_extend(args, state.yanked)
    list_extend(args, { "-t", state.cwd })

    sudo_execute(args)
end

return {
    entry = function(_, args)
        local cmd = args[1]
        local state = get_state()

        if #state.yanked == 0 then
            return
        end

        if cmd == "paste" then
            sudo_paste(state)
        elseif cmd == "link" then
            sudo_link(state)
        end
    end,
}
