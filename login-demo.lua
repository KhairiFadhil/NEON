-- NEON — full login → menu demo.  Run in an executor:
--   loadstring(game:HttpGet("https://raw.githubusercontent.com/KhairiFadhil/NEON/main/login-demo.lua"))()
-- Key to enter: DEMO   (or any MODKIT-XXXX-XXXX-XXXX)

local NEON = loadstring(game:HttpGet("https://raw.githubusercontent.com/KhairiFadhil/NEON/main/main.lua"))()
local LP = game:GetService("Players").LocalPlayer

-- built after the key is accepted -------------------------------------------
local function buildMenu()
	local Window = NEON:CreateWindow({
		Title = "MODKIT",
		SubTitle = "Session Active · " .. (LP and LP.DisplayName or "Wanderer"),
		Build = "2.4.1",
		ToggleKey = Enum.KeyCode.RightShift,
	})

	local Character = Window:CreateTab({ Title = "Character" })
	Character:Toggle{ Title = "God Mode", Desc = "Invulnerable · no fall damage", Badge = "SIGNATURE", Feature = true, Default = true }
	Character:Slider{ Title = "Movement Speed", Desc = "Base 100%", Min = 25, Max = 400, Step = 5, Unit = "%", Default = 100 }
	Character:Input{ Title = "Display Name", Default = "WANDERER" }
	Character:Keybind{ Title = "Toggle Menu", Desc = "Global hotkey", Default = "RightShift" }

	local World = Window:CreateTab({ Title = "World" })
	World:Dropdown{ Title = "Weather", Options = { "CLEAR", "RAIN", "STORM", "FOG", "SNOW", "BLOOD MOON", "AURORA", "ECLIPSE" }, Default = "CLEAR" }
	World:Segmented{ Title = "Difficulty", Options = { "PEACEFUL", "NORMAL", "HARD" }, Default = "NORMAL" }
	World:Toggle{ Title = "Freeze Time", Badge = "NEW" }

	local Visuals = Window:CreateTab({ Title = "Visuals" })
	Visuals:Colorpicker{ Title = "UI Accent", Default = "A8D8EA" }
	Visuals:Slider{ Title = "Field Of View", Min = 60, Max = 120, Unit = "°", Default = 90 }
	Visuals:Toggle{ Title = "Entity ESP", Desc = "Highlight NPCs through walls", Badge = "NEW" }

	Window:Notify("Access granted — welcome")
end

-- login ----------------------------------------------------------------------
NEON:CreateKeyPage({
	Brand     = "MODKIT",
	Title     = "KEY\nSYSTEM",
	Subtitle  = "Authenticate your license to unlock the loader.",
	Build     = "v2.4.1",
	Discord   = "gg/modkit",
	GetKeyUrl = "https://discord.gg/modkit",
	Callback  = function(key)
		task.wait(1.1)                         -- pretend we hit a license server
		return key == "DEMO" or key:match("^MODKIT%-%w%w%w%w%-%w%w%w%w%-%w%w%w%w$") ~= nil
	end,
	OnSuccess = buildMenu,
	OnClose   = function() end,
})
