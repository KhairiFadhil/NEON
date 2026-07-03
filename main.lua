--!nolint
-- NEON — a Roblox/Luau mod-menu UI library (WindUI-style single-file bundle)
-- Style: "MODKIT / NEON" — cyan #A8D8EA panel on ink #0A0A0A, Oswald(display)+Montserrat(body).
-- Target: exploit executors (parents to gethui()/CoreGui). loadstring(game:HttpGet(url))()
--
-- API (see example.lua for a full reproduction of the design):
--   local NEON = loadstring(game:HttpGet(URL))()
--   local Window = NEON:CreateWindow({ Title="MODKIT", SubTitle="Session Active · Wanderer",
--                                      Build="2.4.1", ToggleKey=Enum.KeyCode.F4 })
--   local Tab = Window:CreateTab({ Title="Character" })
--   Tab:Toggle{ Title="God Mode", Desc="...", Badge="SIGNATURE", Feature=true, Default=true, Callback=fn }
--   Tab:Checkbox{...}  Tab:Slider{...}  Tab:Input{...}  Tab:Keybind{...}
--   Tab:Dropdown{...}  Tab:Segmented{...}  Tab:Colorpicker{...}  Tab:Button{...}
--   Window:Notify("God Mode — Executed")

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local RunService        = game:GetService("RunService")

------------------------------------------------------------------- theme
local ACCENT = Color3.fromHex("A8D8EA")   -- cyan
local INK    = Color3.fromHex("0A0A0A")   -- black

-- Body ~= Archivo. Montserrat (built-in) is close and ships every weight, so we keep it.
local BODY_FAMILY = "rbxasset://fonts/families/Montserrat.json"
local function bodyFont(weight) return Font.new(BODY_FAMILY, weight or Enum.FontWeight.Medium) end

-- Display = Anton. Not a Roblox built-in, so on an executor we download+register the real
-- Google font once; if the fs API is missing we fall back to Oswald (closest built-in condensed).
local DISPLAY_FONT
do
	local ok, font = pcall(function()
		if not (writefile and getcustomasset) then return nil end
		local ttf = "NEON_Anton.ttf"
		if not (isfile and isfile(ttf)) then
			writefile(ttf, game:HttpGet("https://github.com/google/fonts/raw/main/ofl/anton/Anton-Regular.ttf"))
		end
		local asset = getcustomasset(ttf)
		writefile("NEON_Anton.json",
			'{"name":"Anton","faces":[{"name":"Regular","weight":400,"style":"normal","assetId":"' .. asset .. '"}]}')
		return Font.new(getcustomasset("NEON_Anton.json"))
	end)
	DISPLAY_FONT = (ok and font) or Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
end
local function displayFont() return DISPLAY_FONT end

------------------------------------------------------------------- tiny helpers
local function new(class, props)
	local o = Instance.new(class)
	local parent = props.Parent
	props.Parent = nil
	for k, v in pairs(props) do o[k] = v end
	if parent then o.Parent = parent end
	return o
end

local function pad(parent, t, r, b, l)
	return new("UIPadding", {
		Parent = parent,
		PaddingTop = UDim.new(0, t), PaddingRight = UDim.new(0, r or t),
		PaddingBottom = UDim.new(0, b or t), PaddingLeft = UDim.new(0, l or r or t),
	})
end
local function corner(parent, r) return new("UICorner", { Parent = parent, CornerRadius = UDim.new(0, r) }) end
local function stroke(parent, thick, color, trans)
	return new("UIStroke", { Parent = parent, Thickness = thick, Color = color or INK,
		Transparency = trans or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end
local function hlist(parent, gap, align)
	return new("UIListLayout", { Parent = parent, FillDirection = Enum.FillDirection.Horizontal,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder })
end
local function vlist(parent, gap)
	return new("UIListLayout", { Parent = parent, FillDirection = Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 0), SortOrder = Enum.SortOrder.LayoutOrder })
end
local function label(parent, text, size, weight, color)
	return new("TextLabel", {
		Parent = parent, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.fromOffset(0, 0), Text = text, TextColor3 = color or INK,
		FontFace = bodyFont(weight), TextSize = size, TextXAlignment = Enum.TextXAlignment.Left,
	})
end
local TWEEN = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local function tween(o, props, info) TweenService:Create(o, info or TWEEN, props):Play() end

------------------------------------------------------------------- gui root
local function mountRoot()
	-- Remove any previous NEON window so re-running a script never stacks menus.
	for _, r in ipairs({ (function() local ok,h=pcall(function() return gethui() end) return ok and h or nil end)(),
		game:GetService("CoreGui") }) do
		if r then for _, sg in ipairs(r:GetChildren()) do
			if sg:IsA("ScreenGui") and sg:GetAttribute("NEON") then sg:Destroy() end
		end end
	end
	local gui = new("ScreenGui", {
		Name = "\0NEON\0", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = true, DisplayOrder = 999999,
	})
	gui:SetAttribute("NEON", true)
	pcall(function() if syn and syn.protect_gui then syn.protect_gui(gui) end end)
	pcall(function() if protectgui then protectgui(gui) end end)
	local parent
	pcall(function() parent = gethui and gethui() end)
	parent = parent or game:GetService("CoreGui")
	gui.Parent = parent
	return gui
end

------------------------------------------------------------------- drag utility
-- Drags/resizes an offset-positioned frame via the given handle.
local function bindDrag(handle, panel, mode, onDone)
	local dragging, startInput, startVal
	handle.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			startInput = i.Position
			startVal = (mode == "resize") and Vector2.new(panel.Size.X.Offset, panel.Size.Y.Offset)
				or Vector2.new(panel.Position.X.Offset, panel.Position.Y.Offset)
			i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then dragging = false end
			end)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if not dragging then return end
		if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
			local d = i.Position - startInput
			if onDone then onDone(startVal, Vector2.new(d.X, d.Y)) end
		end
	end)
end

-- Dim a handle's parts to `dim` at rest, fade them in on hover or press (design: 0.25 -> 1).
local function microFade(btn, parts, dim)
	dim = dim or 0.72
	local hover, press = false, false
	local function apply()
		local target = (hover or press) and 0 or dim
		for _, p in ipairs(parts) do tween(p, { BackgroundTransparency = target }) end
	end
	btn.MouseEnter:Connect(function() hover = true; apply() end)
	btn.MouseLeave:Connect(function() hover = false; apply() end)
	btn.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then press = true; apply() end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) and press then press = false; apply() end
	end)
	apply()
