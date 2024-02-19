-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

local macos = false
local chromeos = false

if wezterm.target_triple:find("darwin") ~= nil then
	macos = true
end

if wezterm.hostname == "penguin" then
	chromeos = true
end

-- Get defaults
if wezterm.config_builder then
  config = wezterm.config_builder()
end

wezterm.log_info("config loaded and version is " .. wezterm.version)

-- FIXME: find a better way to handle this
config.ssh_domains = {
	{ name = 'crab', remote_address = 'crab', },
	{ name = 'wonkden', remote_address = 'wonkden', },
	{ name = 'perlish', remote_address = 'perlish', remote_wezterm_path = '/home/cowens/bin/wezterm' },
}

config.scrollback_lines = 20000

-- I hate beeps on error and the screen should quickly flash instead
config.audible_bell = "Disabled"
config.visual_bell = {
	fade_in_function = "Linear",
	fade_out_function = "Linear",
	fade_in_duration_ms = 10,
	fade_out_duration_ms = 10,
}

-- I can never decide which is better, but consistency is good
if macos then
	config.native_macos_fullscreen_mode = true
end

-- I don't want new windows popping up when joining to domains and such
config.prefer_to_spawn_tabs = true

-- focus follows mouse is how everything should work
config.pane_focus_follows_mouse = true

-- I prefer a terminal only interface, the fancy tab bar looks too out of place in fullscreen mode
config.use_fancy_tab_bar = false

-- I include the current clipboard value in my status, this code cleans up
-- control characters in it
pretty_control_chars = {
	["\u{7f}"] = "\u{2421}",
}

for c = 0, 0x1f, 1 do
	pretty_control_chars[utf8.char(c)] = utf8.char(c + 0x2400)
end

function prettify_control_chars(s, max)
	local pretty = s:gsub("(.)", function(x) if pretty_control_chars[x] then return pretty_control_chars[x] else return x end end)
	return pretty:sub(1, utf8.offset(pretty, max))
end

wezterm.on("update-status", function(window, pane)
	local left = wezterm.format({{Foreground={Color="black"}},{Text=window:active_workspace()}})
	if window:active_workspace() == (config.default_workspace or "default") then
		left = ""
	end
	window:set_left_status(left)

	local clipboard = ""
	if macos then
		-- FIXME: add the ability to get the clipboard natively in Lua, this is
		-- a massive waste of resources
		_, clipboard, _ = wezterm.run_child_process({"pbpaste"});
		-- FIXME: find a better solution than hard coding 100, maybe
		-- use the width of the window?
		clipboard = " [" .. prettify_control_chars(clipboard, 100) .. "] "
	end

	-- I hate doing the math to figure out what hour it is in UTC
	local utc_hour = wezterm.strftime_utc("%H")

	local right = clipboard .. wezterm.strftime("%a %Y-%m-%d " .. utc_hour .. "/%H:%M:%S")

	window:set_right_status(wezterm.format({{Foreground={Color="black"}},{Text=right}}));
end);

config.tab_bar_at_bottom = true

config.default_cursor_style = 'BlinkingBlock'
config.cursor_blink_rate = 500
config.cursor_blink_ease_in = 'Constant'
config.cursor_blink_ease_out = 'Constant'

config.colors = {
	foreground    = '#00ff00',
	background    = 'black',
	cursor_bg     = '#00ff00',
	cursor_fg     = 'black',
	cursor_border = '#00ff00',
	visual_bell   = "#00ff00",
	compose_cursor = "#ff0000",
	tab_bar = {
		background = "#5fc63b",
		new_tab = {
			bg_color = "#5fc63b",
			fg_color = "#000000",
		},
		new_tab_hover = {
			bg_color = "#5fc63b",
			fg_color = "#000000",
		},
		active_tab = {
			bg_color = "#00ff00",
			fg_color = "#000000",
		},
		inactive_tab = {
			bg_color = "#5fc63b",
			fg_color = "#000000",
		},
		inactive_tab_hover = {
			bg_color = "#5fc63b",
			fg_color = "#000000",
		},
	},
}

config.font = wezterm.font 'Menlo'

-- FIXME: find a better way to handle this
if macos then
	config.font_size = 25
else
	config.font_size = 18
end

config.send_composed_key_when_left_alt_is_pressed = true
config.disable_default_key_bindings = true
config.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
config.selection_word_boundary = '|{}[]()"\'`,;: \t'


local nest_level = 0
wezterm.on('nest', function(win, pane)
	local overrides = win:get_config_overrides() or {}

	if nest_level == 0 then
		overrides.leader = { key = 's', mods = 'CTRL', timeout_milliseconds = 1000 }
		overrides.colors = win:effective_config().colors
		overrides.colors.tab_bar.active_tab.fg_color = '#5fc63b'
		overrides.colors.tab_bar.active_tab.bg_color = 'black'
		overrides.keys = win:effective_config().keys
		overrides.keys[2].action = act.EmitEvent('unnest')
		overrides.keys[3].action = act.DisableDefaultAssignment
		overrides.keys[4].action = act.DisableDefaultAssignment
		overrides.keys[5].action = act.DisableDefaultAssignment
		overrides.keys[6].action = act.DisableDefaultAssignment
		win:set_config_overrides(overrides)
		nest_level = nest_level + 1
	else
		nest_level = nest_level + 1
		win:perform_action( act.SendKey { key = 'UpArrow', mods = 'SHIFT' }, pane )
	end
end)

