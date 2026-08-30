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

--- Returns the common parent directory shared by all paths.
--- For a single path, returns its parent directory.
--- Returns an empty string when the list is empty or
--- the paths do not share a directory.
--- @param paths string[]
--- @return string
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
        for _, file in pairs(cx.yanked) do
            table.insert(yanked, tostring(file.url))
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
            for _, file in pairs(cx.active.selected) do
                table.insert(selected, tostring(file.url))
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
                for _, file in pairs(cx.active.selected) do
                    hovered = tostring(file.url)
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
            for _, file in pairs(cx.active.selected) do
                table.insert(selected, tostring(file.url))
            end
            return {
                kind = "bulk_rename",
                value = {
                    selected = selected,
                },
            }
        end
    elseif cmd == "chmod" then
        local selected = {}

        if #cx.active.selected ~= 0 then
            for _, file in pairs(cx.active.selected) do
                table.insert(selected, tostring(file.url))
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

--- Finds the first blocking editor opener.
--- @return string?
local function bulk_rename_editor()
    local rules = rt and rt.opener and rt.opener.edit
    if rules == nil then
        return nil
    end

    for _, opener in pairs(rules:match()) do
        if opener.block then
            return opener.run
        end
    end
end

--- Replaces the only supported opener placeholder: exactly one `%s`.
--- @param command string
--- @return string?
local function prepare_editor_command(command)
    local first, last = command:find("%s", 1, true)
    if first == nil or command:find("%s", last + 1, true) ~= nil then
        return nil
    end
    if (first > 1 and command:sub(first - 1, first - 1) == "%") or command:sub(last + 1, last + 1):match("%d") then
        return nil
    end

    return command:sub(1, first - 1) .. '"$1"' .. command:sub(last + 1)
end

local function remove_bulk_rename_mapping(mapping)
    Command("rm"):arg({ "-f", "--", mapping }):status()
end

local function sudo_bulk_rename(value)
    local selected = value.selected
    local root = common_prefix(selected)

    -- First create the mapping file without starting an interactive process.
    -- Command:arg() passes arguments directly, so these values must not be
    -- shell-quoted with ya.quote().
    local prepare_args = {
        fs,
        "bulk-rename-prepare",
        "--root",
        root,
    }
    extend_list(prepare_args, selected)

    local prepare_output, prepare_err = Command("nu"):arg(prepare_args):output()
    if prepare_err ~= nil or prepare_output == nil or not prepare_output.status.success then
        ya.notify({
            title = "sudo.yazi",
            content = "Failed to prepare bulk-rename mapping.",
            timeout = 1,
            level = "error",
        })
        return
    end
    local rename_buf = prepare_output.stdout:gsub("%s+$", "")
    if rename_buf == "" then
        ya.notify({
            title = "sudo.yazi",
            content = "Failed to get bulk-rename mapping path.",
            timeout = 1,
            level = "error",
        })
        return
    end

    local editor_cmd = bulk_rename_editor() or "${EDITOR:-nvim} %s"
    local editor_script = prepare_editor_command(editor_cmd)
    if editor_script == nil then
        remove_bulk_rename_mapping(rename_buf)
        ya.notify({
            title = "sudo.yazi",
            content = "Bulk-rename editor must contain exactly one %s placeholder.",
            timeout = 3,
            level = "error",
        })
        return
    end

    -- Run the configured blocking editor with the terminal attached. The
    -- mapping path is passed as $1 instead of interpolated into shell source.
    local permit = ui.hide()
    local child, spawn_err = Command("sh")
        :arg({ "-c", editor_script, "sudo.yazi", rename_buf })
        :stdin(Command.INHERIT)
        :stdout(Command.INHERIT)
        :stderr(Command.INHERIT)
        :spawn()

    if child == nil then
        permit:drop()
        remove_bulk_rename_mapping(rename_buf)
        ya.notify({
            title = "sudo.yazi",
            content = "Failed to start bulk-rename editor: " .. tostring(spawn_err),
            timeout = 2,
            level = "error",
        })
        return
    end

    local edit_status, edit_err = child:wait()
    permit:drop()
    if edit_err ~= nil or edit_status == nil or not edit_status.success then
        remove_bulk_rename_mapping(rename_buf)
        ya.notify({
            title = "sudo.yazi",
            content = "Bulk-rename editor exited unsuccessfully.",
            timeout = 2,
            level = "error",
        })
        return
    end

    local do_args = sudo_cmd()
    extend_list(do_args, {
        "nu",
        ya.quote(fs),
        "bulk-rename-do",
        "--root",
        ya.quote(root),
        "--mapping",
        ya.quote(rename_buf),
    })
    extend_iter(do_args, list_map(selected, ya.quote))
    local rename_command = table.concat(do_args, " ")

    -- Remove the mapping even when sudo authentication or the rename command fails.
    -- bulk-rename-do already removes it on success, so `rm -f` is safe.
    execute({
        "sh",
        "-c",
        ya.quote(rename_command .. "; status=$?; rm -f -- " .. ya.quote(rename_buf) .. "; exit $status"),
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