end

-- Config plumbing. autosaveCb wraps the user's callback so any UI change marks the window
-- dirty (debounced auto-save). bindFlag exposes the value under its Flag/Title key so
-- SaveConfig/LoadConfig can round-trip it.
local function autosaveCb(win, cfg)
	local userCb = cfg.Callback
	cfg.Callback = function(...) if userCb then userCb(...) end; win:_dirty() end
end
local function bindFlag(win, cfg, get, set)
	local key = cfg.Flag or cfg.Title
	if key then win._flags[key] = { get = get, set = set } end
end

------------------------------------------------------------------- ELEMENTS
-- Shared row: left (label/badge/desc) grows, control sits right.
local function makeRow(page)
	local row = new("Frame", { Parent = page, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	-- Top border: sibling of the content frame, NOT inside the horizontal layout —
	-- otherwise it counts as a full-width layout item and shoves the controls off-edge.
	new("Frame", { Parent = row, Name = "border", BackgroundColor3 = INK, BackgroundTransparency = 0.78,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) })
	local content = new("Frame", { Parent = row, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	pad(content, 17, 24, 17, 24)
	hlist(content, 22).VerticalAlignment = Enum.VerticalAlignment.Center

	local left = new("Frame", { Parent = content, BackgroundTransparency = 1, LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(0, 0, 0, 0) })
	new("UIFlexItem", { Parent = left, FlexMode = Enum.UIFlexMode.Fill })
	vlist(left, 7)

	local top = new("Frame", { Parent = left, BackgroundTransparency = 1, LayoutOrder = 1,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0) })
	local tl = hlist(top, 11); tl.VerticalAlignment = Enum.VerticalAlignment.Center; tl.Wraps = true
	local ctrl = new("Frame", { Parent = content, BackgroundTransparency = 1, LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(0, 0, 0, 0) })
	return row, left, top, ctrl
end

local function addLabelAndBadge(top, cfg)
	if cfg.Feature then
		local box = new("TextLabel", { Parent = top, LayoutOrder = 1, BackgroundColor3 = INK,
			AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
			Text = string.upper(cfg.Title), TextColor3 = ACCENT, FontFace = bodyFont(Enum.FontWeight.ExtraBold),
			TextSize = 19 })
		pad(box, 2, 10, 3, 10); corner(box, 3)
	else
		local l = label(top, string.upper(cfg.Title), 19, Enum.FontWeight.ExtraBold, INK)
		l.LayoutOrder = 1
	end
	if cfg.Badge then
		local filled = cfg.Badge == "SIGNATURE" or cfg.Badge == "SPICY"
		local b = new("TextLabel", { Parent = top, LayoutOrder = 2,
			BackgroundColor3 = INK, BackgroundTransparency = filled and 0 or 1,
			AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0),
			Text = string.upper(cfg.Badge), TextColor3 = filled and ACCENT or INK,
			FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 9 })
		pad(b, 3, 7, 3, 7); corner(b, 3)
		if not filled then stroke(b, 1, INK) end
	end
end

local function addDesc(left, cfg)
	if not cfg.Desc then return end
	local d = label(left, string.upper(cfg.Desc), 10.5, Enum.FontWeight.Medium, INK)
	d.LayoutOrder = 2; d.TextTransparency = 0.47
	-- ponytail: natural width, no wrap. Design descs are short one-liners; a scale-width
	-- child inside a flex-Fill column resolves against 0 base width and wraps to nothing.
end

------------------------------------------------------------------- library core
local NEON = {}
NEON.__index = NEON

function NEON:CreateWindow(cfg)
	cfg = cfg or {}
	local gui = mountRoot()
	local win = setmetatable({ _gui = gui, _tabs = {}, _toggleStates = {}, _openDropdown = nil,
		_flags = {}, _configName = cfg.ConfigName }, NEON)

	local W, LIST_H = 772, 352
	local panel = new("Frame", { Parent = gui, BackgroundColor3 = ACCENT, BorderSizePixel = 0,
		Position = UDim2.fromOffset(60, 60), Size = UDim2.new(0, W, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, ClipsDescendants = true, Active = true })
	corner(panel, 4)   -- uniform 4px corners, no black outline (soft shadow instead)
	vlist(panel, 0)
	win._panel = panel

	-- soft drop shadow behind the panel (9-slice); low intensity for a gentle blur
	local shadow = new("ImageLabel", { Parent = gui, BackgroundTransparency = 1, ZIndex = 0,
		Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.76,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450) })

	-- MOVE + RESIZE handles float from the ScreenGui, NOT the panel — the panel's vertical
	-- UIListLayout would otherwise capture them and stack them (the glitch). Floating here also
	-- lets them hide with the panel and on minimise, and never get clipped.
	local moveH = new("TextButton", { Parent = gui, BackgroundTransparency = 1, Text = "", ZIndex = 45,
		AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(70, 22), AutoButtonColor = false })
	local mhFrame = new("Frame", { Parent = moveH, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	local mh = vlist(mhFrame, 3)
	mh.HorizontalAlignment = Enum.HorizontalAlignment.Center; mh.VerticalAlignment = Enum.VerticalAlignment.Center
	local gripBars = {}
	for i = 1, 2 do
		gripBars[i] = new("Frame", { Parent = mhFrame, LayoutOrder = i, BackgroundColor3 = INK,
			BorderSizePixel = 0, Size = UDim2.fromOffset(i == 1 and 42 or 26, 4) })
		corner(gripBars[i], 2)
	end
	-- resize grip: two nested diagonal strokes, matching the design's corner SVG (not a filled ◢)
	local resizeH = new("TextButton", { Parent = gui, BackgroundTransparency = 1, Text = "", ZIndex = 45,
		AnchorPoint = Vector2.new(1, 1), Size = UDim2.fromOffset(26, 26), AutoButtonColor = false })
	local rGrip = new("Frame", { Parent = resizeH, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -5, 1, -5), Size = UDim2.fromOffset(13, 13) })
	local rl1 = new("Frame", { Parent = rGrip, BackgroundColor3 = INK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(16, 1.6), Rotation = -45 })
	local rl2 = new("Frame", { Parent = rGrip, BackgroundColor3 = INK, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(9.25 / 13, 9.25 / 13), Size = UDim2.fromOffset(8, 1.6), Rotation = -45 })
	microFade(moveH, gripBars)
	microFade(resizeH, { rl1, rl2 })

	-- Heartbeat (not changed-signals): AutomaticSize shifts AbsolutePosition a frame late, so a
	-- signal-based follow lags. One cheap per-frame follow keeps shadow + handles exactly pinned.
	local SH = 34
	local uiConn = RunService.Heartbeat:Connect(function()
		if not panel.Parent then return end
		local px, py = panel.Position.X.Offset, panel.Position.Y.Offset
		local s = panel.AbsoluteSize
		shadow.Position = UDim2.fromOffset(px - SH, py - SH)
		shadow.Size = UDim2.fromOffset(s.X + SH * 2, s.Y + SH * 2)
		shadow.Visible = panel.Visible
		local show = panel.Visible and not win._min
		moveH.Visible = show; resizeH.Visible = show
		moveH.Position = UDim2.fromOffset(px + s.X / 2, py + s.Y - 7)
		resizeH.Position = UDim2.fromOffset(px + s.X, py + s.Y)
	end)
	gui.Destroying:Connect(function() uiConn:Disconnect() end)

	-- NAVBAR ---------------------------------------------------------------
	local nav = new("Frame", { Parent = panel, LayoutOrder = 1, BackgroundColor3 = ACCENT,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 64), Active = true })
	corner(nav, 4)   -- rounds the panel's TOP corners even if ClipsDescendants doesn't round
	local navL = new("Frame", { Parent = nav, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 36, 0.5, 0), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0,0) })
	hlist(navL, 16).VerticalAlignment = Enum.VerticalAlignment.Center
	-- hamburger / minimize glyph
	local burger = new("TextButton", { Parent = navL, LayoutOrder = 1, BackgroundTransparency = 1,
		Text = "", Size = UDim2.fromOffset(28, 24), AutoButtonColor = false })
	local bcol = new("Frame", { Parent = burger, BackgroundTransparency = 1, Size = UDim2.fromScale(1,1) })
	local bl = vlist(bcol, 5); bl.HorizontalAlignment = Enum.HorizontalAlignment.Left
	bl.VerticalAlignment = Enum.VerticalAlignment.Center
	for i = 1, 3 do
		new("Frame", { Parent = bcol, LayoutOrder = i, BackgroundColor3 = INK, BorderSizePixel = 0,
			Size = UDim2.fromOffset(i == 3 and 16 or 24, 2.5) })
	end
	-- optional logo/icon (image) before the title; set Title="" for an icon-only header
	if cfg.Icon then
		local icon = new("ImageLabel", { Parent = navL, LayoutOrder = 2, BackgroundTransparency = 1,
			Image = cfg.Icon, Size = UDim2.fromOffset(cfg.IconSize or 30, cfg.IconSize or 30),
			ScaleType = Enum.ScaleType.Fit })
		if cfg.IconCorner ~= false then corner(icon, cfg.IconCorner or 8) end
		win._icon = icon
	end
	local titleWrap = new("Frame", { Parent = navL, LayoutOrder = 3, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0,0) })
	local t = label(titleWrap, string.upper(tostring(cfg.Title or "MODKIT")), cfg.TitleSize or 26, Enum.FontWeight.Heavy, INK)
	t.FontFace = bodyFont(Enum.FontWeight.Heavy)
	titleWrap.Visible = (t.Text ~= "")
	win._title = t

	-- SESSION SUBSTRIP -----------------------------------------------------
	local sub = new("Frame", { Parent = panel, LayoutOrder = 2, BackgroundColor3 = ACCENT,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 48) })
	local subTopB = new("Frame", { Parent = sub, BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1.5), Position = UDim2.fromScale(0, 0) })
	local subBotB = new("Frame", { Parent = sub, BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1.5), Position = UDim2.new(0, 0, 1, -1.5) })
	local subL = new("Frame", { Parent = sub, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 20, 0.5, 0), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0,0) })
	hlist(subL, 12).VerticalAlignment = Enum.VerticalAlignment.Center
	local avatar
	if cfg.Avatar then   -- customizable image slot
		avatar = new("ImageLabel", { Parent = subL, LayoutOrder = 1, BackgroundTransparency = 1,
			Image = cfg.Avatar, Size = UDim2.fromOffset(26, 26), ScaleType = Enum.ScaleType.Crop })
	else
		avatar = new("TextLabel", { Parent = subL, LayoutOrder = 1, BackgroundTransparency = 1,
			Size = UDim2.fromOffset(26, 26), Text = cfg.AvatarText or "W", TextColor3 = INK, FontFace = bodyFont(), TextSize = 12 })
	end
	local avatarStroke = stroke(avatar, 1.5, INK); corner(avatar, 6)
	win._avatar = avatar
	local sesWrap = new("Frame", { Parent = subL, LayoutOrder = 2, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0,0) })
	hlist(sesWrap, 7).VerticalAlignment = Enum.VerticalAlignment.Center
	local dot = new("Frame", { Parent = sesWrap, LayoutOrder = 1, BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.fromOffset(7, 7) })
	tween(dot, { BackgroundTransparency = 0.7 },
		TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true))
	local ses = label(sesWrap, string.upper(tostring(cfg.SubTitle or "Session Active · Wanderer")), 11,
		Enum.FontWeight.Medium, INK)
	ses.LayoutOrder = 2
	win._ses = ses
	local subArrow = new("TextLabel", { Parent = sub, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -20, 0.5, 0), Size = UDim2.fromOffset(16, 16), Text = "→",
		TextColor3 = INK, FontFace = bodyFont(), TextSize = 16 })
	-- refs for the minimise animation: navbar shrinks, substrip inverts to ink bg / aqua ink
	win._nav, win._navL, win._sub = nav, navL, sub
	win._subBorders = { subTopB, subBotB }
	win._subInkText = { ses, subArrow }
	if avatar:IsA("TextLabel") then table.insert(win._subInkText, avatar) end
	win._subInkFill = { dot }
	win._avatarStroke = avatarStroke

	-- BODY (collapses on minimize) ----------------------------------------
	local body = new("Frame", { Parent = panel, LayoutOrder = 3, BackgroundColor3 = ACCENT,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	vlist(body, 0)
	win._body = body

	-- TAB BAR. The bottom border must live OUTSIDE the tab row's layout — a full-width border
	-- inside the horizontal layout counts as a layout item and pushes every tab off the edge.
	local tabBar = new("Frame", { Parent = body, LayoutOrder = 1, BackgroundColor3 = ACCENT,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 46) })
	new("Frame", { Parent = tabBar, BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1.5), Position = UDim2.new(0, 0, 1, -1.5) })
	-- leave the bottom 1.5px free so the tab buttons don't cover the border line
	local tabsRow = new("Frame", { Parent = tabBar, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, -1.5) })
	hlist(tabsRow, 0)
	win._tabBar = tabsRow

	-- HEADER
	local header = new("Frame", { Parent = body, LayoutOrder = 2, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	pad(header, 8, 24, 6, 24)
	local hrow = hlist(header, 12); hrow.VerticalAlignment = Enum.VerticalAlignment.Bottom
	local hL = new("Frame", { Parent = header, LayoutOrder = 1, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(0, 0, 0, 0) })
	new("UIFlexItem", { Parent = hL, FlexMode = Enum.UIFlexMode.Fill })
	vlist(hL, 2)
	local cat = label(hL, "CATEGORY — EDITING", 10, Enum.FontWeight.Medium, INK)
	cat.LayoutOrder = 1; cat.TextTransparency = 0.47
	-- Crop the Anton em-box's empty bottom (descender space): top-align + a box shorter than the
	-- font size so the caps hug the box, with no wasted vertical padding under the title.
	local bigTitle = new("TextLabel", { Parent = hL, LayoutOrder = 2, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 0, 66), Text = "",
		TextColor3 = INK, FontFace = displayFont(), TextSize = 80, ClipsDescendants = true,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	local hR = new("Frame", { Parent = header, LayoutOrder = 2, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0,0) })
	local hRl = vlist(hR, 5); hRl.HorizontalAlignment = Enum.HorizontalAlignment.Right
	local countLbl = new("TextLabel", { Parent = hR, LayoutOrder = 1, BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0,0), Text = "✳ 0 ACTIVE",
		TextColor3 = INK, FontFace = displayFont(), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right })
	local sub2 = label(hR, "TOGGLES ENABLED", 9.5, Enum.FontWeight.Medium, INK)
	sub2.LayoutOrder = 2; sub2.TextTransparency = 0.53; sub2.TextXAlignment = Enum.TextXAlignment.Right
	win._catLbl, win._bigTitle, win._countLbl = cat, bigTitle, countLbl
	-- accent bar (indented under the title)
	local barWrap = new("Frame", { Parent = body, LayoutOrder = 3, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 8) })
	new("Frame", { Parent = barWrap, BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.new(0, 200, 0, 2.5), Position = UDim2.fromOffset(24, 2) })

	-- LIST (scrolling; holds one page per tab)
	local scroll = new("ScrollingFrame", { Parent = body, LayoutOrder = 4, BackgroundTransparency = 1,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 0),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
		ScrollBarImageColor3 = INK, ScrollBarImageTransparency = 0.6,
		ScrollingDirection = Enum.ScrollingDirection.Y })
	local scrollLayout = vlist(scroll, 0)
	win._scroll = scroll
	win._scrollMaxH = LIST_H
	-- Frame height = min(content, max): a short tab hugs its content (no empty gap above the
	-- footer); a tall tab caps at max and scrolls. ScrollingFrame's own AutomaticSize ignores
	-- UISizeConstraint, so we size the frame from the layout's content size ourselves.
	local function fitScroll()
		scroll.Size = UDim2.new(1, 0, 0, math.min(scrollLayout.AbsoluteContentSize.Y, win._scrollMaxH))
	end
	scrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(fitScroll)
	win._fitScroll = fitScroll
	task.defer(fitScroll)

	-- FOOTER (static height, not AutomaticSize)
	local footer = new("Frame", { Parent = body, LayoutOrder = 5, BackgroundColor3 = ACCENT,
		BackgroundTransparency = 0, Size = UDim2.new(1, 0, 0, 48) })
	corner(footer, 4)   -- rounds the panel's BOTTOM corners (top corners hidden behind the list)
	new("Frame", { Parent = footer, BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1.5), Position = UDim2.fromScale(0, 0) })
	local footerText = cfg.Footer or ("BUILD " .. (cfg.Build or "1.0") .. " · STANDALONE")
	local fL = label(footer, tostring(footerText), 10, Enum.FontWeight.Medium, INK)
	fL.AnchorPoint = Vector2.new(0, 0.5); fL.Position = UDim2.new(0, 24, 0.5, 0); fL.TextTransparency = 0.53
	win._footerL = fL
	-- keyboard hint removed; only shows a right-side footer if you explicitly pass FooterRight
	if cfg.FooterRight then
		local fR = label(footer, tostring(cfg.FooterRight), 10, Enum.FontWeight.Medium, INK)
		fR.AnchorPoint = Vector2.new(1, 0.5); fR.Position = UDim2.new(1, -24, 0.5, 0); fR.TextXAlignment = Enum.TextXAlignment.Right
		win._footerR = fR
	end

	-- interactions ---------------------------------------------------------
	bindDrag(nav, panel, "move", function(startPos, d)
		if win._min then return end
		panel.Position = UDim2.fromOffset(startPos.X + d.X, startPos.Y + d.Y)
		win._restorePos = panel.Position
	end)
	bindDrag(moveH, panel, "move", function(startPos, d)
		if win._min then return end
		panel.Position = UDim2.fromOffset(startPos.X + d.X, startPos.Y + d.Y)
		win._restorePos = panel.Position
	end)
	-- Resize: capture the LIVE width + list height at grab time. Using the constant LIST_H as
	-- the baseline made a second drag snap the list back to 352 (the "footer expands" jump).
	do
		local dragging, startInput, startW, startH
		resizeH.InputBegan:Connect(function(i)
			if win._min then return end
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true; startInput = i.Position
				startW = panel.AbsoluteSize.X; startH = win._scrollMaxH
				i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if not dragging then return end
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				local d = i.Position - startInput
				panel.Size = UDim2.new(0, math.clamp(startW + d.X, 560, 1000), 0, 0)
				win._scrollMaxH = math.clamp(startH + d.Y, 200, 560); win._fitScroll()
			end
		end)
	end
	burger.MouseButton1Click:Connect(function() win:_toggleMin() end)

	-- toggle-menu hotkey
	win._key = cfg.ToggleKey or Enum.KeyCode.F4
	UserInputService.InputBegan:Connect(function(i, gpe)
		if gpe then return end
		if i.KeyCode == win._key then panel.Visible = not panel.Visible end
	end)

	-- initial state (Minimized = true starts collapsed) + slide-down entry with ease-out --------
	win._restorePos = UDim2.fromOffset(60, 60)   -- where the maximized panel rests
	local restPos = win._restorePos
	if cfg.Minimized then
		win._min = true
		body.Visible = false
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UDim2.new(1, 0, 0, 0)
		panel.Size = UDim2.new(0, 392, 0, 0)
		win:_setMinStyle(true, TweenInfo.new(0))   -- apply minimized styling instantly
		local vpx = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize.X) or 1280
		restPos = UDim2.fromOffset(math.floor((vpx - 392) / 2), 20)
	end
	panel.Position = UDim2.fromOffset(restPos.X.Offset, restPos.Y.Offset - 64)   -- start above the rest spot
	tween(panel, { Position = restPos }, TweenInfo.new(0.55, Enum.EasingStyle.Quint, Enum.EasingDirection.Out))

	return win