wezterm.on('unnest', function(win, pane)
	if nest_level <= 1 then
		nest_level = 0
		local overrides = win:get_config_overrides() or {}
		overrides.leader = { key = 'a', mods = 'CTRL', timeout_milliseconds = 1000 }
		overrides.colors = win:effective_config().colors
		overrides.colors.tab_bar.active_tab.fg_color = 'black'
		overrides.colors.tab_bar.active_tab.bg_color = '#00ff00'
		overrides.keys = win:effective_config().keys
		overrides.keys[2].action = act.DisableDefaultAssignment
		overrides.keys[3].action = act.ActivateTabRelative(-1)
		overrides.keys[4].action = act.MoveTabRelative(-1)
		overrides.keys[5].action = act.ActivateTabRelative(1)
		overrides.keys[6].action = act.MoveTabRelative(1)
		win:set_config_overrides(overrides)
	else
		nest_level = nest_level - 1
		win:perform_action( act.SendKey { key = 'DownArrow', mods = 'SHIFT' }, pane )
	end
end)

local keys = {
	{ key = 'UpArrow',    mods = 'SHIFT',        action = act.EmitEvent('nest')                      },
	{ key = 'DownArrow',  mods = 'SHIFT',        action = act.DisableDefaultAssignment               },
	{ key = 'LeftArrow',  mods = 'SHIFT',        action = act.ActivateTabRelative(-1)                },
	{ key = 'LeftArrow',  mods = 'SHIFT|CTRL',   action = act.MoveTabRelative(-1)                    },
	{ key = 'RightArrow', mods = 'SHIFT',        action = act.ActivateTabRelative(1)                 },
	{ key = 'RightArrow', mods = 'SHIFT|CTRL',   action = act.MoveTabRelative(1)                     },
	{ key = 'UpArrow',    mods = 'SHIFT|CTRL',   action = act.ScrollToPrompt(-1)                     },
	{ key = 'DownArrow',  mods = 'SHIFT|CTRL',   action = act.ScrollToPrompt(1)                      },
	{ key = 'a',          mods = 'LEADER|CTRL',  action = act.ActivateLastTab                        },
	{ key = 'a',          mods = 'LEADER',       action = act.SendKey { key = 'a', mods = 'CTRL' }   },
	{ key = 'c',          mods = 'LEADER',       action = act.SpawnTab 'CurrentPaneDomain'           },
	{ key = 'd',          mods = 'LEADER',       action = act.DetachDomain 'CurrentPaneDomain'       },
	{ key = 'mapped:D',   mods = 'LEADER',       action = act.ShowLauncherArgs { flags = "DOMAINS" } },
	{ key = 'e',          mods = 'LEADER',       action = act.CharSelect                             },
	{
		key = ',',
		mods = 'LEADER',
		action = act.PromptInputLine {
			description = 'Enter new name for tab',
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:active_tab():set_title(line)
				end
			end),
		}
	},
	{
		key = 'mapped:S',
		mods = 'LEADER',
		action = act.PromptInputLine {
			description = "Rename Workspace",
			action = wezterm.action_callback(function(window, pane, line)
				if line then
					window:mux_window():set_workspace(line)
				end
			end)
		}
	},
	{ key = 's',           mods = 'LEADER', action = act.ShowLauncherArgs { flags = "WORKSPACES" }               },
	{ key = '/',           mods = 'LEADER', action = act.Search("CurrentSelectionOrEmptyString")                 },
	{ key = '?',           mods = 'LEADER', action = act.ShowDebugOverlay                                        },
	{ key = 'v',           mods = 'LEADER', action = act.ActivateCopyMode                                        },
	{ key = 'z',           mods = 'LEADER', action = act.TogglePaneZoomState                                     },
	{ key = 'x',           mods = 'LEADER', action = act.CloseCurrentTab { confirm = true }                      },
	{ key = '|',           mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' }        },
	{ key = '\\',          mods = 'LEADER', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' }        },
	{ key = '-',           mods = 'LEADER', action = act.SplitVertical { domain = 'CurrentPaneDomain' }          },
	{ key = 'UpArrow',     mods = 'LEADER', action = act.ActivatePaneDirection('Up')                             },
	{ key = 'DownArrow',   mods = 'LEADER', action = act.ActivatePaneDirection('Down')                           },
	{ key = 'LeftArrow',   mods = 'LEADER', action = act.ActivatePaneDirection('Left')                           },
	{ key = 'RightArrow',  mods = 'LEADER', action = act.ActivatePaneDirection('Right')                          },
	{ key = '-',           mods = 'SUPER',  action = act.DecreaseFontSize                                        },
	{ key = '+',           mods = 'SUPER',  action = act.IncreaseFontSize                                        },
	{ key = '0',           mods = 'SUPER',  action = act.ResetFontSize                                           },
	{ key = 'Enter',       mods = 'SUPER',  action = act.ToggleFullScreen                                        },
}

for i = 0, 9 do
	keys[#keys+1] = { key = tostring(i), mods = 'LEADER', action = act.ActivateTab(i+1) }
end

config.keys = keys

-- config.mouse_bindings = {
-- 	{ event = { Down = { streak = 1, button = 'Right' }, mods = none, action = act.nop  },
-- 	{ event = { Up   = { streak = 1, button = 'Right' }, mods = none, action = act.  },
-- }
wezterm.on('gui-startup', function(cmd)
	local window_args = {}
	if wezterm.gui.screens().by_name["LG QHD"] then
		window_args = {
			position = {
				x = wezterm.gui.screens().by_name["LG QHD"].x,
				y = wezterm.gui.screens().by_name["LG QHD"].y,
				origin = { Named="LG QHD" },
			},
		}
	end
	local tab, pane, window = wezterm.mux.spawn_window(cmd or window_args)
	window:gui_window():toggle_fullscreen()
end)

if chromeos then
	enable_wayland=false
end

-- and finally, return the configuration to wezterm
return config
