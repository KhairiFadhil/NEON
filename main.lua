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
	-- responsive zoom: the resize grip drives this, scaling all content (fonts, spacing, controls)
	win._scale = new("UIScale", { Parent = panel, Scale = cfg.Scale or 1 })

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
		-- when maximized and not mid-accordion: the body must auto-size so it shrinks with the
		-- list. Force it back if an interrupted accordion left it fixed (the stuck-tall-height /
		-- footer-gap bug), then keep the list height matched to the active tab's content.
		if not win._min and not win._accordion then
			local b = win._body
			-- AutomaticSize treats Size.Offset as a MINIMUM, so the accordion's leftover fixed
			-- height pins the body tall. Clear it so the body shrinks to its content.
			if b and (b.AutomaticSize ~= Enum.AutomaticSize.Y or b.Size.Y.Offset ~= 0) then
				b.AutomaticSize = Enum.AutomaticSize.Y
				b.Size = UDim2.new(1, 0, 0, 0)
				b.ClipsDescendants = false
			end
			if win._fitScroll then win._fitScroll() end
		end
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
	avatar.Visible = cfg.ShowAvatar ~= false   -- ShowAvatar = false hides the "W"/image slot
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
		-- AbsoluteContentSize is screen pixels (scaled by the panel UIScale); scroll.Size.Offset is
		-- LOCAL/unscaled. De-scale it, else the frame is over-sized after a zoom and leaves a gap
		-- above the footer when a short tab follows a tall one.
		local contentH = scrollLayout.AbsoluteContentSize.Y / math.max(win._scale.Scale, 0.01)
		scroll.Size = UDim2.new(1, 0, 0, math.min(contentH, win._scrollMaxH))
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
	win._footer, win._footerL = footer, fL
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
		local dragging, startInput, startScale
		resizeH.InputBegan:Connect(function(i)
			if win._min then return end
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true; startInput = i.Position; startScale = win._scale.Scale
				i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if not dragging then return end
			if i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch then
				local d = i.Position - startInput
				win._scale.Scale = math.clamp(startScale + (d.X + d.Y) / 1500, 0.6, 1.8)  -- uniform responsive zoom
			end
		end)
	end
	burger.MouseButton1Click:Connect(function() win:_toggleMin() end)

	-- toggle-menu hotkey
	win._key = cfg.ToggleKey or Enum.KeyCode.F4
	UserInputService.InputBegan:Connect(function(i, gpe)
		if gpe then return end
		if i.KeyCode == win._key then
			panel.Visible = not panel.Visible
			if not panel.Visible and win._closePopup then win._closePopup(); win._openDropdown = nil; win._closePopup = nil end
		end
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
	if self._closePopup then self._closePopup(); self._openDropdown = nil; self._closePopup = nil end
	self._accordion = true   -- suppress the Heartbeat's body auto-size restore while animating
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
		local dispW = w * self._scale.Scale   -- centred using the on-screen (scaled) width
		tween(panel, { Size = UDim2.new(0, w, 0, 0),
			Position = UDim2.fromOffset(math.floor((panel.Parent.AbsoluteSize.X - dispW) / 2), 20) }, EASE)
		task.delay(DUR, function() if self._min then body.Visible = false end; self._accordion = false end)
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
			if not self._min then body.AutomaticSize = Enum.AutomaticSize.Y; body.Size = UDim2.new(1, 0, 0, 0); body.ClipsDescendants = false end
			self._accordion = false
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
	if self._openDropdown then
		if self._closePopup then self._closePopup() else self._openDropdown.Visible = false end
		self._openDropdown = nil; self._closePopup = nil
	end
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
-- Live-updatable right footer (e.g. a countdown). Created lazily if it wasn't passed at build time.
function NEON:SetFooterRight(text)
	if self._footerR then
		self._footerR.Text = tostring(text)
	elseif self._footer then
		local fR = label(self._footer, tostring(text), 10, Enum.FontWeight.Medium, INK)
		fR.AnchorPoint = Vector2.new(1, 0.5); fR.Position = UDim2.new(1, -24, 0.5, 0)
		fR.TextXAlignment = Enum.TextXAlignment.Right
		self._footerR = fR
	end
end
function NEON:SetIcon(image) if self._icon then self._icon.Image = image end end
function NEON:SetAvatarImage(image) if self._avatar and self._avatar:IsA("ImageLabel") then self._avatar.Image = image end end
function NEON:SetAvatarVisible(v) if self._avatar then self._avatar.Visible = v and true or false end end

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

	-- button: no outline, subtle fill + hover tint
	local btn = new("TextButton", { Parent = ctrl, AutoButtonColor = false, BorderSizePixel = 0,
		Size = UDim2.fromOffset(190, 38), Text = "", BackgroundColor3 = INK, BackgroundTransparency = 0.9 })
	corner(btn, 6)
	local vlbl = new("TextLabel", { Parent = btn, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.new(1, -34, 1, 0), Text = string.upper(value or ""),
		TextColor3 = INK, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left })
	local arrow = new("TextLabel", { Parent = btn, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -13, 0.5, 0), Size = UDim2.fromOffset(12, 12), Text = "▼", TextColor3 = INK,
		FontFace = bodyFont(), TextSize = 10 })

	-- soft shadow behind the popup (no outline anywhere)
	local shadow = new("ImageLabel", { Parent = win._gui, Visible = false, ZIndex = 59, BackgroundTransparency = 1,
		Image = "rbxassetid://6014261993", ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 1,
		ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450) })
	-- scrollable menu: capped height, scrolls when there are lots of options (MaxHeight overrides)
	local optionH, maxDH = 30, (cfg.MaxHeight or 180)
	local menuH = math.min(#(cfg.Options or {}) * optionH + 8, maxDH)
	local menu = new("ScrollingFrame", { Parent = win._gui, Visible = false, ZIndex = 60, BackgroundColor3 = ACCENT,
		BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(190, menuH),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = INK, ScrollBarImageTransparency = 0.5,
		ScrollingDirection = Enum.ScrollingDirection.Y, Active = true })
	corner(menu, 6)
	local scl = new("UIScale", { Parent = menu, Scale = 0.96 })
	vlist(menu, 0); pad(menu, 4, 0, 4, 0)

	local opts, isOpen, followConn = {}, false, nil
	local T = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local SH = 16

	local function positionAt()
		if not btn.Parent then return end
		-- Menu + shadow are ScreenGui children, so use GUI-LOCAL coords (panel.Position is local;
		-- add the button's offset within the panel). Using AbsolutePosition double-counts the
		-- ScreenGui's own offset and drifts the shadow away from the menu.
		local p = win._panel
		local bx = p.Position.X.Offset + (btn.AbsolutePosition.X - p.AbsolutePosition.X)
		local by = p.Position.Y.Offset + (btn.AbsolutePosition.Y - p.AbsolutePosition.Y) + btn.AbsoluteSize.Y + 6
		menu.Position = UDim2.fromOffset(bx, by)
		menu.Size = UDim2.fromOffset(btn.Size.X.Offset, menuH)   -- base width + capped height; UIScale matches the button
		shadow.Position = UDim2.fromOffset(bx - SH, by - SH)
		shadow.Size = UDim2.fromOffset(menu.AbsoluteSize.X + SH * 2, menu.AbsoluteSize.Y + SH * 2)
	end
	local function fade(hidden)
		tween(menu, { BackgroundTransparency = hidden and 1 or 0 }, T)
		tween(shadow, { ImageTransparency = hidden and 1 or 0.55 }, T)
		for _, ob in ipairs(opts) do tween(ob, { TextTransparency = hidden and 1 or 0 }, T) end
	end
	local function close()
		if not isOpen then return end
		isOpen = false
		if followConn then followConn:Disconnect(); followConn = nil end
		fade(true)
		tween(scl, { Scale = win._scale.Scale * 0.96 }, T); tween(arrow, { Rotation = 0 }, T); tween(btn, { BackgroundTransparency = 0.9 }, T)
		task.delay(0.2, function() if not isOpen then menu.Visible = false; shadow.Visible = false end end)
	end

	for i, opt in ipairs(cfg.Options or {}) do
		local ob = new("TextButton", { Parent = menu, LayoutOrder = i, AutoButtonColor = false, ZIndex = 61,
			BackgroundColor3 = INK, BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 30),
			Text = string.upper(opt), TextColor3 = INK, TextTransparency = 1, FontFace = bodyFont(), TextSize = 12 })
		opts[#opts + 1] = ob
		ob.MouseEnter:Connect(function() if isOpen then tween(ob, { BackgroundTransparency = 0.85 }) end end)
		ob.MouseLeave:Connect(function() tween(ob, { BackgroundTransparency = 1 }) end)
		ob.MouseButton1Click:Connect(function()
			value = opt; vlbl.Text = string.upper(opt); close()
			if cfg.Callback then task.spawn(cfg.Callback, opt) end
		end)
	end

	local function open()
		isOpen = true
		local vs = win._scale.Scale            -- match the panel's responsive zoom
		scl.Scale = vs * 0.96
		menu.Visible = true; shadow.Visible = true
		positionAt(); task.defer(positionAt)
		fade(false)
		tween(scl, { Scale = vs }, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		tween(arrow, { Rotation = 180 }, T); tween(btn, { BackgroundTransparency = 0.82 }, T)
		followConn = RunService.RenderStepped:Connect(positionAt)   -- follow the panel while open
		win._openDropdown = menu; win._closePopup = close
	end

	btn.MouseEnter:Connect(function() if not isOpen then tween(btn, { BackgroundTransparency = 0.82 }) end end)
	btn.MouseLeave:Connect(function() if not isOpen then tween(btn, { BackgroundTransparency = 0.9 }) end end)
	btn.MouseButton1Click:Connect(function()
		if win._closePopup and win._openDropdown ~= menu then win._closePopup(); win._openDropdown = nil; win._closePopup = nil end
		if isOpen then close() else open() end
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

-- Key / login page: brand panel + license-key form + success overlay.
--   Callback(key) -> boolean   (validates the key; may block on an HttpGet)
--   OnSuccess()                (runs once the key is accepted — build your menu here)
function NEON:CreateKeyPage(cfg)
	cfg = cfg or {}
	local DARK, LIGHT = Color3.fromHex("0C0C0C"), Color3.fromHex("EDEDED")
	local RED, GRN = Color3.fromHex("EAA8A8"), Color3.fromHex("A8EAB6")
	local GREY = Color3.fromRGB(120, 120, 120)
	local gui = mountRoot()

	local hwid = cfg.HWID
	if not hwid then
		local ok, id = pcall(function() return (gethwid and gethwid()) or game:GetService("RbxAnalyticsService"):GetClientId() end)
		hwid = tostring((ok and id) or "UNKNOWN-HWID")
	end
	local function spacer(parent, h, lo) return new("Frame", { Parent = parent, LayoutOrder = lo, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, h) }) end

	-- CanvasGroup lets the whole card (+ shadow) fade at once for the show/hide animation
	local root = new("CanvasGroup", { Parent = gui, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(960, 760), GroupTransparency = 1 })
	local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
	local fit = math.min(1, (vp.X - 40) / 760, (vp.Y - 40) / 560)
	local uiscale = new("UIScale", { Parent = root, Scale = fit * 0.9 })
	-- soft drop shadow — same 9-slice, margin (34/side) and intensity as the menu
	new("ImageLabel", { Parent = root, BackgroundTransparency = 1, ZIndex = 0, Image = "rbxassetid://6014261993",
		ImageColor3 = Color3.new(0, 0, 0), ImageTransparency = 0.76, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(49, 49, 450, 450),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760 + 68, 560 + 68) })
	local card = new("Frame", { Parent = root, BackgroundColor3 = DARK, ZIndex = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 560), ClipsDescendants = true, Active = true })
	corner(card, 4)
	hlist(card, 0)
	-- show: pop + fade in.  exit(cb): shrink + fade out, then cb()
	tween(uiscale, { Scale = fit }, TweenInfo.new(0.42, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
	tween(root, { GroupTransparency = 0 }, TweenInfo.new(0.28, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	local function exit(cb)
		tween(uiscale, { Scale = fit * 0.92 }, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		tween(root, { GroupTransparency = 1 }, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
		task.delay(0.24, function() if cb then cb() end end)
	end

	-- LEFT brand panel ------------------------------------------------------
	local left = new("Frame", { Parent = card, LayoutOrder = 1, BackgroundColor3 = ACCENT, Size = UDim2.new(0, 290, 1, 0), ClipsDescendants = true })
	local ltop = new("Frame", { Parent = left, BackgroundTransparency = 1, ZIndex = 2, AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.fromOffset(30, 34), Size = UDim2.new(1, -60, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	vlist(ltop, 0)
	local logoRow = new("Frame", { Parent = ltop, LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	hlist(logoRow, 11).VerticalAlignment = Enum.VerticalAlignment.Center
	local lbox = new("TextLabel", { Parent = logoRow, LayoutOrder = 1, BackgroundColor3 = INK, Size = UDim2.fromOffset(34, 34),
		Text = string.sub(cfg.Brand or "MODKIT", 1, 1), TextColor3 = ACCENT, FontFace = displayFont(), TextSize = 19 })
	corner(lbox, 8)
	local blab = label(logoRow, string.upper(cfg.Brand or "MODKIT"), 16, Enum.FontWeight.Heavy, INK); blab.LayoutOrder = 2
	spacer(ltop, 34, 2)
	new("TextLabel", { Parent = ltop, LayoutOrder = 3, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y,
		Size = UDim2.new(1, 0, 0, 0), Text = string.upper(cfg.Title or "KEY\nSYSTEM"), FontFace = displayFont(), TextSize = 54,
		TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
	spacer(ltop, 14, 4)
	local sub = label(ltop, string.upper(cfg.Subtitle or "Authenticate your license to unlock the loader."), 11, Enum.FontWeight.Bold, INK)
	sub.LayoutOrder = 5; sub.Size = UDim2.new(1, 0, 0, 0); sub.AutomaticSize = Enum.AutomaticSize.Y; sub.TextWrapped = true; sub.TextTransparency = 0.4
	local lbot = new("Frame", { Parent = left, BackgroundTransparency = 1, ZIndex = 2, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 30, 1, -34), Size = UDim2.new(1, -60, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	vlist(lbot, 10)
	new("Frame", { Parent = lbot, LayoutOrder = 1, BackgroundColor3 = INK, BackgroundTransparency = 0.8, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1) })
	local statusRow = new("Frame", { Parent = lbot, LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14) })
	local srL = new("Frame", { Parent = statusRow, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0) })
	hlist(srL, 7).VerticalAlignment = Enum.VerticalAlignment.Center
	local sdot = new("Frame", { Parent = srL, LayoutOrder = 1, BackgroundColor3 = INK, BorderSizePixel = 0, Size = UDim2.fromOffset(7, 7) }); corner(sdot, 999)
	tween(sdot, { BackgroundTransparency = 0.7 }, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true))
	local sol = label(srL, "SERVERS ONLINE", 10, Enum.FontWeight.Bold, INK); sol.LayoutOrder = 2
	local ver = label(statusRow, cfg.Build or "v2.4.1", 10, Enum.FontWeight.ExtraBold, INK); ver.AnchorPoint = Vector2.new(1, 0.5); ver.Position = UDim2.new(1, 0, 0.5, 0)

	-- RIGHT form panel ------------------------------------------------------
	local form = new("Frame", { Parent = card, LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, -290, 1, 0) })
	pad(form, 38, 40, 38, 40)
	local fcol = new("Frame", { Parent = form, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y })
	vlist(fcol, 0)
	local step = label(fcol, "STEP 01 — AUTHENTICATION", 10, Enum.FontWeight.Bold, ACCENT); step.LayoutOrder = 1; step.TextTransparency = 0.3
	spacer(fcol, 8, 2)
	new("TextLabel", { Parent = fcol, LayoutOrder = 3, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Text = string.upper(cfg.Heading or "ENTER LICENSE KEY"), FontFace = displayFont(), TextSize = 36, TextColor3 = LIGHT, TextXAlignment = Enum.TextXAlignment.Left })
	spacer(fcol, 7, 4)
	local note = label(fcol, string.upper(cfg.Note or "Paste the key bound to your HWID below"), 12, Enum.FontWeight.SemiBold, LIGHT); note.LayoutOrder = 5; note.TextTransparency = 0.55
	spacer(fcol, 24, 6)

	local inputArea = new("Frame", { Parent = fcol, LayoutOrder = 7, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 74) })
	local inputBox = new("Frame", { Parent = inputArea, BackgroundColor3 = INK, Size = UDim2.new(1, 0, 0, 50) })
	corner(inputBox, 4); local inStroke = stroke(inputBox, 1.5, ACCENT, 0.65)
	hlist(inputBox, 0).VerticalAlignment = Enum.VerticalAlignment.Center
	local prefix = new("TextLabel", { Parent = inputBox, LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(46, 50), Text = "⌘", TextColor3 = ACCENT, FontFace = bodyFont(Enum.FontWeight.ExtraBold), TextSize = 15 })
	new("Frame", { Parent = prefix, BackgroundColor3 = ACCENT, BackgroundTransparency = 0.8, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, 0, 0, 0) })
	local box = new("TextBox", { Parent = inputBox, LayoutOrder = 2, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Text = "", PlaceholderText = "MODKIT-XXXX-XXXX-XXXX", PlaceholderColor3 = GREY, TextColor3 = LIGHT, ClearTextOnFocus = false, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left })
	new("UIPadding", { Parent = box, PaddingLeft = UDim.new(0, 14) }); new("UIFlexItem", { Parent = box, FlexMode = Enum.UIFlexMode.Fill })
	local pasteBtn = new("TextButton", { Parent = inputBox, LayoutOrder = 3, BackgroundTransparency = 1, AutoButtonColor = false, Size = UDim2.fromOffset(74, 50), Text = "PASTE", TextColor3 = ACCENT, TextTransparency = 0.3, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 10 })
	new("Frame", { Parent = pasteBtn, BackgroundColor3 = ACCENT, BackgroundTransparency = 0.8, BorderSizePixel = 0, Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(0, 0, 0, 0) })
	local msgRow = new("Frame", { Parent = inputArea, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 16) })
	hlist(msgRow, 7).VerticalAlignment = Enum.VerticalAlignment.Center
	local msgDot = new("Frame", { Parent = msgRow, LayoutOrder = 1, BackgroundColor3 = ACCENT, BorderSizePixel = 0, Size = UDim2.fromOffset(6, 6), Visible = false }); corner(msgDot, 999)
	local msgLbl = label(msgRow, "", 11, Enum.FontWeight.Bold, ACCENT); msgLbl.LayoutOrder = 2; msgLbl.Visible = false

	spacer(fcol, 10, 8)
	local authBtn = new("TextButton", { Parent = fcol, LayoutOrder = 9, AutoButtonColor = false, BackgroundColor3 = ACCENT, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), Text = "" })
	corner(authBtn, 4); stroke(authBtn, 1.5, ACCENT)
	local authWrap = new("Frame", { Parent = authBtn, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 0) })
	hlist(authWrap, 11).VerticalAlignment = Enum.VerticalAlignment.Center
	local spin = new("Frame", { Parent = authWrap, LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 16), Visible = false })
	local ring = new("Frame", { Parent = spin, ZIndex = 1, BackgroundColor3 = ACCENT, Size = UDim2.fromScale(1, 1) }); corner(ring, 999)
	new("UIGradient", { Parent = ring, Rotation = 45,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 0.9) }) })  -- comet fade
	local hole = new("Frame", { Parent = spin, ZIndex = 2, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = DARK, BorderSizePixel = 0 }); corner(hole, 999)
	local authLbl = label(authWrap, "AUTHENTICATE", 14, Enum.FontWeight.ExtraBold, ACCENT); authLbl.LayoutOrder = 2

	spacer(fcol, 22, 10)
	local linkRow = new("Frame", { Parent = fcol, LayoutOrder = 11, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) })
	hlist(linkRow, 10)
	local getBtn = new("TextButton", { Parent = linkRow, LayoutOrder = 1, AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), Text = "GET A KEY →", TextColor3 = ACCENT, TextTransparency = 0.15, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 11 })
	new("UIFlexItem", { Parent = getBtn, FlexMode = Enum.UIFlexMode.Fill }); corner(getBtn, 4); stroke(getBtn, 1, ACCENT, 0.72)
	local hwidBtn
	if cfg.ShowHWID ~= false then   -- Copy-HWID button is optional (getBtn fills the row when hidden)
		hwidBtn = new("TextButton", { Parent = linkRow, LayoutOrder = 2, AutoButtonColor = false, BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), Text = "COPY HWID", TextColor3 = ACCENT, TextTransparency = 0.15, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 11 })
		new("UIFlexItem", { Parent = hwidBtn, FlexMode = Enum.UIFlexMode.Fill }); corner(hwidBtn, 4); stroke(hwidBtn, 1, ACCENT, 0.72)
	end

	spacer(fcol, 16, 12)
	local metaRow = new("Frame", { Parent = fcol, LayoutOrder = 13, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28) })
	new("Frame", { Parent = metaRow, BackgroundColor3 = ACCENT, BackgroundTransparency = 0.9, BorderSizePixel = 0, Size = UDim2.new(1, 0, 0, 1), Position = UDim2.fromScale(0, 0) })
	local metaL = label(metaRow, "HWID · " .. string.upper(string.sub(tostring(hwid), 1, 22)), 9.5, Enum.FontWeight.SemiBold, LIGHT); metaL.AnchorPoint = Vector2.new(0, 1); metaL.Position = UDim2.new(0, 0, 1, 0); metaL.TextTransparency = 0.7
	local discordUrl = cfg.DiscordUrl or ("https://discord.gg/" .. string.gsub(cfg.Discord or "modkit", "^%s*gg/%s*", ""))
	local metaR = new("TextButton", { Parent = metaRow, AutoButtonColor = false, BackgroundTransparency = 1, Text = "DISCORD · " .. string.upper(cfg.Discord or "gg/modkit"), TextColor3 = LIGHT, TextTransparency = 0.7, FontFace = bodyFont(Enum.FontWeight.Bold), TextSize = 10, AutomaticSize = Enum.AutomaticSize.XY, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(0, 0) })
	metaR.MouseButton1Click:Connect(function()
		pcall(function() if setclipboard then setclipboard(discordUrl) end end)
		pcall(function() game:GetService("GuiService"):OpenBrowserWindow(discordUrl) end)
	end)
	metaR.MouseEnter:Connect(function() metaR.TextTransparency = 0.3 end)
	metaR.MouseLeave:Connect(function() metaR.TextTransparency = 0.7 end)

	-- SUCCESS overlay -------------------------------------------------------
	local overlay = new("Frame", { Parent = card, BackgroundColor3 = ACCENT, Size = UDim2.fromScale(1, 1), ZIndex = 5, Visible = false, Active = true })
	local ocol = new("Frame", { Parent = overlay, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 440, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 6 })
	local ocolScale = new("UIScale", { Parent = ocol, Scale = 1 })
	local ov = vlist(ocol, 16); ov.HorizontalAlignment = Enum.HorizontalAlignment.Center
	local check = new("TextLabel", { Parent = ocol, LayoutOrder = 1, BackgroundTransparency = 1, Size = UDim2.fromOffset(72, 72), Text = "✓", TextColor3 = INK, FontFace = bodyFont(Enum.FontWeight.ExtraBold), TextSize = 34, ZIndex = 6 }); corner(check, 999); stroke(check, 2.5, INK)
	new("TextLabel", { Parent = ocol, LayoutOrder = 2, BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), Text = "ACCESS\nGRANTED", FontFace = displayFont(), TextSize = 46, TextColor3 = INK, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6 })
	local launch = label(ocol, "LAUNCHING LOADER…", 11, Enum.FontWeight.Bold, INK); launch.LayoutOrder = 3; launch.TextTransparency = 0.4; launch.TextXAlignment = Enum.TextXAlignment.Center; launch.Size = UDim2.new(1, 0, 0, 0); launch.AutomaticSize = Enum.AutomaticSize.Y; launch.ZIndex = 6

	-- close button (top-right) + drag the page by the brand panel (holder) -----
	local closeBtn = new("TextButton", { Parent = card, ZIndex = 20, AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = INK, BackgroundTransparency = 0.55,
		Text = "✕", TextColor3 = LIGHT, TextSize = 13, FontFace = bodyFont(Enum.FontWeight.Bold) })
	corner(closeBtn, 4)
	closeBtn.MouseEnter:Connect(function() tween(closeBtn, { BackgroundTransparency = 0.25 }) end)
	closeBtn.MouseLeave:Connect(function() tween(closeBtn, { BackgroundTransparency = 0.55 }) end)
	closeBtn.MouseButton1Click:Connect(function() exit(function() if gui.Parent then gui:Destroy() end; if cfg.OnClose then task.spawn(cfg.OnClose) end end) end)
	do
		local dragging, startIn, startPos
		left.Active = true
		left.InputBegan:Connect(function(i)
			if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
				dragging = true; startIn = i.Position; startPos = root.Position
				i.Changed:Connect(function() if i.UserInputState == Enum.UserInputState.End then dragging = false end end)
			end
		end)
		UserInputService.InputChanged:Connect(function(i)
			if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
				local d = i.Position - startIn
				root.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
			end
		end)
	end

	-- logic -----------------------------------------------------------------
	local status, loading = "idle", false
	local function refresh()
		local erry = status == "bad" or status == "empty"
		local bc = erry and RED or (status == "ok" and GRN or ACCENT)
		tween(inStroke, { Color = bc, Transparency = (erry or status == "ok") and 0 or 0.65 })
		local show = status ~= "idle"
		msgDot.Visible = show; msgLbl.Visible = show
		local map = { empty = "KEY FIELD IS EMPTY", bad = "INVALID OR EXPIRED KEY", checking = "VERIFYING WITH SERVER…", ok = "KEY ACCEPTED" }
		msgLbl.Text = map[status] or ""; msgLbl.TextColor3 = bc; msgDot.BackgroundColor3 = bc
		spin.Visible = loading
		authLbl.Text = loading and "AUTHENTICATING" or (status == "ok" and "UNLOCKED ✓" or "AUTHENTICATE")
		authLbl.TextColor3 = (status == "ok") and INK or ACCENT
		authBtn.BackgroundTransparency = (status == "ok") and 0 or (loading and 0.86 or 1)
	end
	local function shake() for i, dx in ipairs({ 7, -7, 5, -5, 3, -3, 0 }) do task.delay((i - 1) * 0.045, function() inputBox.Position = UDim2.fromOffset(dx, 0) end) end end
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local up = string.upper(box.Text)
		if box.Text ~= up then box.Text = up; return end
		if status == "bad" or status == "empty" then status = "idle"; refresh() end
	end)
	local function submit()
		if loading then return end
		local key = string.gsub(string.upper(box.Text), "%s", "")
		if key == "" then status = "empty"; refresh(); shake(); return end
		loading = true; status = "checking"; refresh()
		task.spawn(function()
			local valid = false
			if cfg.Callback then local s, r = pcall(cfg.Callback, key); valid = s and r and true or false else valid = (key == "DEMO") end
			loading = false
			if valid then
				status = "ok"; refresh(); task.wait(0.3)
				-- reveal: cyan wipes in, the content pops, the check spins in
				overlay.BackgroundTransparency = 1; ocolScale.Scale = 0.7; check.Rotation = -35; overlay.Visible = true
				tween(overlay, { BackgroundTransparency = 0 }, TweenInfo.new(0.2, Enum.EasingStyle.Quad))
				tween(ocolScale, { Scale = 1 }, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
				tween(check, { Rotation = 0 }, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
				task.wait(1.25)
				-- dive into the app: zoom through + fade out
				tween(uiscale, { Scale = fit * 1.18 }, TweenInfo.new(0.42, Enum.EasingStyle.Quint, Enum.EasingDirection.In))
				tween(root, { GroupTransparency = 1 }, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.In))
				task.delay(0.44, function()
					if cfg.OnSuccess then task.spawn(cfg.OnSuccess) elseif gui.Parent then gui:Destroy() end
				end)
			else
				status = "bad"; refresh(); shake()
			end
		end)
	end
	authBtn.MouseButton1Click:Connect(submit)
	box.FocusLost:Connect(function(enter) if enter then submit() end end)
	pasteBtn.MouseButton1Click:Connect(function()
		local ok, t = pcall(function() return getclipboard and getclipboard() end)
		box.Text = (ok and t and t ~= "" and string.upper(t)) or "MODKIT-7F3A-9K2P-XR41"
		status = "idle"; refresh()
	end)
	getBtn.MouseButton1Click:Connect(function()
		local url = cfg.GetKeyUrl or "https://discord.gg"
		pcall(function() if setclipboard then setclipboard(url) end end)
		pcall(function() game:GetService("GuiService"):OpenBrowserWindow(url) end)
	end)
	if hwidBtn then
		hwidBtn.MouseButton1Click:Connect(function()
			pcall(function() if setclipboard then setclipboard(tostring(hwid)) end end)
			hwidBtn.Text = "COPIED ✓"; task.delay(1.4, function() if hwidBtn.Parent then hwidBtn.Text = "COPY HWID" end end)
		end)
	end
	local spinConn
	spinConn = RunService.RenderStepped:Connect(function()
		if not gui.Parent then spinConn:Disconnect(); return end
		if spin.Visible then spin.Rotation = (spin.Rotation + 9) % 360 end
	end)
	gui.Destroying:Connect(function() if spinConn then spinConn:Disconnect() end end)

	refresh()
	return { Gui = gui, Destroy = function() exit(function() gui:Destroy() end) end, Unlock = function() status = "ok"; refresh(); overlay.Visible = true end }
end

return setmetatable({}, { __index = NEON, __call = function(_, cfg) return NEON:CreateWindow(cfg) end })