end

function NEON:_setMinStyle(min, ti)
	local ink = min and ACCENT or INK   -- substrip text/fill flips ink <-> aqua
	tween(self._nav, { Size = UDim2.new(1, 0, 0, min and 48 or 64) }, ti)          -- title padding shrinks
	tween(self._navL, { Position = UDim2.new(0, min and 22 or 36, 0.5, 0) }, ti)
	tween(self._sub, { BackgroundColor3 = min and INK or ACCENT,
		Size = UDim2.new(1, 0, 0, min and 40 or 48) }, ti)                         -- substrip inverts colour
	for _, b in ipairs(self._subBorders) do tween(b, { BackgroundTransparency = min and 1 or 0 }, ti) end
	for _, e in ipairs(self._subInkText) do tween(e, { TextColor3 = ink }, ti) end
	for _, e in ipairs(self._subInkFill) do tween(e, { BackgroundColor3 = ink }, ti) end
	tween(self._avatarStroke, { Color = ink }, ti)
end

function NEON:_toggleMin()
	local panel, body = self._panel, self._body
	self._min = not self._min
	local DUR = 0.34
	local EASE = TweenInfo.new(DUR, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out)
	self:_setMinStyle(self._min, EASE)
	if self._min then
		-- accordion: freeze the body's live height, then tween it shut (panel auto-follows)
		self._bodyH = body.AbsoluteSize.Y
		body.AutomaticSize = Enum.AutomaticSize.None
		body.ClipsDescendants = true
		body.Size = UDim2.new(1, 0, 0, self._bodyH)
		tween(body, { Size = UDim2.new(1, 0, 0, 0) }, EASE)
		local w = 392
		self._restorePos = self._restorePos or panel.Position
		tween(panel, { Size = UDim2.new(0, w, 0, 0),
			Position = UDim2.fromOffset(math.floor((panel.Parent.AbsoluteSize.X - w) / 2), 20) }, EASE)
		task.delay(DUR, function() if self._min then body.Visible = false end end)
	else
		body.ClipsDescendants = true
		local targetH = self._bodyH
		if not targetH or targetH <= 0 then   -- never captured (e.g. started minimized): measure it
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.Size = UDim2.new(1, 0, 0, 0)
			task.wait()
			targetH = body.AbsoluteSize.Y
		end
		body.AutomaticSize = Enum.AutomaticSize.None
		body.Size = UDim2.new(1, 0, 0, 0)
		body.Visible = true
		self._bodyH = targetH
		tween(body, { Size = UDim2.new(1, 0, 0, targetH) }, EASE)  -- accordion open
		tween(panel, { Size = UDim2.new(0, 772, 0, 0), Position = self._restorePos }, EASE)
		task.delay(DUR, function()
			if not self._min then body.AutomaticSize = Enum.AutomaticSize.Y; body.ClipsDescendants = false end
		end)
	end
