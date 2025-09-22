require("lspconfig").lua_ls.setup({
    settings = {
        Lua = {
            ["$schema"] = "https://raw.githubusercontent.com/LuaLS/vscode-lua/master/setting/schema.json",
            runtime = {
                version = "Lua 5.4",
            },
            workspace = {
                library = {
                    vim.fn.expand("~/.config/yazi/plugins/types.yazi/"),
                },
            },
        },
    },
})
