local fs = os.getenv("HOME") .. "/.config/yazi/plugins/sudo.yazi/assets/fs.nu"

function string:ends_with_char(suffix)
    return self:sub(-#suffix) == suffix
end

function string:is_path()
    local i = self:find("/")
    return self == "." or self == ".." or i and i ~= #self
end

function string:file_name()
    local file_name = self:match(".*/(.*)")
    if file_name ~= nil then
        return file_name
    else
        return self
    end
end

local function list_map(self, f)
    local i = nil
    return function()
        local v
        i, v = next(self, i)
        if v then
            return f(v)
        else
            return nil
        end
    end
end

local function common_prefix(paths)
    if #paths == 0 then
        return ""
    end
    if #paths == 1 then
        local last_slash = paths[1]:match(".*()/")
        if last_slash then
            return paths[1]:sub(1, last_slash - 1)
        end
        return paths[1]
    end

    local prefix = paths[1]
    for i = 2, #paths do
        local path = paths[i]
        local j = 1
        while j <= #prefix and j <= #path and prefix:sub(j, j) == path:sub(j, j) do
            j = j + 1
        end
        prefix = prefix:sub(1, j - 1)
        if prefix == "" then
            return ""
        end
    end

    local last_slash = prefix:match(".*()/")
    if last_slash then
        return prefix:sub(1, last_slash - 1)
    end
    return ""
end

local get_state = ya.sync(function(_, cmd)
    if cmd == "paste" or cmd == "link" or cmd == "hardlink" then
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
    elseif cmd == "rename" then
        if #cx.active.selected <= 1 then
            local hovered
            if #cx.active.selected == 1 then
                for _, url in pairs(cx.active.selected) do
                    hovered = tostring(url)
                    break
                end
            else
                hovered = tostring(cx.active.current.hovered.url)
            end
            return {
                kind = cmd,
                value = {
                    hovered = hovered,
                },
            }
        else
            local selected = {}
            for _, url in pairs(cx.active.selected) do
                table.insert(selected, tostring(url))
            end

            local editor_cmd = nil
            local oe = rt and rt.opener and rt.opener.edit
            if oe then
                for _, rule in ipairs(oe) do
                    if rule.block then
                        editor_cmd = rule.run
                        break
                    end
                end
            end
            editor_cmd = editor_cmd or "${EDITOR:-vim} %s"

            return {
                kind = "bulk_rename",
                value = {
                    selected = selected,
                    editor_cmd = editor_cmd,
                },
            }
        end
    elseif cmd == "chmod" then
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
    else
        return {}
    end
end)

local function sudo_cmd()
    return { "sudo", "-k", "--" }
end

local function extend_list(self, list)
    for _, value in ipairs(list) do
        table.insert(self, value)
    end
end

local function extend_iter(self, iter)
    for item in iter do
        table.insert(self, item)
    end
end

local function execute(command)
    ya.emit("shell", {
        table.concat(command, " "),
        block = true,
        confirm = true,
    })
end

local function sudo_paste(value)
    local args = sudo_cmd()

    extend_list(args, { "nu", fs })
    if value.is_cut then
        table.insert(args, "mv")
    else
        table.insert(args, "cp")
    end
    if value.force then
        table.insert(args, "--force")
    end
    extend_iter(args, list_map(value.yanked, ya.quote))

    execute(args)
end

local function sudo_link(value)
    local args = sudo_cmd()

    extend_list(args, { "nu", fs, "ln" })
    if value.relative then
        table.insert(args, "--relative")
    end
    extend_iter(args, list_map(value.yanked, ya.quote))

    execute(args)
end

local function sudo_hardlink(value)
    local args = sudo_cmd()

    extend_list(args, { "nu", fs, "hardlink" })
    extend_iter(args, list_map(value.yanked, ya.quote))

    execute(args)
end

local function sudo_create()
    local name, event = ya.input({
        title = "sudo create:",
        pos = { "top-center", y = 2, w = 40 },
    })

    -- Input and confirm
    if event == 1 and not name:is_path() then
        local args = sudo_cmd()

        if name:ends_with_char("/") then
            extend_list(args, { "mkdir", "-p" })
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
        pos = { "top-center", y = 2, w = 40 },
        value = value.hovered:file_name(),
    })

    -- Input and confirm
    if event == 1 and not new_name:is_path() then
        local args = sudo_cmd()
        extend_list(args, { "mv", ya.quote(value.hovered), ya.quote(new_name) })
        execute(args)
    end
end

local function sudo_bulk_rename(value)
    local selected = value.selected
    local root = common_prefix(selected)
    local editor_cmd = value.editor_cmd

    local old_names = {}
    for _, path in ipairs(selected) do
        local rel = root ~= "" and path:sub(#root + 2) or path
        table.insert(old_names, rel)
    end

    local script = {}
    table.insert(script, "TMP=$(mktemp)")
    table.insert(script, 'trap "rm -f $TMP" EXIT')
    table.insert(script, "cat > \"$TMP\" << 'EOF_SUDO_YAZI'")
    for _, name in ipairs(old_names) do
        table.insert(script, name)
    end
    table.insert(script, "EOF_SUDO_YAZI")
    local editor_line = editor_cmd:gsub("%%s", '"$TMP"')
    table.insert(script, editor_line)

    local nu_cmd = sudo_cmd()
    extend_list(nu_cmd, { "nu", fs, "bulk-rename", "--root", root, "--tmp", "$TMP" })
    extend_iter(nu_cmd, list_map(selected, ya.quote))
    table.insert(script, table.concat(nu_cmd, " "))

    ya.emit("shell", {
        table.concat(script, "\n"),
        block = true,
        confirm = true,
    })
end

local function sudo_remove(value)
    local args = sudo_cmd()

    extend_list(args, { "nu", fs, "rm" })
    if value.permanently then
        table.insert(args, "--permanent")
    end
    extend_iter(args, list_map(value.selected, ya.quote))

    execute(args)
end

local function sudo_chmod(value)
    local mode, event = ya.input({
        title = "sudo chmod:",
        pos = { "top-center", y = 2, w = 40 },
    })

    if event == 1 then
        local args = sudo_cmd()
        extend_list(args, { "chmod", mode })
        extend_iter(args, list_map(value.selected, ya.quote))
        execute(args)
    end
end

return {
    entry = function(_, job)
        -- https://github.com/sxyazi/yazi/issues/1553#issuecomment-2309119135
        ya.emit("escape", { visual = true })

        local state = get_state(job.args[1])

        if state.kind == "paste" then
            state.value.force = job.args.force
            sudo_paste(state.value)
        elseif state.kind == "link" then
            state.value.relative = job.args.relative
            sudo_link(state.value)
        elseif state.kind == "hardlink" then
            sudo_hardlink(state.value)
        elseif state.kind == "create" then
            sudo_create()
        elseif state.kind == "remove" then
            state.value.permanently = job.args.permanently
            sudo_remove(state.value)
        elseif state.kind == "rename" then
            sudo_rename(state.value)
        elseif state.kind == "bulk_rename" then
            sudo_bulk_rename(state.value)
        elseif state.kind == "chmod" then
            sudo_chmod(state.value)
        end
    end,
}