end

function NEON:_refreshCount()
	local n = 0
	for _, on in pairs(self._toggleStates) do if on then n += 1 end end
	self._countLbl.Text = "✳ " .. n .. " ACTIVE"
end

function NEON:_selectTab(tab)
	self._activeTab = tab
	if self._openDropdown then self._openDropdown.Visible = false end
	for _, tb in ipairs(self._tabs) do
		tb._page.Visible = (tb == tab)
		if tb._refresh then tb._refresh() end
	end
	self._bigTitle.Text = string.upper(tab._title)
	self._catLbl.Text = "CATEGORY — " .. string.upper(tab._title)
	if self._fitScroll then task.defer(self._fitScroll) end
end

-- Runtime customisation ------------------------------------------------------
function NEON:SetTitle(text)
	if self._title then self._title.Text = string.upper(tostring(text)); self._title.Parent.Visible = (self._title.Text ~= "") end
end
function NEON:SetSubTitle(text) if self._ses then self._ses.Text = string.upper(tostring(text)) end end
function NEON:SetFooter(text) if self._footerL then self._footerL.Text = tostring(text) end end
function NEON:SetIcon(image) if self._icon then self._icon.Image = image end end
function NEON:SetAvatarImage(image) if self._avatar and self._avatar:IsA("ImageLabel") then self._avatar.Image = image end end

