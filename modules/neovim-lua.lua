-- ============================================================================
-- Essential Settings
-- ============================================================================

vim.opt.number = true
vim.opt.relativenumber = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.undofile = true
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.ignorecase = true
vim.opt.smartcase = true
vim.opt.termguicolors = true
vim.opt.cursorline = true
vim.opt.clipboard = "unnamedplus"
vim.opt.updatetime = 500
vim.opt.mouse = ""
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

-- Leader stays Neovim default (\). Do not set vim.g.mapleader.

-- ============================================================================
-- Colorscheme (after termguicolors)
-- ============================================================================

require("nord").setup({})
vim.cmd.colorscheme("nord")

vim.keymap.set("n", "<leader>h", "<cmd>nohlsearch<cr>", { desc = "Clear search highlights" })

-- ============================================================================
-- Treesitter (nixpkgs 26.05 ships the main-branch rewrite)
-- Parsers come from nvim-treesitter.withPlugins. setup({ highlight = ... })
-- is a no-op on main; highlighting is vim.treesitter.start().
-- ============================================================================

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("joe.treesitter", { clear = true }),
	callback = function(ev)
		local ok = pcall(vim.treesitter.start, ev.buf)
		if ok then
			vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
		end
	end,
})

-- ============================================================================
-- LSP (nvim-lspconfig plugin on rtp supplies lsp/*.lua; do not require it)
-- Per-server on_attach would replace stock commands (pyright/clangd).
-- Root detection: leave stock root_markers; a string root_dir is frozen
-- at config-load time and would pin every buffer to startup cwd.
-- ============================================================================

vim.lsp.config("*", {
	capabilities = require("blink.cmp").get_lsp_capabilities(),
})

vim.lsp.config("pyright", {
	settings = {
		pyright = {
			disableOrganizeImports = true, -- ruff owns imports
		},
		python = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				diagnosticMode = "openFilesOnly",
				typeCheckingMode = "basic",
			},
		},
	},
})

-- Stock bashls filetypes are sh/bash only.
vim.lsp.config("bashls", {
	filetypes = { "sh", "bash", "zsh" },
})

vim.lsp.config("gopls", {
	settings = {
		gopls = {
			analyses = {
				unusedparams = true,
				shadow = true,
			},
			staticcheck = true,
			gofumpt = true,
			usePlaceholders = true,
			completeUnimported = true,
		},
	},
})

do
	local nixd = {
		formatting = { command = { "nixfmt" } },
	}
	local flake = vim.g.joe_dotfiles_flake
	local hm = vim.g.joe_hm_config
	if type(flake) == "string" and flake ~= "" and type(hm) == "string" and hm ~= "" then
		nixd.options = {
			["home-manager"] = {
				expr = string.format('(builtins.getFlake "path:%s").homeConfigurations["%s"].options', flake, hm),
			},
		}
	end
	vim.lsp.config("nixd", { settings = { nixd = nixd } })
end

-- Neovim Lua recipe. Skip if the workspace already has a .luarc.json.
vim.lsp.config("lua_ls", {
	on_init = function(client)
		if client.workspace_folders then
			local path = client.workspace_folders[1].name
			if
				path ~= vim.fn.stdpath("config")
				and (vim.uv.fs_stat(path .. "/.luarc.json") or vim.uv.fs_stat(path .. "/.luarc.jsonc"))
			then
				return
			end
		end
		client.config.settings.Lua = vim.tbl_deep_extend("force", client.config.settings.Lua or {}, {
			runtime = {
				version = "LuaJIT",
				path = { "lua/?.lua", "lua/?/init.lua" },
			},
			workspace = {
				checkThirdParty = false,
				library = { vim.env.VIMRUNTIME },
			},
		})
	end,
})

vim.lsp.config("jsonls", {
	settings = {
		json = {
			schemas = require("schemastore").json.schemas(),
			validate = { enable = true },
		},
	},
})

-- Official Docker LSP covers Dockerfile + Compose. Compose files need this ft.
-- buf_ls also serves Buf config files; those are not detected automatically.
vim.filetype.add({
	extension = {
		tf = "terraform",
		tfvars = "terraform",
		hcl = "hcl",
		tfstate = "json",
	},
	filename = {
		[".terraformrc"] = "hcl",
		["terraform.rc"] = "hcl",
		["docker-compose.yml"] = "yaml.docker-compose",
		["docker-compose.yaml"] = "yaml.docker-compose",
		["compose.yml"] = "yaml.docker-compose",
		["compose.yaml"] = "yaml.docker-compose",
		["buf.yaml"] = "buf-config",
		["buf.gen.yaml"] = "buf-config",
		["buf.policy.yaml"] = "buf-config",
		["buf.lock"] = "buf-config",
	},
	pattern = {
		[".*docker%-compose.*%.ya?ml"] = "yaml.docker-compose",
		[".*%.tfstate%.backup"] = "json",
	},
})
vim.treesitter.language.register("yaml", "buf-config")
vim.treesitter.language.register("yaml", "yaml.helm-values")

-- helm_ls uses yamlls for values.yaml completion; binary is on extraPackages.
vim.lsp.config("helm_ls", {
	settings = {
		["helm-ls"] = {
			yamlls = {
				path = "yaml-language-server",
			},
		},
	},
})

vim.lsp.config("clangd", {
	cmd = { "clangd", "--background-index", "--clang-tidy", "--completion-style=detailed" },
})

vim.lsp.config("jdtls", {
	settings = {
		java = {
			configuration = {
				runtimes = vim.env.JAVA_HOME and {
					{ name = "JavaSE-21", path = vim.env.JAVA_HOME },
				} or {},
			},
		},
	},
})

-- SchemaStore is enabled by default; only extras that are not in the catalog.
-- Do not map JSON/TOML files onto yamlls.
-- Drop yaml.docker-compose / yaml.helm-values: docker_language_server and
-- helm_ls (which already embeds yamlls) own those filetypes.
vim.lsp.config("yamlls", {
	filetypes = { "yaml", "yaml.gitlab" },
	settings = {
		yaml = {
			schemaStore = { enable = true },
			schemas = {
				["https://raw.githubusercontent.com/derailed/k9s/master/internal/config/json/schemas/k9s.json"] = "k9s*.yaml",
				["https://raw.githubusercontent.com/rancher/k3d/main/pkg/config/config.versions.schema.json"] = "k3d*.yaml",
				["https://raw.githubusercontent.com/ray-project/ray/master/python/ray/autoscaler/ray-schema.json"] = "ray*.yaml",
			},
			validate = true,
			hover = true,
			completion = true,
		},
	},
})

-- Rust: rustaceanvim filetype plugin. Do not vim.lsp.enable('rust_analyzer').
vim.lsp.enable({
	"pyright",
	"ruff",
	"bashls",
	"docker_language_server",
	"gopls",
	"terraformls",
	"tflint",
	"ts_ls",
	"nixd",
	"lua_ls",
	"jsonls",
	"taplo",
	"clangd",
	"jdtls",
	"yamlls",
	"helm_ls",
	"fish_lsp",
	"buf_ls",
	"marksman",
})

-- Defaults already provide K, gra/grn/grr/gri/grt/grx, gO, [d ]d, <C-w>d, i_CTRL-S.
-- Do not map `gr` — it prefixes the gr* family. Do not rebind [d ]d (deprecated
-- goto_prev/goto_next; Neovim maps them to vim.diagnostic.jump).
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("joe.lsp", { clear = true }),
	callback = function(ev)
		local client = assert(vim.lsp.get_client_by_id(ev.data.client_id))
		local opts = { buffer = ev.buf, silent = true }

		vim.keymap.set("n", "gd", vim.lsp.buf.definition, opts)
		vim.keymap.set("n", "gD", vim.lsp.buf.declaration, opts)

		-- ruff + pyright: pyright hover/types, ruff lint/format. Disable ruff hover.
		if client.name == "ruff" then
			client.server_capabilities.hoverProvider = false
		end

		if client:supports_method("textDocument/inlayHint") then
			vim.lsp.inlay_hint.enable(true, { bufnr = ev.buf })
		end

		if client:supports_method("textDocument/documentHighlight") then
			local hl = vim.api.nvim_create_augroup("joe.lsp.hl." .. ev.buf, { clear = true })
			vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
				group = hl,
				buffer = ev.buf,
				callback = vim.lsp.buf.document_highlight,
			})
			vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
				group = hl,
				buffer = ev.buf,
				callback = vim.lsp.buf.clear_references,
			})
		end
	end,
})

vim.diagnostic.config({
	virtual_text = {
		prefix = "●",
		spacing = 4,
		severity = {
			min = vim.diagnostic.severity.HINT,
		},
	},
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "󰅚 ",
			[vim.diagnostic.severity.WARN] = "󰀪 ",
			[vim.diagnostic.severity.HINT] = "󰌶 ",
			[vim.diagnostic.severity.INFO] = "󰋽 ",
		},
	},
	underline = true,
	update_in_insert = false,
	severity_sort = true,
	float = {
		border = "rounded",
		source = "always",
		header = "",
		prefix = "",
		focusable = false,
	},
})

-- ============================================================================
-- Formatting (conform owns formatters; LSP is fallback)
-- ============================================================================

require("conform").setup({
	formatters_by_ft = {
		lua = { "stylua" },
		nix = { "nixfmt" },
		python = { "ruff_organize_imports", "ruff_format" },
		go = { lsp_format = "prefer" },
		terraform = { "terraform_fmt" },
		hcl = { "terraform_fmt" },
		toml = { "taplo" },
		rust = { lsp_format = "fallback" },
		sh = { "shfmt" },
		bash = { "shfmt" },
		json = { lsp_format = "prefer" },
		jsonc = { lsp_format = "prefer" },
	},
	format_on_save = function(bufnr)
		local enabled = {
			lua = true,
			nix = true,
			python = true,
			go = true,
			terraform = true,
			hcl = true,
			rust = true,
		}
		if not enabled[vim.bo[bufnr].filetype] then
			return
		end
		return { timeout_ms = 1000, lsp_format = "fallback" }
	end,
})

vim.keymap.set("n", "<leader>lf", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Format" })
vim.keymap.set("n", "<leader>le", vim.diagnostic.open_float, { desc = "Line diagnostics" })
vim.keymap.set("n", "<leader>lq", vim.diagnostic.setloclist, { desc = "Diagnostics loclist" })

-- ============================================================================
-- Plugins
-- ============================================================================

require("copilot").setup({
	panel = { enabled = false },
	suggestion = { enabled = false },
	filetypes = { ["*"] = true },
	-- extraPackages puts nodejs on the nvim wrapper PATH
	copilot_node_command = vim.fn.exepath("node"),
})

require("blink.cmp").setup({
	keymap = { preset = "enter" },
	completion = {
		documentation = { auto_show = true },
	},
	signature = { enabled = true },
	sources = {
		default = { "lsp", "path", "snippets", "buffer", "copilot" },
		providers = {
			copilot = {
				name = "copilot",
				module = "blink-copilot",
				score_offset = 100,
				async = true,
			},
		},
	},
	cmdline = { enabled = true },
})

require("telescope").setup({
	extensions = {
		fzf = {
			fuzzy = true,
			override_generic_sorter = true,
			override_file_sorter = true,
			case_mode = "smart_case",
		},
	},
})
require("telescope").load_extension("fzf")

local builtin = require("telescope.builtin")
vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })

require("gitsigns").setup({
	on_attach = function(bufnr)
		local gitsigns = require("gitsigns")
		local opts = { buffer = bufnr }
		vim.keymap.set("n", "]c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "]c", bang = true })
			else
				gitsigns.nav_hunk("next")
			end
		end, vim.tbl_extend("force", opts, { desc = "Next hunk" }))
		vim.keymap.set("n", "[c", function()
			if vim.wo.diff then
				vim.cmd.normal({ "[c", bang = true })
			else
				gitsigns.nav_hunk("prev")
			end
		end, vim.tbl_extend("force", opts, { desc = "Prev hunk" }))
		vim.keymap.set("n", "<leader>gs", gitsigns.stage_hunk, vim.tbl_extend("force", opts, { desc = "Stage hunk" }))
		vim.keymap.set("n", "<leader>gr", gitsigns.reset_hunk, vim.tbl_extend("force", opts, { desc = "Reset hunk" }))
		vim.keymap.set(
			"n",
			"<leader>gp",
			gitsigns.preview_hunk,
			vim.tbl_extend("force", opts, { desc = "Preview hunk" })
		)
		vim.keymap.set("n", "<leader>gb", gitsigns.blame_line, vim.tbl_extend("force", opts, { desc = "Blame line" }))
	end,
})

require("ibl").setup({
	indent = { char = "▏" },
	scope = {
		enabled = true,
		show_start = true,
		show_end = false,
	},
})

require("nvim-web-devicons").setup({ default = true })

require("oil").setup({
	default_file_explorer = true,
	view_options = { show_hidden = true },
})
vim.keymap.set("n", "-", "<cmd>Oil<cr>", { desc = "Open parent directory" })
vim.keymap.set("n", "<leader>n", "<cmd>Oil<cr>", { desc = "Oil" })

require("harpoon").setup()
vim.keymap.set("n", "<leader>a", require("harpoon.mark").add_file, { desc = "Harpoon add file" })
vim.keymap.set("n", "<leader>e", require("harpoon.ui").toggle_quick_menu, { desc = "Harpoon quick menu" })
vim.keymap.set("n", "<leader>1", function()
	require("harpoon.ui").nav_file(1)
end, { desc = "Harpoon nav to file 1" })
vim.keymap.set("n", "<leader>2", function()
	require("harpoon.ui").nav_file(2)
end, { desc = "Harpoon nav to file 2" })
vim.keymap.set("n", "<leader>3", function()
	require("harpoon.ui").nav_file(3)
end, { desc = "Harpoon nav to file 3" })
vim.keymap.set("n", "<leader>4", function()
	require("harpoon.ui").nav_file(4)
end, { desc = "Harpoon nav to file 4" })
require("telescope").load_extension("harpoon")

require("lualine").setup({
	options = { theme = "nord" },
})
require("which-key").setup({})
require("which-key").add({
	{ "<leader>f", group = "find" },
	{ "<leader>d", group = "diff" },
	{ "<leader>g", group = "git" },
	{ "<leader>l", group = "lsp" },
	{ "<leader>x", group = "trouble" },
})

require("trouble").setup({})
vim.keymap.set("n", "<leader>xx", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Diagnostics (Trouble)" })
vim.keymap.set(
	"n",
	"<leader>xX",
	"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
	{ desc = "Buffer Diagnostics (Trouble)" }
)
vim.keymap.set("n", "<leader>xq", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix List (Trouble)" })

require("diffview").setup({})
vim.keymap.set("n", "<leader>dv", "<cmd>DiffviewOpen<cr>", { desc = "Open Diffview" })
vim.keymap.set("n", "<leader>dc", "<cmd>DiffviewClose<cr>", { desc = "Close Diffview" })
vim.keymap.set("n", "<leader>dh", "<cmd>DiffviewFileHistory<cr>", { desc = "File History" })
vim.keymap.set("n", "<leader>df", "<cmd>DiffviewFileHistory %<cr>", { desc = "Current File History" })

require("barbar").setup({
	animation = true,
	auto_hide = false,
	clickable = true,
	icons = {
		button = "",
		modified = { button = "●" },
		filetype = { enabled = true },
		separator = { left = "▎", right = "" },
		inactive = { separator = { left = "▎", right = "" } },
		diagnostics = {
			[vim.diagnostic.severity.ERROR] = { enabled = true },
			[vim.diagnostic.severity.WARN] = { enabled = true },
		},
	},
	highlight_inactive_file_icons = false,
	insert_at_end = true,
	maximum_padding = 1,
	minimum_padding = 1,
	semantic_letters = true,
	letters = "asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP",
})

local map = vim.keymap.set
local barbar_opts = { silent = true }
map("n", "<A-,>", "<Cmd>BufferPrevious<CR>", barbar_opts)
map("n", "<A-.>", "<Cmd>BufferNext<CR>", barbar_opts)
map("n", "<A-1>", "<Cmd>BufferGoto 1<CR>", barbar_opts)
map("n", "<A-2>", "<Cmd>BufferGoto 2<CR>", barbar_opts)
map("n", "<A-3>", "<Cmd>BufferGoto 3<CR>", barbar_opts)
map("n", "<A-4>", "<Cmd>BufferGoto 4<CR>", barbar_opts)
map("n", "<A-5>", "<Cmd>BufferGoto 5<CR>", barbar_opts)
map("n", "<A-6>", "<Cmd>BufferGoto 6<CR>", barbar_opts)
map("n", "<A-7>", "<Cmd>BufferGoto 7<CR>", barbar_opts)
map("n", "<A-8>", "<Cmd>BufferGoto 8<CR>", barbar_opts)
map("n", "<A-9>", "<Cmd>BufferGoto 9<CR>", barbar_opts)
map("n", "<A-0>", "<Cmd>BufferLast<CR>", barbar_opts)
map("n", "<A-c>", "<Cmd>BufferClose<CR>", barbar_opts)
map("n", "<A-s-c>", "<Cmd>BufferRestore<CR>", barbar_opts)
