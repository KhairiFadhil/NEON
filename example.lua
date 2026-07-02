-- NEON demo — reproduces "Mod Menu.dc.html" 1:1. Exercises every control.
-- In-game:  loadstring(game:HttpGet("<raw main.lua url>"))()  then run this.
-- Local test: place main.lua beside this and require/loadstring it.

local NEON = loadstring(game:HttpGet("https://raw.githubusercontent.com/KhairiFadhil/NEON/main/main.lua"))()

local Window = NEON:CreateWindow({
	Title = "MODKIT",
	SubTitle = "Session Active · Wanderer",
	Build = "2.4.1",
	ToggleKey = Enum.KeyCode.F4,
})

-- CHARACTER
local Character = Window:CreateTab({ Title = "Character" })
Character:Toggle{ Title = "God Mode", Desc = "Invulnerable · no fall damage", Badge = "SIGNATURE", Feature = true, Default = true }
Character:Toggle{ Title = "Infinite Stamina", Desc = "Sprint / swim / climb forever" }
Character:Slider{ Title = "Movement Speed", Desc = "Base 100%", Min = 25, Max = 400, Step = 5, Unit = "%", Default = 100 }
Character:Slider{ Title = "Jump Height", Desc = "Vertical force", Min = 10, Max = 300, Step = 5, Unit = "%", Default = 100 }
Character:Input{ Title = "Display Name", Desc = "Shown above character", Default = "WANDERER" }
Character:Keybind{ Title = "Toggle Menu", Desc = "Global hotkey · click to rebind", Default = "F4" }

-- WORLD
local World = Window:CreateTab({ Title = "World" })
World:Slider{ Title = "Time Of Day", Desc = "00:00 — 24:00", Min = 0, Max = 100, Step = 1, Default = 45 }
World:Dropdown{ Title = "Weather", Desc = "Force atmosphere", Options = { "CLEAR", "RAIN", "STORM", "FOG", "SNOW", "BLOOD MOON" }, Default = "CLEAR" }
World:Toggle{ Title = "Freeze Time", Desc = "Pause world clock", Badge = "NEW" }
World:Segmented{ Title = "Difficulty", Desc = "Enemy scaling", Options = { "PEACEFUL", "NORMAL", "HARD", "NIGHTMARE" }, Default = "NORMAL" }

-- INVENTORY
local Inventory = Window:CreateTab({ Title = "Inventory" })
Inventory:Input{ Title = "Spawn Item", Desc = "Item id / name", Default = "IRON SWORD" }
Inventory:Dropdown{ Title = "Category", Desc = "Filter spawn pool", Options = { "WEAPONS", "ARMOR", "CONSUMABLES", "MATERIALS", "KEY ITEMS" }, Default = "WEAPONS" }
Inventory:Input{ Title = "Quantity", Desc = "Stack size", Default = "10" }
Inventory:Checkbox{ Title = "Auto-Loot", Desc = "Vacuum nearby drops", Default = true }
Inventory:Button{ Title = "Add To Inventory", Desc = "Commit spawn to bag", Badge = "SPICY", Feature = true }

-- COMBAT
local Combat = Window:CreateTab({ Title = "Combat" })
Combat:Toggle{ Title = "One-Hit Kill", Desc = "Any hit = lethal", Badge = "SPICY", Feature = true }
Combat:Slider{ Title = "Damage Multiplier", Desc = "Outgoing damage", Min = 50, Max = 1000, Step = 10, Unit = "%", Default = 150 }
Combat:Toggle{ Title = "No Reload", Desc = "Infinite magazine", Default = true }
Combat:Keybind{ Title = "Rapid Fire", Desc = "Bind · hold to burst", Default = "MOUSE1" }

-- VISUALS
local Visuals = Window:CreateTab({ Title = "Visuals" })
Visuals:Colorpicker{ Title = "UI Accent", Desc = "Interface color", Default = "A8D8EA" }
Visuals:Colorpicker{ Title = "Player Glow", Desc = "Character outline", Default = "C9A8EA" }
Visuals:Slider{ Title = "Field Of View", Desc = "Camera angle", Min = 60, Max = 120, Step = 1, Unit = "°", Default = 90 }
Visuals:Toggle{ Title = "Entity ESP", Desc = "Highlight NPCs through walls", Badge = "NEW" }