-- Config save/load (executor filesystem) -------------------------------------
function NEON:_cfgPath(name) return "NEON_" .. tostring(name or self._configName or "default") .. ".json" end
function NEON:SaveConfig(name)
	local HttpService = game:GetService("HttpService")
	local data = {}
	for k, f in pairs(self._flags) do local ok, v = pcall(f.get); if ok then data[k] = v end end
	return pcall(function() writefile(self:_cfgPath(name), HttpService:JSONEncode(data)) end)
end
function NEON:LoadConfig(name)
	local HttpService = game:GetService("HttpService")
	local path = self:_cfgPath(name)
	local ok, data = pcall(function() if isfile and isfile(path) then return HttpService:JSONDecode(readfile(path)) end end)
	if ok and type(data) == "table" then
		self._loading = true
		for k, v in pairs(data) do local f = self._flags[k]; if f then pcall(f.set, v) end end
		self._loading = false
		return true
	end
	return false
end
function NEON:_dirty()
	if not self._configName or self._loading then return end
	self._pendingSave = true
	if self._saving then return end
	self._saving = true
	task.delay(0.4, function()
		self._saving = false
		if self._pendingSave then self._pendingSave = false; self:SaveConfig() end
	end)
end

------------------------------------------------------------------- Tab
local Tab = {}
Tab.__index = Tab

