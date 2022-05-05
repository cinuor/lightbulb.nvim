local M = { servers = {} }

M.config = {
    sign = {
        enabled = true,
        priority = 10,
    },
    float = {
        enabled = false,
        text = "💡",
        win_opts = {},
    },
    virtual_text = {
        enabled = false,
        text = "💡",
        hl_mode = "replace",
    },
    status_text = {
        enabled = false,
        text = "💡",
        text_unavailable = "",
    },
    ignore = {},
}

M.special_buffers = {
    ["NvimTree"] = true,
    ["vist"] = true,
    ["lspinfo"] = true,
    ["markdown"] = true,
    ["text"] = true,
    ["Outline"] = true,
    ["alpha"] = true,
    ["packer"] = true,
    ["startuptime"] = true,
}

-- local function check_lsp_active()
--   local active_clients = vim.lsp.get_active_clients()
--   if next(active_clients) == nil then
--     return false, "[lspsaga] No lsp client available"
--   end
--   return true, nil
-- end

local function contains(tbl, val)
    for _, value in ipairs(tbl) do
        if value == val then
            return true
        end
    end

    return false
end

--- Patch for breaking neovim master update to LSP handlers
--- See: https://github.com/neovim/neovim/issues/14090#issuecomment-913198455
local function mk_handler(fn)
    return function(...)
        local config_or_client_id = select(4, ...)
        local is_new = type(config_or_client_id) ~= 'number'
        if is_new then
            fn(...)
        else
            local err = select(1, ...)
            local method = select(2, ...)
            local result = select(3, ...)
            local client_id = select(4, ...)
            local bufnr = select(5, ...)
            local config = select(6, ...)
            fn(err, result, { method = method, client_id = client_id, bufnr = bufnr }, config)
        end
    end
end

local function handler_factory(opts, line, bufnr)
    --- Handler for textDocument/codeAction.
    ---
    --- See lsp-handler for more information.
    ---
    --- @private
    local function code_action_handler(responses)
        -- Check for available code actions from all LSP server responses
        local has_actions = false
        for client_id, resp in ipairs(responses) do
            if resp.result and not opts.ignored_clients[client_id] and not vim.tbl_isempty(resp.result) then
                has_actions = true
                break
            end
        end

        require("luadev").print(tostring(had_actions))

        -- -- No available code actions
        -- if not has_actions then
        --     if opts.sign.enabled then
        --         _update_sign(opts.sign.priority, vim.b.lightbulb_line, nil, bufnr)
        --     end
        --     if opts.virtual_text.enabled then
        --         _update_virtual_text(opts.virtual_text, nil, bufnr)
        --     end
        --     if opts.status_text.enabled then
        --         _update_status_text(opts.status_text.text_unavailable, bufnr)
        --     end
        -- else
        --     if opts.sign.enabled then
        --         _update_sign(opts.sign.priority, vim.b.lightbulb_line, line + 1, bufnr)
        --     end
        --
        --     if opts.float.enabled then
        --         _update_float(opts.float, bufnr)
        --     end
        --
        --     if opts.virtual_text.enabled then
        --         _update_virtual_text(opts.virtual_text, line, bufnr)
        --     end
        --
        --     if opts.status_text.enabled then
        --         _update_status_text(opts.status_text.text, bufnr)
        --     end
        -- end

    end

    return mk_handler(code_action_handler)
end

M.check = function()
    local opts = { ignored_clients = {} }
    local code_action_cap_found = false
    local active_clients = vim.lsp.get_active_clients()
    for _, client in pairs(active_clients) do
        if client then
            if client.supports_method("textDocument/codeAction") then
                if contains(M.config.ignore, client.name) then
                    opts.ignored_clients[client.id] = true
                else
                    code_action_cap_found = true
                end
            end
        end
    end

    local current_file = vim.api.nvim_buf_get_name(0)
    local is_file = vim.loop.fs_stat(current_file) ~= nil

    if not code_action_cap_found or not is_file or M.special_buffers[vim.bo.filetype] then
        return
    end

    -- if M.servers[current_file] == nil then
    --   vim.lsp.for_each_buffer_client(vim.api.nvim_get_current_buf(), function(client)
    --       if M.servers[current_file] then return end
    --       local is_nightly = vim.fn.has("nvim-0.8.0")
    --       local code_action_provider = nil
    --       if is_nightly then
    --         code_action_provider = client.server_capabilities.codeActionProvider
    --       else
    --         code_action_provider = client.resolved_capabilities.code_action
    --       end
    --       if code_action_provider and client.supports_method "code_action"
    --       then
    --         M.servers[current_file] = true
    --       end
    --     end
    --   )
    --
    --   if M.servers[current_file] == nil then
    --     M.servers[current_file] = false
    --   end
    -- end

    -- if M.servers[current_file] == false then
    --   return
    -- end

    local context = { diagnostics = vim.lsp.diagnostic.get_line_diagnostics() }
    local params = vim.lsp.util.make_range_params()
    params.context = context
    local bufnr = vim.api.nvim_get_current_buf()
    vim.lsp.buf_request_all(
        0, 'textDocument/codeAction', params, handler_factory(opts, params.range.start.line, bufnr)
    )

end

M.setup = function(opts)
  opts = opts or {}
  M.config = vim.tbl_deep_extend("force", M.config, opts)
end


return M
