# NEON

A Roblox / Luau mod-menu UI library (WindUI-style, single file). Style: **MODKIT / NEON** — cyan `#A8D8EA` panel on ink `#0A0A0A`, Anton display + Montserrat body. Targets exploit executors (parents to `gethui()`/CoreGui).

## Load

```lua
local NEON = loadstring(game:HttpGet("https://raw.githubusercontent.com/KhairiFadhil/NEON/main/main.lua"))()
```

## Quick start

```lua
local Window = NEON:CreateWindow({
    Title = "MODKIT",
    SubTitle = "Session Active · Wanderer",
    Build = "2.4.1",
    ToggleKey = Enum.KeyCode.F4,   -- show/hide the menu
})

local Tab = Window:CreateTab({ Title = "Character" })

Tab:Toggle{ Title = "God Mode", Desc = "Invulnerable", Badge = "SIGNATURE", Feature = true, Default = true,
            Callback = function(on) print("god mode", on) end }
Tab:Slider{ Title = "Speed", Min = 25, Max = 400, Step = 5, Unit = "%", Default = 100, Callback = print }
Tab:Input{ Title = "Name", Default = "WANDERER", Callback = print }
Tab:Keybind{ Title = "Bind", Default = "F", Callback = print }
Tab:Dropdown{ Title = "Weather", Options = {"CLEAR","RAIN","STORM"}, Default = "CLEAR", Callback = print }
Tab:Segmented{ Title = "Difficulty", Options = {"EASY","NORMAL","HARD"}, Default = "NORMAL", Callback = print }
Tab:Checkbox{ Title = "Auto-Loot", Default = true, Callback = print }
Tab:Colorpicker{ Title = "Accent", Default = "A8D8EA", Callback = print }
Tab:Button{ Title = "Execute", Badge = "SPICY", Feature = true, Callback = function() print("run") end }

Window:Notify("God Mode — Executed")
```

See `example.lua` for a full reproduction of the design (all 5 tabs, every control).

## Key / login page

Optional license-key screen shown before the menu (same style: 4px corners, drop shadow,
draggable, closeable). Build your menu in `OnSuccess`:

```lua
NEON:CreateKeyPage({
    Callback  = function(key) return key == "DEMO" end,  -- return true/false (may HttpGet)
    OnSuccess = function() NEON:CreateWindow({ Title = "MODKIT" }) end,
})
```

Config: `Brand`, `Title`, `Subtitle`, `Heading`, `Note`, `Build`, `HWID`, `ShowHWID`,
`GetKeyUrl`, `Discord`/`DiscordUrl`, `Callback`, `OnSuccess`, `OnClose`. Full flow demo:
`login-demo.lua` (key: `DEMO`). See `DOCS.md`.

## Config keys

- **Window**:
  - `Title` (text), `TitleSize`, `Icon` (rbxassetid logo before the title), `IconSize`, `IconCorner`
  - `SubTitle`, `Avatar` (rbxassetid image slot) or `AvatarText` (letter, default "W")
  - `Footer` (left text), `FooterRight` (optional right text — omitted by default)
  - `ToggleKey`, `ConfigName` (enables auto-save under `NEON_<name>.json`)
- **Element** (common): `Title`, `Desc`, `Badge` (`"SIGNATURE"` / `"SPICY"` filled, anything else outlined), `Feature` (boxed label), `Default`, `Callback`, `Flag` (config key override — defaults to `Title`)
- **Slider**: `Min`, `Max`, `Step`, `Unit`
- **Dropdown / Segmented**: `Options` (array)
- **Colorpicker**: `Default` (hex), `Swatches` (array of hex preset choices)

Most elements return `{ Set, Get }`.

## Runtime customisation

```lua
Window:SetTitle("NEW NAME")
Window:SetSubTitle("logged in as X")
Window:SetFooter("v2")
Window:SetIcon("rbxassetid://123")
Window:SetAvatarImage("rbxassetid://123")
```

## Config save/load

Pass `ConfigName` to the window and it auto-saves every change. Load it back after building your tabs:

```lua
local Window = NEON:CreateWindow({ Title = "MODKIT", ConfigName = "myscript" })
-- ... create all tabs + elements ...
Window:LoadConfig()   -- restore saved values on startup
-- Window:SaveConfig() also available for a manual save
```

Values persist to `NEON_myscript.json` on the executor's filesystem. Each element is keyed by its `Title` (or `Flag`).

## Features

Drag (navbar or bottom handle) · resize (corner grip) · minimize accordion · F4 toggle · toast notifications · soft drop shadow. Fonts: downloads Anton via `getcustomasset`, falls back to Oswald if the fs API is missing.