function NEON:CreateTab(cfg)
	cfg = cfg or {}
	local win = self
	local page = new("Frame", { Parent = win._scroll, BackgroundTransparency = 1, Visible = false,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	vlist(page, 0)
	local btn = new("TextButton", { Parent = win._tabBar, BackgroundColor3 = ACCENT, BorderSizePixel = 0,
		Text = "", Size = UDim2.new(1, 0, 1, 0), AutoButtonColor = false })
	-- visible divider between tabs so 5 buttons read as 5 buttons (not one cyan bar)
	new("Frame", { Parent = btn, BackgroundColor3 = INK, BackgroundTransparency = 0.6, BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0) })
	local lbl = new("TextLabel", { Parent = btn, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Text = string.upper(cfg.Title or "TAB"), TextColor3 = INK, FontFace = bodyFont(Enum.FontWeight.ExtraBold),
		TextSize = 12 })

	local tab = setmetatable({ _win = win, _page = page, _btn = btn, _lbl = lbl, _title = cfg.Title or "TAB" }, Tab)
	-- Single source of truth for the tab colour so hover + select never fight each other.
	-- Cancel the in-flight tween first, else a hover tween can override the select colour.
	local function refresh()
		local active = win._activeTab == tab
		local target = active and INK or (tab._hover and ACCENT:Lerp(INK, 0.16) or ACCENT)
		if tab._ctween then tab._ctween:Cancel() end
		tab._ctween = TweenService:Create(btn, TWEEN, { BackgroundColor3 = target })
		tab._ctween:Play()
		lbl.TextColor3 = active and ACCENT or INK
	end
	tab._refresh = refresh
	btn.MouseButton1Click:Connect(function() win:_selectTab(tab) end)
	btn.MouseEnter:Connect(function() tab._hover = true; refresh() end)
	btn.MouseLeave:Connect(function() tab._hover = false; refresh() end)
	table.insert(win._tabs, tab)
	-- Equal-width tabs via scale. (UIFlexItem Fill collapses to 0 when EVERY sibling is Fill,
	-- so we size explicitly and re-split on each new tab.)
	local n = #win._tabs
	for _, tb in ipairs(win._tabs) do tb._btn.Size = UDim2.new(1 / n, 0, 1, 0) end
	if #win._tabs == 1 then win:_selectTab(tab) end
	return tab
end
NEON.Tab = NEON.CreateTab

------------------------------------------------------------------- controls
function Tab:Toggle(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local id = cfg.Title
	local on = cfg.Default and true or false
	win._toggleStates[id] = on
	local track = new("TextButton", { Parent = ctrl, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		Size = UDim2.fromOffset(58, 28), BackgroundColor3 = INK, BackgroundTransparency = on and 0 or 1 })
	stroke(track, 1.5, INK); corner(track, 999)
	local knob = new("Frame", { Parent = track, BorderSizePixel = 0, Size = UDim2.fromOffset(20, 20),
		Position = UDim2.fromOffset(on and 33 or 3, 3), BackgroundColor3 = on and ACCENT or INK })
	corner(knob, 999)
	local function render()
		track.BackgroundTransparency = on and 0 or 1
		tween(knob, { Position = UDim2.fromOffset(on and 33 or 3, 3), BackgroundColor3 = on and ACCENT or INK })
		win._toggleStates[id] = on; win:_refreshCount()
	end
	track.MouseButton1Click:Connect(function()
		on = not on; render()
		if cfg.Callback then task.spawn(cfg.Callback, on) end
	end)
	win:_refreshCount()
	local api = { Set = function(_, v) on = v and true or false; render() end, Get = function() return on end }
	bindFlag(win, cfg, function() return on end, function(v) api:Set(v) end)
	return api
end

function Tab:Checkbox(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local on = cfg.Default and true or false
	local box = new("TextButton", { Parent = ctrl, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		BackgroundTransparency = 1, Size = UDim2.fromOffset(26, 26) })
	stroke(box, 1.5, INK); corner(box, 4)
	local fill = new("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(14, 14), BackgroundColor3 = INK, BackgroundTransparency = on and 0 or 1, BorderSizePixel = 0 })
	corner(fill, 3)
	box.MouseButton1Click:Connect(function()
		on = not on; fill.BackgroundTransparency = on and 0 or 1
		if cfg.Callback then task.spawn(cfg.Callback, on) end
	end)
	local api = { Set = function(_, v) on = v and true or false; fill.BackgroundTransparency = on and 0 or 1 end,
		Get = function() return on end }
	bindFlag(win, cfg, function() return on end, function(v) api:Set(v) end)
	return api
end

function Tab:Slider(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local min, max, step = cfg.Min or 0, cfg.Max or 100, cfg.Step or 1
	local value = math.clamp(cfg.Default or min, min, max)
	local holder = new("Frame", { Parent = ctrl, BackgroundTransparency = 1, Size = UDim2.fromOffset(250, 24) })
	hlist(holder, 14).VerticalAlignment = Enum.VerticalAlignment.Center
	local track = new("TextButton", { Parent = holder, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		BackgroundColor3 = INK, BackgroundTransparency = 0.72, Size = UDim2.new(1, -68, 0, 4) })
	new("UIFlexItem", { Parent = track, FlexMode = Enum.UIFlexMode.Fill }); corner(track, 999)
	local fill = new("Frame", { Parent = track, BackgroundColor3 = INK, BorderSizePixel = 0,
		Size = UDim2.new((value - min) / (max - min), 0, 1, 0) }); corner(fill, 999)
	local knob = new("Frame", { Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), BorderSizePixel = 0,
		Position = UDim2.new((value - min) / (max - min), 0, 0.5, 0), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = INK }); corner(knob, 999)
	local valLbl = new("TextLabel", { Parent = holder, BackgroundTransparency = 1, Size = UDim2.fromOffset(54, 20),
		Text = value .. (cfg.Unit or ""), TextColor3 = INK, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Right })
	local function apply(v)
		value = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
		local f = (value - min) / (max - min)
		fill.Size = UDim2.new(f, 0, 1, 0); knob.Position = UDim2.new(f, 0, 0.5, 0)
		valLbl.Text = value .. (cfg.Unit or "")
		if cfg.Callback then task.spawn(cfg.Callback, value) end
	end
	local dragging
	local function fromX(x) apply(min + (max - min) * math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)) end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true; fromX(i.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			fromX(i.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	local api = { Set = function(_, v) apply(v) end, Get = function() return value end }
	bindFlag(win, cfg, function() return value end, function(v) api:Set(v) end)
	return api
end

function Tab:Input(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local box = new("TextBox", { Parent = ctrl, Size = UDim2.fromOffset(210, 36), BackgroundTransparency = 1,
		Text = string.upper(tostring(cfg.Default or "")), PlaceholderText = string.upper(cfg.Placeholder or ""),
		TextColor3 = INK, PlaceholderColor3 = INK, ClearTextOnFocus = false, FontFace = bodyFont(),
		TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left })
	stroke(box, 1.5, INK); corner(box, 4); pad(box, 9, 11, 9, 11)
	box.FocusLost:Connect(function()
		box.Text = string.upper(box.Text)
		if cfg.Callback then task.spawn(cfg.Callback, box.Text) end
	end)
	local api = { Set = function(_, v) box.Text = string.upper(tostring(v)) end, Get = function() return box.Text end }
	bindFlag(win, cfg, function() return box.Text end, function(v) api:Set(v) end)
	return api
end

function Tab:Keybind(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local key = tostring(cfg.Default or "NONE")
	local btn = new("TextButton", { Parent = ctrl, AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, Text = "[ " .. key .. " ]",
		TextColor3 = INK, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 12 })
	stroke(btn, 1.5, INK); corner(btn, 4); pad(btn, 10, 14, 10, 14)
	local capturing
	btn.MouseButton1Click:Connect(function()
		capturing = true; btn.Text = "PRESS ANY KEY…"; btn.BackgroundTransparency = 0
		btn.BackgroundColor3 = INK; btn.TextColor3 = ACCENT
	end)
	UserInputService.InputBegan:Connect(function(i, gpe)
		if not capturing or gpe then return end
		if i.KeyCode ~= Enum.KeyCode.Unknown then
			capturing = false; key = i.KeyCode.Name
			btn.Text = "[ " .. string.upper(key) .. " ]"; btn.BackgroundTransparency = 1; btn.TextColor3 = INK
			if cfg.Callback then task.spawn(cfg.Callback, i.KeyCode) end
		end
	end)
	local function setKey(v) key = tostring(v); btn.Text = "[ " .. string.upper(key) .. " ]" end
	local api = { Set = function(_, v) setKey(v) end, Get = function() return key end }
	bindFlag(win, cfg, function() return key end, function(v) setKey(v) end)
	return api
end

function Tab:Segmented(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local value = cfg.Default or (cfg.Options and cfg.Options[1])
	local group = new("Frame", { Parent = ctrl, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 36), ClipsDescendants = true })
	stroke(group, 1.5, INK); corner(group, 4); hlist(group, 0)
	local buttons = {}
	local function render()
		for opt, b in pairs(buttons) do
			local a = opt == value
			b.bg.BackgroundColor3 = INK; b.bg.BackgroundTransparency = a and 0 or 1
			b.lbl.TextColor3 = a and ACCENT or INK
		end
	end
	for i, opt in ipairs(cfg.Options or {}) do
		local b = new("TextButton", { Parent = group, LayoutOrder = i, AutoButtonColor = false, BorderSizePixel = 0,
			BackgroundColor3 = INK, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0), Text = "" })
		if i > 1 then new("Frame", { Parent = b, BackgroundColor3 = INK, BackgroundTransparency = 0.73,
			BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0) }) end
		local l = new("TextLabel", { Parent = b, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0), Text = string.upper(opt), TextColor3 = INK,
			FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 11 })
		pad(l, 9, 11, 9, 11)
		buttons[opt] = { bg = b, lbl = l }
		b.MouseButton1Click:Connect(function()
			value = opt; render()
			if cfg.Callback then task.spawn(cfg.Callback, opt) end
		end)
	end
	render()
	local api = { Set = function(_, v) value = v; render() end, Get = function() return value end }
	bindFlag(win, cfg, function() return value end, function(v) api:Set(v) end)
	return api
end

function Tab:Dropdown(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local value = cfg.Default or (cfg.Options and cfg.Options[1])
	local btn = new("TextButton", { Parent = ctrl, AutoButtonColor = false, BackgroundTransparency = 1,
		Size = UDim2.fromOffset(190, 38), Text = "", BorderSizePixel = 0 })
	stroke(btn, 1.5, INK); corner(btn, 4)
	local vlbl = new("TextLabel", { Parent = btn, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(1, -34, 1, 0), Text = string.upper(value or ""),
		TextColor3 = INK, FontFace = bodyFont(), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
	new("TextLabel", { Parent = btn, BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -13, 0.5, 0), Size = UDim2.fromOffset(12, 12), Text = "▼", TextColor3 = INK,
		FontFace = bodyFont(), TextSize = 10 })
	-- overlay list, parented to the ScreenGui so neither the scroll nor the panel clips it
	local menu = new("Frame", { Parent = win._gui, Visible = false, ZIndex = 60, BackgroundColor3 = ACCENT,
		BorderSizePixel = 0, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.fromOffset(190, 0), Active = true })
	stroke(menu, 1.5, INK).ZIndex = 60; corner(menu, 4)
	vlist(menu, 0)
	local function close() menu.Visible = false end
	for i, opt in ipairs(cfg.Options or {}) do
		local ob = new("TextButton", { Parent = menu, LayoutOrder = i, AutoButtonColor = false, ZIndex = 61,
			BackgroundColor3 = INK, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30),
			Text = string.upper(opt), TextColor3 = INK, FontFace = bodyFont(), TextSize = 12 })
		ob.MouseEnter:Connect(function() ob.BackgroundTransparency = 0.85 end)
		ob.MouseLeave:Connect(function() ob.BackgroundTransparency = 1 end)
		ob.MouseButton1Click:Connect(function()
			value = opt; vlbl.Text = string.upper(opt); close()
			if cfg.Callback then task.spawn(cfg.Callback, opt) end
		end)
	end
	btn.MouseButton1Click:Connect(function()
		if win._openDropdown and win._openDropdown ~= menu then win._openDropdown.Visible = false end
		if menu.Visible then close(); return end
		local ap = btn.AbsolutePosition
		menu.Position = UDim2.fromOffset(ap.X, ap.Y + btn.AbsoluteSize.Y + 4)
		menu.Size = UDim2.fromOffset(btn.AbsoluteSize.X, 0)
		menu.Visible = true; win._openDropdown = menu
	end)
	local api = { Set = function(_, v) value = v; vlbl.Text = string.upper(v) end, Get = function() return value end }
	bindFlag(win, cfg, function() return value end, function(v) api:Set(v) end)
	return api
end

-- Colour picker: pick from preset swatches. Override the set with Swatches = { "RRGGBB", ... }.
function Tab:Colorpicker(cfg)
	local win = self._win
	autosaveCb(win, cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local swatches = cfg.Swatches or { "A8D8EA", "EAA8D8", "C9A8EA", "A8EAB6", "EAD8A8" }
	local value = cfg.Default or swatches[1]
	local row = new("Frame", { Parent = ctrl, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 30) })
	hlist(row, 10).VerticalAlignment = Enum.VerticalAlignment.Center
	local btns = {}
	local function render()
		for hex, b in pairs(btns) do
			local a = hex == value
			b.stroke.Transparency = a and 0 or 0.8; b.stroke.Thickness = a and 2.5 or 2
		end
	end
	for i, hex in ipairs(swatches) do
		local b = new("TextButton", { Parent = row, LayoutOrder = i, AutoButtonColor = false, Text = "",
			BorderSizePixel = 0, Size = UDim2.fromOffset(30, 30), BackgroundColor3 = Color3.fromHex(hex) })
		local st = stroke(b, 2, INK); corner(b, 4)
		btns[hex] = { btn = b, stroke = st }
		b.MouseButton1Click:Connect(function()
			value = hex; render()
			if cfg.Callback then task.spawn(cfg.Callback, Color3.fromHex(hex)) end
		end)
	end
	render()
	local api = {
		Set = function(_, c) value = (typeof(c) == "Color3") and c:ToHex() or tostring(c); render() end,
		Get = function() return Color3.fromHex(value) end,
	}
	bindFlag(win, cfg, function() return value end, function(hex) value = tostring(hex); render() end)
	return api
end

function Tab:Button(cfg)
	local _, left, top, ctrl = makeRow(self._page)
	addLabelAndBadge(top, cfg); addDesc(left, cfg)
	local btn = new("TextButton", { Parent = ctrl, AutoButtonColor = false, BackgroundColor3 = INK, BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 42), Text = "" })
	corner(btn, 4); pad(btn, 12, 22, 12, 22)
	local wrap = new("Frame", { Parent = btn, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(0,0) })
	hlist(wrap, 10).VerticalAlignment = Enum.VerticalAlignment.Center
	local l = label(wrap, string.upper(cfg.Text or "EXECUTE"), 13, Enum.FontWeight.ExtraBold, ACCENT); l.LayoutOrder = 1
	local a = label(wrap, "→", 15, Enum.FontWeight.ExtraBold, ACCENT); a.LayoutOrder = 2
	btn.MouseButton1Click:Connect(function()
		self._win:Notify(cfg.Title .. " — Executed")
		if cfg.Callback then task.spawn(cfg.Callback) end
	end)
	return btn
end

-- Section header: a divider line + small bar + uppercase label to group controls.
function Tab:Section(cfg)
	local title = (type(cfg) == "table" and (cfg.Title or "")) or tostring(cfg or "")
	local sec = new("Frame", { Parent = self._page, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	vlist(sec, 0)
	new("Frame", { Parent = sec, LayoutOrder = 1, BackgroundColor3 = INK, BackgroundTransparency = 0.78,
		BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) })
	local inner = new("Frame", { Parent = sec, LayoutOrder = 2, BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	pad(inner, 15, 24, 7, 24)
	hlist(inner, 9).VerticalAlignment = Enum.VerticalAlignment.Center
	new("Frame", { Parent = inner, LayoutOrder = 1, BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromOffset(16, 2.5) })
	local l = label(inner, string.upper(title), 11, Enum.FontWeight.ExtraBold, INK)
	l.LayoutOrder = 2; l.TextTransparency = 0.15
	return sec
end

------------------------------------------------------------------- Notify / toast
function NEON:Notify(text)
	local gui = self._gui
	local toast = new("Frame", { Parent = self._panel.Parent, BackgroundColor3 = ACCENT, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -30, 1, -30), AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 46), ZIndex = 200 })
	stroke(toast, 1.5, INK).ZIndex = 200; corner(toast, 10)
	local wrap = new("Frame", { Parent = toast, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0), ZIndex = 201 })
	hlist(wrap, 12).VerticalAlignment = Enum.VerticalAlignment.Center
	pad(wrap, 0, 20, 0, 20)
	local star = label(wrap, "✳", 16, Enum.FontWeight.ExtraBold, INK); star.LayoutOrder = 1; star.ZIndex = 201
	local l = label(wrap, string.upper(text), 13, Enum.FontWeight.ExtraBold, INK); l.LayoutOrder = 2; l.ZIndex = 201
	toast.Position = UDim2.new(1, -30, 1, -16)
	tween(toast, { Position = UDim2.new(1, -30, 1, -30) }, TweenInfo.new(0.18, Enum.EasingStyle.Back))
	task.delay(1.7, function()
		if toast and toast.Parent then
			tween(toast, { Position = UDim2.new(1, -30, 1, 0) }, TWEEN)
			task.wait(0.2); toast:Destroy()
		end
	end)
end

return setmetatable({}, { __index = NEON, __call = function(_, cfg) return NEON:CreateWindow(cfg) end })
