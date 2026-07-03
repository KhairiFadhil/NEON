# NEON UI — Documentation

A single-file WindUI-style mod-menu UI library for Roblox exploit executors.
Style: cyan `#A8D8EA` / ink `#0A0A0A` (MODKIT / NEON), Anton display + Montserrat body.

---

## Loading

```lua
local NEON = loadstring(game:HttpGet("https://raw.githubusercontent.com/KhairiFadhil/NEON/main/main.lua"))()
```

> The `main` branch is CDN-cached ~5 min. To force the newest right after an update, add a
> cache-buster: `...main/main.lua?v="..tick()`. Re-running always removes the previous menu
> (no stacking).

---

## Window

```lua
local Window = NEON:CreateWindow({
    Title      = "MODKIT",              -- header text (uppercased). "" for icon-only
    TitleSize  = 26,                    -- optional
    Icon       = "rbxassetid://123",    -- optional logo image, shown before the title
    IconSize   = 30,                    -- optional (default 30)
    IconCorner = 8,                     -- optional corner radius, or false for square

    SubTitle   = "Session Active",      -- substrip text
    Avatar     = "rbxassetid://123",    -- image for the substrip slot...
    AvatarText = "W",                   -- ...or a letter if no Avatar image (default "W")

    Footer      = "BUILD 1.0",          -- footer left text
    FooterRight = nil,                  -- optional footer right text (hidden by default)

    ToggleKey  = Enum.KeyCode.RightShift, -- show/hide the whole menu
    ConfigName = "myscript",            -- enable auto-save to NEON_myscript.json (optional)
})
```

### Window methods

| Method | Description |
|---|---|
| `Window:CreateTab({ Title = "..." })` | Add a tab, returns a Tab |
| `Window:Notify("text")` | Toast (bottom-right, auto-dismiss) |
| `Window:SetTitle(text)` | Change the header title |
| `Window:SetSubTitle(text)` | Change the substrip text |
| `Window:SetFooter(text)` | Change the footer text |
| `Window:SetIcon(rbxassetid)` | Change the logo image |
| `Window:SetAvatarImage(rbxassetid)` | Change the substrip image |
| `Window:SaveConfig([name])` | Save all values to a JSON file |
| `Window:LoadConfig([name])` | Load values from a JSON file |

Behaviour: drag by the navbar or the bottom handle · resize from the corner grip · minimize
via the hamburger (accordion) · `ToggleKey` shows/hides · the list caps at ~352px and scrolls
when a tab overflows (short tabs shrink to fit).

---

## Tabs

```lua
local Tab = Window:CreateTab({ Title = "Main" })
```

Elements are added to a Tab. Every element shares these common config keys:

| Key | Meaning |
|---|---|
| `Title` | Label (also the default config key) |
| `Desc` | Small description line under the label |
| `Badge` | Chip: `"SIGNATURE"` / `"SPICY"` = filled, anything else = outline |
| `Feature` | Renders the label as a filled box (highlight) |
| `Default` | Starting value |
| `Callback` | `function(value)` fired on change |
| `Flag` | Config key override (defaults to `Title`) |

Most elements return `{ Set, Get }` — see each below.

---

## Elements

### Toggle
```lua
local t = Tab:Toggle{ Title = "God Mode", Desc = "Invulnerable", Badge = "SIGNATURE",
                      Feature = true, Default = false, Callback = function(on) end }
t:Set(true)      -- boolean
print(t:Get())   -- boolean
```

### Checkbox
```lua
Tab:Checkbox{ Title = "Auto-Loot", Default = true, Callback = function(on) end }  -- :Set/:Get boolean
```

### Slider
```lua
local s = Tab:Slider{ Title = "WalkSpeed", Min = 16, Max = 500, Step = 1, Unit = "",
                      Default = 16, Callback = function(v) end }
s:Set(200); print(s:Get())   -- number
```

### Input (text box)
```lua
Tab:Input{ Title = "Name", Default = "", Placeholder = "type here",
           Callback = function(text) end }  -- :Set/:Get string (uppercased)
```

### Keybind
```lua
Tab:Keybind{ Title = "Fly Key", Default = "F", Callback = function(keycode) end }
-- :Get returns the key name string; :Set(name) sets it
```

### Dropdown
```lua
Tab:Dropdown{ Title = "Weather", Options = {"CLEAR","RAIN","STORM"}, Default = "CLEAR",
              Callback = function(opt) end }  -- :Set/:Get string
```

### Segmented (button group)
```lua
Tab:Segmented{ Title = "Difficulty", Options = {"EASY","NORMAL","HARD"}, Default = "NORMAL",
               Callback = function(opt) end }  -- :Set/:Get string
```

### Colorpicker (preset swatches)
```lua
Tab:Colorpicker{ Title = "ESP Color", Default = "FF0000",
                 Swatches = {"A8D8EA","EAA8D8","C9A8EA","A8EAB6","EAD8A8"}, -- optional
                 Callback = function(c3) end }
-- :Get returns Color3, :Set(Color3) or :Set("RRGGBB")
```

### Button
```lua
Tab:Button{ Title = "Rejoin", Text = "EXECUTE", Badge = "SPICY", Feature = true,
            Callback = function() end }  -- fires + shows a toast
```

### Section (header/divider)
```lua
Tab:Section("Combat")   -- or Tab:Section({ Title = "Combat" })
```

---

## Config save/load

Pass `ConfigName` when creating the window and every UI change auto-saves (debounced).
Load saved values back after building your tabs:

```lua
local Window = NEON:CreateWindow({ Title = "MODKIT", ConfigName = "myscript" })
-- ... create all tabs + elements ...
Window:LoadConfig()          -- restore on startup
-- Window:SaveConfig()       -- manual save (also happens automatically)
```

- Saved to `NEON_myscript.json` on the executor filesystem.
- Each element is keyed by its `Title` (or its `Flag`). Give elements unique titles, or set
  `Flag = "unique_key"` if two share a title.
- Colors are stored as hex, toggles as bool, sliders as number, etc.

---

## Full example

```lua
local NEON = loadstring(game:HttpGet("https://raw.githubusercontent.com/KhairiFadhil/NEON/main/main.lua"))()
local LP = game:GetService("Players").LocalPlayer

local Window = NEON:CreateWindow({
    Title = "MODKIT", SubTitle = "Session Active", Footer = "v1.0",
    ToggleKey = Enum.KeyCode.RightShift, ConfigName = "mymenu",
})

local Char = Window:CreateTab({ Title = "Character" })
Char:Section("Movement")
Char:Slider{ Title = "WalkSpeed", Min = 16, Max = 300, Default = 16,
    Callback = function(v) LP.Character.Humanoid.WalkSpeed = v end }
Char:Toggle{ Title = "Infinite Jump", Default = false,
    Callback = function(on) getgenv().InfJump = on end }

local Visual = Window:CreateTab({ Title = "Visual" })
Visual:Toggle{ Title = "ESP", Badge = "NEW", Default = false, Callback = function(on) end }
Visual:Colorpicker{ Title = "ESP Color", Default = "A8D8EA", Callback = function(c) end }

Window:LoadConfig()            -- restore saved settings
Window:Notify("Loaded!")
```
