local Drawing = {}
Drawing.__index = Drawing

local function unc(func, alternative, shouldWarn)
	if func and type(func) == "function" then
		return func
	else
		return alternative or function() end
	end
end

local cloneref = unc(cloneref, function(o)
	return o
end, true)

local gethui = unc(gethui, function()
	return game:GetService("CoreGui"):FindFirstChild("RobloxGui")
end, true)

local FindService, GetService = game.FindService, game.GetService
local function getService(serviceName: string, serviceProvider: ServiceProvider?)
	local provider = serviceProvider or game

	local ok, service = pcall(FindService, provider, serviceName)
	if not (ok and service) then
		ok, service = pcall(GetService, provider, serviceName)
	end

	if not (ok and service) then
		return
	end

	local okCloned, cloned = pcall(cloneref, service)
	if not (okCloned and cloned) then
		service = cloned
	end

	return service
end

local Workspace = getService("Workspace")
local Players = getService("Players")
local RunService = getService("RunService")
local TweenService = getService("TweenService")
local CurrentCamera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local TextService = getService("TextService")

local FONT_UI = 0
local FONT_SYSTEM = 1
local FONT_PLEX = 2
local FONT_MONOSPACE = 3

Drawing.Fonts = {
	UI = FONT_UI,
	System = FONT_SYSTEM,
	Plex = FONT_PLEX,
	Monospace = FONT_MONOSPACE,
}

local gettextboundsasync = TextService.GetTextBoundsAsync

local renv = getrenv()

local math_pi = renv.math.pi
local math_huge = renv.math.huge
local math_min = renv.math.min
local math_max = renv.math.max
local math_abs = renv.math.abs
local math_sin = renv.math.sin
local math_cos = renv.math.cos
local math_floor = renv.math.floor
local math_ceil = renv.math.ceil
local math_sqrt = renv.math.sqrt
local math_clamp = renv.math.clamp
local math_atan2 = renv.math.atan2
local math_pow = renv.math.pow

local assert = renv.assert
local typeof = renv.typeof
local setmetatable = renv.setmetatable
local pairs = renv.pairs
local ipairs = renv.ipairs
local next = renv.next
local tostring = renv.tostring
local tonumber = renv.tonumber
local pcall = renv.pcall
local xpcall = renv.xpcall

local string_format = renv.string.format
local string_lower = renv.string.lower
local string_sub = renv.string.sub
local string_gsub = renv.string.gsub
local string_find = renv.string.find
local string_gmatch = renv.string.gmatch

local table_concat = renv.table.concat
local table_insert = renv.table.insert
local table_remove = renv.table.remove

local Color3_new = renv.Color3.new
local Color3_fromRGB = renv.Color3.fromRGB
local Vector2_new = renv.Vector2.new
local Vector3_new = renv.Vector3.new
local CFrame_new = renv.CFrame.new
local UDim_new = renv.UDim.new
local UDim2_new = renv.UDim2.new
local UDim2_fromOffset = renv.UDim2.fromOffset
local Instance_new = renv.Instance.new
local ColorSequence_new = renv.ColorSequence.new
local ColorSequenceKeypoint_new = renv.ColorSequenceKeypoint.new

local task_spawn = renv.task.spawn
local task_wait = renv.task.wait
local task_cancel = renv.task.cancel

local game_Destroy = game.Destroy
local game_HttpGet = game.HttpGet

local state, cache
do
	local opt = {
		uniqueKey = "flatline esp",
		debug = true,
		executionDebounce = 1,
		cleanUpWait = 1,
		cacheHandlers = {
			{
				type = "RBXScriptConnection",
				uniqueKey = "__rbxscriptconnections",
				handler = function(thing)
					thing:Disconnect()
				end,
			},
			{
				type = "Instance",
				uniqueKey = "__instances",
				handler = function(obj)
					obj:Destroy()
				end,
			},
			{
				type = "thread",
				uniqueKey = "__threads",
				handler = function(thread)
					task.cancel(thread)
				end,
			},
			{
				type = "function",
				uniqueKey = "__hooks",
				handler = function(restoreFunc)
					restoreFunc()
				end,
			},
		},
	}

	local ignoreWait, now = false, time()
	local uniqueKey = tostring(opt.uniqueKey)

	state = shared[uniqueKey]

	if state == nil then
		ignoreWait = true
		state = { __timestamp = now, __cache = {}, __unloaded = false }
		shared[uniqueKey] = state
	elseif type(state) == "table" and type(state.__timestamp) == "number" and type(state.__cache) == "table" then
	else
		return
	end
	if not ignoreWait and (now - state.__timestamp) <= opt.executionDebounce then
		return
	else
		state.__timestamp = now
	end

	local stateCache = state.__cache

	for _, handler in opt.cacheHandlers do
		if type(stateCache[handler.uniqueKey]) ~= "table" then
			stateCache[handler.uniqueKey] = {}
		end
	end

	function state.CACHE_OBJECTS(...)
		if state.__unloaded then
			return ...
		end

		for _, obj in { ... } do
			local t = typeof(obj)
			for _, handler in opt.cacheHandlers do
				if handler.type == t then
					stateCache[handler.uniqueKey][#stateCache[handler.uniqueKey] + 1] = obj
					break
				end
			end
		end
		return ...
	end

	function state.REMOVE_CACHED_OBJECTS()
		for _, handler in opt.cacheHandlers do
			local handled = 0

			for i = #stateCache[handler.uniqueKey], 1, -1 do
				if xpcall(handler.handler, function(err) end, stateCache[handler.uniqueKey][i]) then
					table.remove(stateCache[handler.uniqueKey], i)
					handled = handled + 1
				end
			end
		end
	end

	function state.UNLOAD()
		state.__unloaded = true

		state.REMOVE_CACHED_OBJECTS()

		for key in pairs(stateCache) do
			stateCache[key] = nil
		end

		shared[uniqueKey] = nil
	end

	state.REMOVE_CACHED_OBJECTS()

	if not ignoreWait then
		task.wait(opt.cleanUpWait)
	end

	cache = state.CACHE_OBJECTS
end

local function create(className, properties, children)
	local inst = cache(Instance_new(className))
	for i, v in properties do
		if i ~= "Parent" then
			inst[i] = v
		end
	end
	if children then
		for i, v in children do
			v.Parent = inst
		end
	end
	inst.Parent = properties.Parent
	return inst
end

local function createGradient(colors, transparency, rotation)
	if not colors or type(colors) ~= "table" or #colors == 0 then
		return nil
	end

	for i, color in ipairs(colors) do
		if typeof(color) ~= "Color3" then
			return nil
		end
	end

	if #colors == 1 then
		return ColorSequence_new(colors[1])
	end

	local keypoints = {}
	for i, color in ipairs(colors) do
		local time = (i - 1) / (#colors - 1)
		keypoints[#keypoints + 1] = ColorSequenceKeypoint_new(time, color)
	end
	return ColorSequence_new(keypoints)
end

do
	local fonts = {
		Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	}

	for i, v in fonts do
		TextService:GetTextBoundsAsync(create("GetTextBoundsParams", {
			Text = "Hi",
			Size = 12,
			Font = v,
			Width = math_huge,
		}))
	end
end

local drawingDirectory = create("ScreenGui", {
	DisplayOrder = 15,
	IgnoreGuiInset = true,
	Name = "lua_drawing_library",
	Parent = gethui(),
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local function updatePosition(frame, from, to, thickness)
	local central = (from + to) / 2
	local offset = to - from
	frame.Position = UDim2_fromOffset(central.X, central.Y)
	frame.Rotation = math_atan2(offset.Y, offset.X) * 180 / math_pi
	frame.Size = UDim2_fromOffset(offset.Magnitude, thickness)
end

local itemCounter = 0
local registerCache = {}
local classes = {}

do
	local line = {}

	function line.new()
		itemCounter = itemCounter + 1
		local id = itemCounter

		local newLine = setmetatable({
			_id = id,
			__OBJECT_EXISTS = true,
			_properties = {
				Color = Color3_new(),
				From = Vector2_new(),
				Thickness = 1,
				To = Vector2_new(),
				Transparency = 1,
				Visible = false,
				ZIndex = 0,
				GradientEnabled = false,
				GradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				GradientRotation = 0,
			},
			_frame = create("Frame", {
				Name = id,
				AnchorPoint = Vector2_new(0.5, 0.5),
				BackgroundColor3 = Color3_new(),
				BorderSizePixel = 0,
				Parent = drawingDirectory,
				Position = UDim2_new(),
				Size = UDim2_new(),
				Visible = false,
				ZIndex = 0,
			}),
		}, line)

		registerCache[id] = newLine
		return newLine
	end

	function line:__index(k)
		local prop = self._properties[k]
		if prop ~= nil then
			return prop
		end
		return line[k]
	end

	function line:__newindex(k, v)
		if self.__OBJECT_EXISTS == true then
			local props = self._properties

			if props[k] == nil or props[k] == v or (k ~= "GradientColors" and typeof(props[k]) ~= typeof(v)) then
				return
			end

			props[k] = v

			if k == "Color" then
				if not props.GradientEnabled then
					self._frame.BackgroundColor3 = v
				end
			elseif k == "From" then
				self:_updatePosition()
			elseif k == "Thickness" then
				self._frame.Size = UDim2_fromOffset(self._frame.AbsoluteSize.X, math_max(v, 1))
			elseif k == "To" then
				self:_updatePosition()
			elseif k == "Transparency" then
				self._frame.BackgroundTransparency = math_clamp(1 - v, 0, 1)
			elseif k == "Visible" then
				self._frame.Visible = v
			elseif k == "ZIndex" then
				self._frame.ZIndex = v
			elseif k == "GradientEnabled" or k == "GradientColors" or k == "GradientRotation" then
				self:_updateGradient()
			end
		end
	end

	function line:__iter()
		return next, self._properties
	end

	function line:__tostring()
		return "Drawing"
	end

	function line:Destroy()
		registerCache[self._id] = nil
		self.__OBJECT_EXISTS = false
		game_Destroy(self._frame)
	end

	function line:_updatePosition()
		local props = self._properties
		updatePosition(self._frame, props.From, props.To, props.Thickness)
	end

	function line:_updateGradient()
		local props = self._properties
		if props.GradientEnabled then
			if not self._frame:FindFirstChild("_gradient") then
				create("UIGradient", {
					Name = "_gradient",
					Parent = self._frame,
				})
			end
			local gradient = self._frame._gradient
			gradient.Color = createGradient(props.GradientColors)
			gradient.Rotation = props.GradientRotation
			self._frame.BackgroundColor3 = Color3_new(1, 1, 1)
		else
			if self._frame:FindFirstChild("_gradient") then
				self._frame._gradient:Destroy()
			end
			self._frame.BackgroundColor3 = props.Color
		end
	end

	line.Remove = line.Destroy
	classes.Line = line
end

do
	local circle = {}

	function circle.new()
		itemCounter = itemCounter + 1
		local id = itemCounter

		local newCircle = setmetatable({
			_id = id,
			__OBJECT_EXISTS = true,
			_properties = {
				Color = Color3_new(),
				Filled = false,
				NumSides = 0,
				Position = Vector2_new(),
				Radius = 0,
				Thickness = 1,
				Transparency = 1,
				Visible = false,
				ZIndex = 0,
				GradientEnabled = false,
				GradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				GradientRotation = 0,
				StrokeGradientEnabled = false,
				StrokeGradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				StrokeGradientRotation = 0,
			},
			_frame = create("Frame", {
				Name = id,
				AnchorPoint = Vector2_new(0.5, 0.5),
				BackgroundColor3 = Color3_new(),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = drawingDirectory,
				Position = UDim2_new(),
				Size = UDim2_new(),
				Visible = false,
				ZIndex = 0,
			}, {
				create("UICorner", {
					Name = "_corner",
					CornerRadius = UDim_new(1, 0),
				}),
				create("UIStroke", {
					Name = "_stroke",
					Color = Color3_new(),
					Thickness = 1,
				}),
			}),
		}, circle)

		registerCache[id] = newCircle
		return newCircle
	end

	function circle:__index(k)
		local prop = self._properties[k]
		if prop ~= nil then
			return prop
		end
		return circle[k]
	end

	function circle:__newindex(k, v)
		if self.__OBJECT_EXISTS == true then
			local props = self._properties
			if props[k] == nil or props[k] == v or (k ~= "GradientColors" and k ~= "StrokeGradientColors" and typeof(props[k]) ~= typeof(v)) then
				return
			end
			props[k] = v
			if k == "Color" then
				if not props.GradientEnabled then
					self._frame.BackgroundColor3 = v
				end
				if not props.StrokeGradientEnabled then
					self._frame._stroke.Color = v
				end
			elseif k == "Filled" then
				self._frame.BackgroundTransparency = v and 1 - props.Transparency or 1
			elseif k == "Position" then
				self._frame.Position = UDim2_fromOffset(v.X, v.Y)
			elseif k == "Radius" then
				self:_updateRadius()
			elseif k == "Thickness" then
				self._frame._stroke.Thickness = math_max(v, 1)
				self:_updateRadius()
			elseif k == "Transparency" then
				self._frame._stroke.Transparency = 1 - v
				if props.Filled then
					self._frame.BackgroundTransparency = 1 - v
				end
			elseif k == "Visible" then
				self._frame.Visible = v
			elseif k == "ZIndex" then
				self._frame.ZIndex = v
			elseif k == "GradientEnabled" or k == "GradientColors" or k == "GradientRotation" then
				self:_updateGradient()
			elseif k == "StrokeGradientEnabled" or k == "StrokeGradientColors" or k == "StrokeGradientRotation" then
				self:_updateStrokeGradient()
			end
		end
	end

	function circle:__iter()
		return next, self._properties
	end

	function circle:__tostring()
		return "Drawing"
	end

	function circle:Destroy()
		registerCache[self._id] = nil
		self.__OBJECT_EXISTS = false
		game_Destroy(self._frame)
	end

	function circle:_updateRadius()
		local props = self._properties
		local diameter = (props.Radius * 2) - (props.Thickness * 2)
		self._frame.Size = UDim2_fromOffset(diameter, diameter)
	end

	function circle:_updateGradient()
		local props = self._properties
		if props.GradientEnabled then
			if not self._frame:FindFirstChild("_gradient") then
				create("UIGradient", {
					Name = "_gradient",
					Parent = self._frame,
				})
			end
			local gradient = self._frame._gradient
			if props.GradientColors and #props.GradientColors > 0 then
				gradient.Color = createGradient(props.GradientColors)
			else
				gradient.Color = ColorSequence_new(Color3_new(1, 1, 1))
			end
			gradient.Rotation = props.GradientRotation
			self._frame.BackgroundColor3 = Color3_new(1, 1, 1)
		else
			if self._frame:FindFirstChild("_gradient") then
				self._frame._gradient:Destroy()
			end
			self._frame.BackgroundColor3 = props.Color
		end
	end

	function circle:_updateStrokeGradient()
		local props = self._properties
		if props.StrokeGradientEnabled then
			if not self._frame._stroke:FindFirstChild("_gradient") then
				create("UIGradient", {
					Name = "_gradient",
					Parent = self._frame._stroke,
				})
			end
			local gradient = self._frame._stroke._gradient
			if props.StrokeGradientColors and #props.StrokeGradientColors > 0 then
				local gradientColor = createGradient(props.StrokeGradientColors)
				if gradientColor then
					gradient.Color = gradientColor
				else
					gradient.Color = ColorSequence_new(Color3_new(1, 1, 1))
				end
			else
				gradient.Color = ColorSequence_new(Color3_new(1, 1, 1))
			end
			gradient.Rotation = props.StrokeGradientRotation
			self._frame._stroke.Color = Color3_new(1, 1, 1)
		else
			if self._frame._stroke:FindFirstChild("_gradient") then
				self._frame._stroke._gradient:Destroy()
			end
			self._frame._stroke.Color = props.Color
		end
	end

	circle.Remove = circle.Destroy
	classes.Circle = circle
end

do
	local enumToFont = {
		[Drawing.Fonts.UI] = Font.new("rbxasset://fonts/families/Arial.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		[Drawing.Fonts.System] = Font.new("rbxasset://fonts/families/HighwayGothic.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		[Drawing.Fonts.Plex] = Font.new("rbxasset://fonts/families/Roboto.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
		[Drawing.Fonts.Monospace] = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular, Enum.FontStyle.Normal),
	}

	local text = {}

	function text.new()
		itemCounter = itemCounter + 1
		local id = itemCounter

		local newText = setmetatable({
			_id = id,
			__OBJECT_EXISTS = true,
			_properties = {
				Center = false,
				Color = Color3_new(),
				Font = 0,
				Outline = false,
				OutlineColor = Color3_new(),
				Position = Vector2_new(),
				Size = 12,
				Text = "",
				TextBounds = Vector2_new(),
				Transparency = 1,
				Visible = false,
				ZIndex = 0,
				GradientEnabled = false,
				GradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				GradientRotation = 0,
				StrokeGradientEnabled = false,
				StrokeGradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				StrokeGradientRotation = 0,
			},
			_frame = create("TextLabel", {
				Name = id,
				BackgroundTransparency = 1,
				FontFace = enumToFont[0],
				Parent = drawingDirectory,
				Position = UDim2_new(),
				Size = UDim2_new(),
				Text = "",
				TextColor3 = Color3_new(),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				Visible = false,
				ZIndex = 0,
			}, {
				create("UIStroke", {
					Name = "_stroke",
					Color = Color3_new(),
					Enabled = false,
					Thickness = 1,
				}),
			}),
		}, text)

		registerCache[id] = newText
		return newText
	end

	function text:__index(k)
		local prop = self._properties[k]
		if prop ~= nil then
			return prop
		end
		return text[k]
	end

	function text:__newindex(k, v)
		if self.__OBJECT_EXISTS == true then
			local props = self._properties
			if k == "TextBounds" or props[k] == nil or props[k] == v or (k ~= "GradientColors" and k ~= "StrokeGradientColors" and typeof(props[k]) ~= typeof(v)) then
				return
			end
			props[k] = v
			if k == "Center" then
				self._frame.TextXAlignment = v and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
			elseif k == "Color" then
				if not props.GradientEnabled then
					self._frame.TextColor3 = v
				end
			elseif k == "Font" then
				self._frame.FontFace = enumToFont[v]
				self:_updateTextBounds()
			elseif k == "Outline" then
				self._frame._stroke.Enabled = v
			elseif k == "OutlineColor" then
				if not props.StrokeGradientEnabled then
					self._frame._stroke.Color = v
				end
			elseif k == "Position" then
				self._frame.Position = UDim2_fromOffset(v.X, v.Y)
			elseif k == "Size" then
				self._frame.TextSize = v
				self:_updateTextBounds()
			elseif k == "Text" then
				self._frame.Text = v
				self:_updateTextBounds()
			elseif k == "Transparency" then
				self._frame.TextTransparency = 1 - v
				self._frame._stroke.Transparency = 1 - v
			elseif k == "Visible" then
				self._frame.Visible = v
			elseif k == "ZIndex" then
				self._frame.ZIndex = v
			elseif k == "GradientEnabled" or k == "GradientColors" or k == "GradientRotation" then
				self:_updateGradient()
			elseif k == "StrokeGradientEnabled" or k == "StrokeGradientColors" or k == "StrokeGradientRotation" then
				self:_updateStrokeGradient()
			end
		end
	end

	function text:__iter()
		return next, self._properties
	end

	function text:__tostring()
		return "Drawing"
	end

	function text:Destroy()
		registerCache[self._id] = nil
		self.__OBJECT_EXISTS = false
		game_Destroy(self._frame)
	end

	function text:_updateTextBounds()
		local props = self._properties
		props.TextBounds = gettextboundsasync(
			TextService,
			create("GetTextBoundsParams", {
				Text = props.Text,
				Size = props.Size,
				Font = enumToFont[props.Font],
				Width = math_huge,
			})
		)
	end

	function text:_updateGradient()
		local props = self._properties
		if props.GradientEnabled then
			if not self._frame:FindFirstChild("_gradient") then
				create("UIGradient", {
					Name = "_gradient",
					Parent = self._frame,
				})
			end
			local gradient = self._frame._gradient
			gradient.Color = createGradient(props.GradientColors)
			gradient.Rotation = props.GradientRotation
			self._frame.TextColor3 = Color3_new(1, 1, 1)
		else
			if self._frame:FindFirstChild("_gradient") then
				self._frame._gradient:Destroy()
			end
			self._frame.TextColor3 = props.Color
		end
	end

	function text:_updateStrokeGradient()
		local props = self._properties
		if props.StrokeGradientEnabled then
			if not self._frame._stroke:FindFirstChild("_gradient") then
				create("UIGradient", {
					Name = "_gradient",
					Parent = self._frame._stroke,
				})
			end
			local gradient = self._frame._stroke._gradient
			gradient.Color = createGradient(props.StrokeGradientColors)
			gradient.Rotation = props.StrokeGradientRotation
			self._frame._stroke.Color = Color3_new(1, 1, 1)
		else
			if self._frame._stroke:FindFirstChild("_gradient") then
				self._frame._stroke._gradient:Destroy()
			end
			self._frame._stroke.Color = props.OutlineColor
		end
	end

	text.Remove = text.Destroy
	classes.Text = text
end

do
	local square = {}

	function square.new()
		itemCounter = itemCounter + 1
		local id = itemCounter

		local newSquare = setmetatable({
			_id = id,
			__OBJECT_EXISTS = true,
			_properties = {
				Color = Color3_new(),
				Filled = false,
				Position = Vector2_new(),
				Size = Vector2_new(),
				Thickness = 1,
				Transparency = 1,
				Visible = false,
				ZIndex = 0,
				GradientEnabled = false,
				GradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				GradientRotation = 0,
				StrokeGradientEnabled = false,
				StrokeGradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				StrokeGradientRotation = 0,
			},
			_frame = create("Frame", {
				BackgroundColor3 = Color3_new(),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Parent = drawingDirectory,
				Position = UDim2_new(),
				Size = UDim2_new(),
				Visible = false,
				ZIndex = 0,
			}, {
				create("UIStroke", {
					Name = "_stroke",
					Color = Color3_new(),
					Thickness = 1,
					LineJoinMode = Enum.LineJoinMode.Miter,
				}),
			}),
		}, square)

		registerCache[id] = newSquare
		return newSquare
	end

	function square:__index(k)
		local prop = self._properties[k]
		if prop ~= nil then
			return prop
		end
		return square[k]
	end

	function square:__newindex(k, v)
		if self.__OBJECT_EXISTS == true then
			local props = self._properties
			if props[k] == nil or props[k] == v or (k ~= "GradientColors" and k ~= "StrokeGradientColors" and typeof(props[k]) ~= typeof(v)) then
				return
			end
			props[k] = v
			if k == "Color" then
				if not props.GradientEnabled then
					self._frame.BackgroundColor3 = v
				end
				if not props.StrokeGradientEnabled then
					self._frame._stroke.Color = v
				end
			elseif k == "Filled" then
				self._frame.BackgroundTransparency = v and 1 - props.Transparency or 1
			elseif k == "Position" then
				self:_updateScale()
			elseif k == "Size" then
				self:_updateScale()
			elseif k == "Thickness" then
				self._frame._stroke.Thickness = v
				self:_updateScale()
			elseif k == "Transparency" then
				self._frame._stroke.Transparency = 1 - v
				if props.Filled then
					self._frame.BackgroundTransparency = 1 - v
				end
			elseif k == "Visible" then
				self._frame.Visible = v
			elseif k == "ZIndex" then
				self._frame.ZIndex = v
			elseif k == "GradientEnabled" or k == "GradientColors" or k == "GradientRotation" then
				self:_updateGradient()
			elseif k == "StrokeGradientEnabled" or k == "StrokeGradientColors" or k == "StrokeGradientRotation" then
				self:_updateStrokeGradient()
			end
		end
	end

	function square:__iter()
		return next, self._properties
	end

	function square:__tostring()
		return "Drawing"
	end

	function square:Destroy()
		registerCache[self._id] = nil
		self.__OBJECT_EXISTS = false
		game_Destroy(self._frame)
	end

	function square:_updateScale()
		local props = self._properties
		self._frame.Position = UDim2_fromOffset(props.Position.X + props.Thickness, props.Position.Y + props.Thickness)
		local thickness = props.Thickness
		self._frame.Size = UDim2_fromOffset(props.Size.X - thickness * 2, props.Size.Y - thickness * 2)
	end

	function square:_updateGradient()
		local props = self._properties
		if props.GradientEnabled then
			if not self._frame:FindFirstChild("_gradient") then
				create("UIGradient", {
					Name = "_gradient",
					Parent = self._frame,
				})
			end
			local gradient = self._frame._gradient
			gradient.Color = createGradient(props.GradientColors)
			gradient.Rotation = props.GradientRotation
			self._frame.BackgroundColor3 = Color3_new(1, 1, 1)
		else
			if self._frame:FindFirstChild("_gradient") then
				self._frame._gradient:Destroy()
			end
			self._frame.BackgroundColor3 = props.Color
		end
	end

	function square:_updateStrokeGradient()
		local props = self._properties
		if props.StrokeGradientEnabled then
			if not self._frame._stroke:FindFirstChild("_gradient") then
				create("UIGradient", {
					Name = "_gradient",
					Parent = self._frame._stroke,
				})
			end
			local gradient = self._frame._stroke._gradient
			local gradientColor = createGradient(props.StrokeGradientColors)
			if gradientColor then
				gradient.Color = gradientColor
			else
				gradient.Color = ColorSequence_new(Color3_new(1, 1, 1))
			end
			gradient.Rotation = props.StrokeGradientRotation
			self._frame._stroke.Color = Color3_new(1, 1, 1)
		else
			if self._frame._stroke:FindFirstChild("_gradient") then
				self._frame._stroke._gradient:Destroy()
			end
			self._frame._stroke.Color = props.Color
		end
	end

	square.Remove = square.Destroy
	classes.Square = square
end

do
	local image = {}

	function image.new()
		itemCounter = itemCounter + 1
		local id = itemCounter

		local newImage = setmetatable({
			_id = id,
			_imageId = 0,
			__OBJECT_EXISTS = true,
			_properties = {
				Color = Color3_new(1, 1, 1),
				Data = "",
				Position = Vector2_new(),
				Rounding = 0,
				Size = Vector2_new(),
				Transparency = 1,
				Uri = "",
				Visible = false,
				ZIndex = 0,
			},
			_frame = create("ImageLabel", {
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = "",
				ImageColor3 = Color3_new(1, 1, 1),
				Parent = drawingDirectory,
				Position = UDim2_new(),
				Size = UDim2_new(),
				Visible = false,
				ZIndex = 0,
			}, {
				create("UICorner", {
					Name = "_corner",
					CornerRadius = UDim_new(),
				}),
			}),
		}, image)

		registerCache[id] = newImage
		return newImage
	end

	function image:__index(k)
		assert(k ~= "Data", string_format("Attempt to read writeonly property '%s'", k))
		if k == "Loaded" then
			return self._frame.IsLoaded
		end
		local prop = self._properties[k]
		if prop ~= nil then
			return prop
		end
		return image[k]
	end

	function image:__newindex(k, v)
		if self.__OBJECT_EXISTS == true then
			local props = self._properties
			if props[k] == nil or props[k] == v or typeof(props[k]) ~= typeof(v) then
				return
			end
			props[k] = v
			if k == "Color" then
				self._frame.ImageColor3 = v
			elseif k == "Data" then
				self:_newImage(v)
			elseif k == "Position" then
				self._frame.Position = UDim2_fromOffset(v.X, v.Y)
			elseif k == "Rounding" then
				self._frame._corner.CornerRadius = UDim_new(0, v)
			elseif k == "Size" then
				self._frame.Size = UDim2_fromOffset(v.X, v.Y)
			elseif k == "Transparency" then
				self._frame.ImageTransparency = 1 - v
			elseif k == "Uri" then
				self:_newImage(v, true)
			elseif k == "Visible" then
				self._frame.Visible = v
			elseif k == "ZIndex" then
				self._frame.ZIndex = v
			end
		end
	end

	function image:__iter()
		return next, self._properties
	end

	function image:__tostring()
		return "Drawing"
	end

	function image:Destroy()
		registerCache[self._id] = nil
		self.__OBJECT_EXISTS = false
		game_Destroy(self._frame)
	end

	function image:_newImage(data, isUri)
		task_spawn(function()
			self._imageId = self._imageId + 1
			local path = string_format("%s-%s.png", self._id, self._imageId)
			if isUri then
				local newData
				while newData == nil do
					local success, res = pcall(game_HttpGet, game, data, true)
					if success then
						newData = res
					elseif string_find(string_lower(res), "too many requests") then
						task.wait(3)
					else
						error(res, 2)
						return
					end
				end
				self._properties.Data = data
			else
				self._properties.Uri = ""
			end
			self._frame.Image = getcustomasset(path, data)
		end)
	end

	image.Remove = image.Destroy
	classes.Image = image
end

do
	local triangle = {}

	function triangle.new()
		itemCounter = itemCounter + 1
		local id = itemCounter

		local newTriangle = setmetatable({
			_id = id,
			__OBJECT_EXISTS = true,
			_properties = {
				Color = Color3_new(),
				Filled = false,
				PointA = Vector2_new(),
				PointB = Vector2_new(),
				PointC = Vector2_new(),
				Thickness = 1,
				Transparency = 1,
				Visible = false,
				ZIndex = 0,
				GradientEnabled = false,
				GradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				GradientRotation = 0,
			},
			_frame = create("Frame", {
				BackgroundTransparency = 1,
				Parent = drawingDirectory,
				Size = UDim2_new(1, 0, 1, 0),
				Visible = false,
				ZIndex = 0,
			}, {
				create("Frame", {
					Name = "_line1",
					AnchorPoint = Vector2_new(0.5, 0.5),
					BackgroundColor3 = Color3_new(),
					BorderSizePixel = 0,
					Position = UDim2_new(),
					Size = UDim2_new(),
					ZIndex = 0,
				}),
				create("Frame", {
					Name = "_line2",
					AnchorPoint = Vector2_new(0.5, 0.5),
					BackgroundColor3 = Color3_new(),
					BorderSizePixel = 0,
					Position = UDim2_new(),
					Size = UDim2_new(),
					ZIndex = 0,
				}),
				create("Frame", {
					Name = "_line3",
					AnchorPoint = Vector2_new(0.5, 0.5),
					BackgroundColor3 = Color3_new(),
					BorderSizePixel = 0,
					Position = UDim2_new(),
					Size = UDim2_new(),
					ZIndex = 0,
				}),
			}),
		}, triangle)

		registerCache[id] = newTriangle
		return newTriangle
	end

	function triangle:__index(k)
		local prop = self._properties[k]
		if prop ~= nil then
			return prop
		end
		return triangle[k]
	end

	function triangle:__newindex(k, v)
		if self.__OBJECT_EXISTS == true then
			local props, frame = self._properties, self._frame
			if props[k] == nil or props[k] == v or (k ~= "GradientColors" and typeof(props[k]) ~= typeof(v)) then
				return
			end
			props[k] = v
			if k == "Color" then
				if not props.GradientEnabled then
					frame._line1.BackgroundColor3 = v
					frame._line2.BackgroundColor3 = v
					frame._line3.BackgroundColor3 = v
				end
			elseif k == "Filled" then
			elseif k == "PointA" then
				self:_updateVertices({
					{ frame._line1, props.PointA, props.PointB },
					{ frame._line3, props.PointC, props.PointA },
				})
				if props.Filled then
					self:_calculateFill()
				end
			elseif k == "PointB" then
				self:_updateVertices({
					{ frame._line1, props.PointA, props.PointB },
					{ frame._line2, props.PointB, props.PointC },
				})
				if props.Filled then
					self:_calculateFill()
				end
			elseif k == "PointC" then
				self:_updateVertices({
					{ frame._line2, props.PointB, props.PointC },
					{ frame._line3, props.PointC, props.PointA },
				})
				if props.Filled then
					self:_calculateFill()
				end
			elseif k == "Thickness" then
				local thickness = math_max(v, 1)
				frame._line1.Size = UDim2_fromOffset(frame._line1.AbsoluteSize.X, thickness)
				frame._line2.Size = UDim2_fromOffset(frame._line2.AbsoluteSize.X, thickness)
				frame._line3.Size = UDim2_fromOffset(frame._line3.AbsoluteSize.X, thickness)
			elseif k == "Transparency" then
				frame._line1.BackgroundTransparency = 1 - v
				frame._line2.BackgroundTransparency = 1 - v
				frame._line3.BackgroundTransparency = 1 - v
			elseif k == "Visible" then
				self._frame.Visible = v
			elseif k == "ZIndex" then
				self._frame.ZIndex = v
			elseif k == "GradientEnabled" or k == "GradientColors" or k == "GradientRotation" then
				self:_updateGradient()
			end
		end
	end

	function triangle:__iter()
		return next, self._properties
	end

	function triangle:__tostring()
		return "Drawing"
	end

	function triangle:Destroy()
		registerCache[self._id] = nil
		self.__OBJECT_EXISTS = false
		game_Destroy(self._frame)
	end

	function triangle:_updateVertices(vertices)
		local thickness = self._properties.Thickness
		for i, v in vertices do
			updatePosition(v[1], v[2], v[3], thickness)
		end
	end

	function triangle:_calculateFill() end

	function triangle:_updateGradient()
		local props = self._properties
		local lines = { self._frame._line1, self._frame._line2, self._frame._line3 }

		for _, line in ipairs(lines) do
			if props.GradientEnabled then
				if not line:FindFirstChild("_gradient") then
					create("UIGradient", {
						Name = "_gradient",
						Parent = line,
					})
				end
				local gradient = line._gradient
				gradient.Color = createGradient(props.GradientColors)
				gradient.Rotation = props.GradientRotation
				line.BackgroundColor3 = Color3_new(1, 1, 1)
			else
				if line:FindFirstChild("_gradient") then
					line._gradient:Destroy()
				end
				line.BackgroundColor3 = props.Color
			end
		end
	end

	triangle.Remove = triangle.Destroy
	classes.Triangle = triangle
end

do
	local quad = {}

	function quad.new()
		itemCounter = itemCounter + 1
		local id = itemCounter

		local newQuad = setmetatable({
			_id = id,
			__OBJECT_EXISTS = true,
			_properties = {
				Color = Color3_new(),
				Filled = false,
				PointA = Vector2_new(),
				PointB = Vector2_new(),
				PointC = Vector2_new(),
				PointD = Vector2_new(),
				Thickness = 1,
				Transparency = 1,
				Visible = false,
				ZIndex = 0,
				GradientEnabled = false,
				GradientColors = { Color3_new(1, 1, 1), Color3_new(0, 0, 0) },
				GradientRotation = 0,
			},
			_frame = create("Frame", {
				BackgroundTransparency = 1,
				Parent = drawingDirectory,
				Size = UDim2_new(1, 0, 1, 0),
				Visible = false,
				ZIndex = 0,
			}, {
				create("Frame", {
					Name = "_line1",
					AnchorPoint = Vector2_new(0.5, 0.5),
					BackgroundColor3 = Color3_new(),
					BorderSizePixel = 0,
					Position = UDim2_new(),
					Size = UDim2_new(),
					ZIndex = 0,
				}),
				create("Frame", {
					Name = "_line2",
					AnchorPoint = Vector2_new(0.5, 0.5),
					BackgroundColor3 = Color3_new(),
					BorderSizePixel = 0,
					Position = UDim2_new(),
					Size = UDim2_new(),
					ZIndex = 0,
				}),
				create("Frame", {
					Name = "_line3",
					AnchorPoint = Vector2_new(0.5, 0.5),
					BackgroundColor3 = Color3_new(),
					BorderSizePixel = 0,
					Position = UDim2_new(),
					Size = UDim2_new(),
					ZIndex = 0,
				}),
				create("Frame", {
					Name = "_line4",
					AnchorPoint = Vector2_new(0.5, 0.5),
					BackgroundColor3 = Color3_new(),
					BorderSizePixel = 0,
					Position = UDim2_new(),
					Size = UDim2_new(),
					ZIndex = 0,
				}),
			}),
		}, quad)

		registerCache[id] = newQuad
		return newQuad
	end

	function quad:__index(k)
		local prop = self._properties[k]
		if prop ~= nil then
			return prop
		end
		return quad[k]
	end

	function quad:__newindex(k, v)
		if self.__OBJECT_EXISTS == true then
			local props, frame = self._properties, self._frame
			if props[k] == nil or props[k] == v or (k ~= "GradientColors" and typeof(props[k]) ~= typeof(v)) then
				return
			end
			props[k] = v
			if k == "Color" then
				if not props.GradientEnabled then
					frame._line1.BackgroundColor3 = v
					frame._line2.BackgroundColor3 = v
					frame._line3.BackgroundColor3 = v
					frame._line4.BackgroundColor3 = v
				end
			elseif k == "Filled" then
			elseif k == "PointA" then
				self:_updateVertices({
					{ frame._line1, props.PointA, props.PointB },
					{ frame._line4, props.PointD, props.PointA },
				})
				if props.Filled then
					self:_calculateFill()
				end
			elseif k == "PointB" then
				self:_updateVertices({
					{ frame._line1, props.PointA, props.PointB },
					{ frame._line2, props.PointB, props.PointC },
				})
				if props.Filled then
					self:_calculateFill()
				end
			elseif k == "PointC" then
				self:_updateVertices({
					{ frame._line2, props.PointB, props.PointC },
					{ frame._line3, props.PointC, props.PointD },
				})
				if props.Filled then
					self:_calculateFill()
				end
			elseif k == "PointD" then
				self:_updateVertices({
					{ frame._line3, props.PointC, props.PointD },
					{ frame._line4, props.PointD, props.PointA },
				})
				if props.Filled then
					self:_calculateFill()
				end
			elseif k == "Thickness" then
				local thickness = math_max(v, 1)
				frame._line1.Size = UDim2_fromOffset(frame._line1.AbsoluteSize.X, thickness)
				frame._line2.Size = UDim2_fromOffset(frame._line2.AbsoluteSize.X, thickness)
				frame._line3.Size = UDim2_fromOffset(frame._line3.AbsoluteSize.X, thickness)
				frame._line4.Size = UDim2_fromOffset(frame._line4.AbsoluteSize.X, thickness)
			elseif k == "Transparency" then
				frame._line1.BackgroundTransparency = 1 - v
				frame._line2.BackgroundTransparency = 1 - v
				frame._line3.BackgroundTransparency = 1 - v
				frame._line4.BackgroundTransparency = 1 - v
			elseif k == "Visible" then
				self._frame.Visible = v
			elseif k == "ZIndex" then
				self._frame.ZIndex = v
			elseif k == "GradientEnabled" or k == "GradientColors" or k == "GradientRotation" then
				self:_updateGradient()
			end
		end
	end

	function quad:__iter()
		return next, self._properties
	end

	function quad:__tostring()
		return "Drawing"
	end

	function quad:Destroy()
		registerCache[self._id] = nil
		self.__OBJECT_EXISTS = false
		game_Destroy(self._frame)
	end

	function quad:_updateVertices(vertices)
		local thickness = self._properties.Thickness
		for i, v in vertices do
			updatePosition(v[1], v[2], v[3], thickness)
		end
	end

	function quad:_calculateFill() end

	function quad:_updateGradient()
		local props = self._properties
		local lines = { self._frame._line1, self._frame._line2, self._frame._line3, self._frame._line4 }

		for _, line in ipairs(lines) do
			if props.GradientEnabled then
				if not line:FindFirstChild("_gradient") then
					create("UIGradient", {
						Name = "_gradient",
						Parent = line,
					})
				end
				local gradient = line._gradient
				gradient.Color = createGradient(props.GradientColors)
				gradient.Rotation = props.GradientRotation
				line.BackgroundColor3 = Color3_new(1, 1, 1)
			else
				if line:FindFirstChild("_gradient") then
					line._gradient:Destroy()
				end
				line.BackgroundColor3 = props.Color
			end
		end
	end

	quad.Remove = quad.Destroy
	classes.Quad = quad
end

function Drawing.new(drawingType)
	return assert(classes[drawingType], string_format("Invalid drawing type '%s'", drawingType)).new()
end

function Drawing.clear()
	for i, v in registerCache do
		if v.__OBJECT_EXISTS then
			v:Destroy()
		end
	end
end

Drawing.cache = registerCache

function Drawing.isrenderobj(x)
	return tostring(x) == "Drawing"
end

function Drawing.getrenderproperty(x, y)
	assert(Drawing.isrenderobj(x), string_format("invalid argument #1 to 'getrenderproperty' (Drawing expected, got %s)", typeof(x)))
	return x[y]
end

function Drawing.setrenderproperty(x, y, z)
	assert(Drawing.isrenderobj(x), string_format("invalid argument #1 to 'setrenderproperty' (Drawing expected, got %s)", typeof(x)))
	x[y] = z
end

if setreadonly then
	setreadonly(Drawing.Fonts, true)
	setreadonly(Drawing, true)
end

local ESPLibrary = {}
ESPLibrary.__index = ESPLibrary

local COLOR_CACHE_DURATION = 2
local TEAM_COLOR_CACHE = {}

local function updateDrawingIfChanged(drawing, property, value)
	if drawing[property] ~= value then
		drawing[property] = value
		return true
	end
	return false
end

local function updateDrawingPosition(drawing, pos, cache, cacheKey)
	if not cache[cacheKey] or cache[cacheKey].X ~= pos.X or cache[cacheKey].Y ~= pos.Y then
		drawing.Position = pos
		cache[cacheKey] = pos
		return true
	end
	return false
end

local function updateDrawingSize(drawing, size, cache, cacheKey)
	if not cache[cacheKey] or cache[cacheKey].X ~= size.X or cache[cacheKey].Y ~= size.Y then
		drawing.Size = size
		cache[cacheKey] = size
		return true
	end
	return false
end

local function trimLower(str)
	if not str or type(str) ~= "string" then
		return ""
	end
	return string_lower(string_gsub(str, "^%s*(.-)%s*$", "%1"))
end

local function getDistSquared(pos1, pos2)
	local dx, dy, dz = pos1.X - pos2.X, pos1.Y - pos2.Y, pos1.Z - pos2.Z
	return dx * dx + dy * dy + dz * dz
end

local function fastMin(a, b, c, d, e, f, g, h, i)
	local min = a
	if b < min then
		min = b
	end
	if c < min then
		min = c
	end
	if d < min then
		min = d
	end
	if e < min then
		min = e
	end
	if f < min then
		min = f
	end
	if g < min then
		min = g
	end
	if h < min then
		min = h
	end
	if i < min then
		min = i
	end
	return min
end

local function fastMax(a, b, c, d, e, f, g, h, i)
	local max = a
	if b > max then
		max = b
	end
	if c > max then
		max = c
	end
	if d > max then
		max = d
	end
	if e > max then
		max = e
	end
	if f > max then
		max = f
	end
	if g > max then
		max = g
	end
	if h > max then
		max = h
	end
	if i > max then
		max = i
	end
	return max
end

local GradientCache = {}
local function getCachedGradient(colors, rotation)
	if not colors or #colors == 0 then
		return nil
	end

	local key = table_concat({ rotation or 0, colors[1].R, colors[1].G, colors[1].B, #colors }, "_")

	if GradientCache[key] then
		return GradientCache[key]
	end

	local keypoints = {}
	for i, color in ipairs(colors) do
		local time = (i - 1) / (#colors - 1)
		keypoints[#keypoints + 1] = ColorSequenceKeypoint_new(time, color)
	end

	local gradient = ColorSequence_new(keypoints)
	GradientCache[key] = gradient
	return gradient
end

local DefaultSettings = {
	Enabled = false,
	ShowSelf = false,
	MaxDistance = 1000,
	DistanceCheck = "Character",
	TargetFPS = 60,

	TargetList = {
		Friendlies = {},
		Enemies = {},
		ShowFriendlies = true,
		ShowEnemies = true,
		ShowOthers = true,
		FriendlyColor = Color3_fromRGB(0, 255, 0),
		EnemyColor = Color3_fromRGB(255, 0, 0),
		UseDifferentColors = true,
	},

	TeamBasedColor = {
		Enabled = true,
		UseTeamColor = true,
		AllyColor = Color3_fromRGB(0, 255, 0),
		EnemyColor = Color3_fromRGB(255, 0, 0),
		GradientStyle = true,
	},

	FadeOnDeath = {
		Enabled = true,
		FadeTime = 1,
	},

	HealthAnimations = {
		Enabled = true,
		TweenSpeed = 0.15,
		PulseOnLowHealth = true,
		LowHealthThreshold = 0.3,
		PulseSpeed = 2,
	},

	Box = {
		Enabled = true,
		Thickness = 2,
		GradientEnabled = true,
		GradientColors = {
			Color3_fromRGB(0, 85, 255),
			Color3_fromRGB(72, 0, 255),
			Color3_fromRGB(0, 128, 255),
		},
		GradientRotation = 90,
		Color = Color3_fromRGB(255, 255, 255),
		Transparency = 1,
		RotationEnabled = true,
		RotationSpeed = 50,
	},

	BoxFill = {
		Enabled = true,
		GradientEnabled = true,
		GradientColors = {
			Color3_fromRGB(0, 85, 255),
			Color3_fromRGB(72, 0, 255),
			Color3_fromRGB(0, 128, 255),
		},
		GradientRotation = 180,
		Color = Color3_fromRGB(0, 0, 0),
		Transparency = 0.5,
		RotationEnabled = true,
		RotationSpeed = 30,
	},

	HealthBar = {
		Enabled = true,
		Width = 5,
		Offset = 3,
		Position = "Left",
		GradientEnabled = true,
		GradientColors = {
			Color3_fromRGB(255, 0, 0),
			Color3_fromRGB(255, 255, 0),
			Color3_fromRGB(0, 255, 0),
		},
		GradientRotation = 270,
		BackgroundColor = Color3_fromRGB(0, 0, 0),
		BackgroundTransparency = 0.5,
		AnimationEnabled = true,
		AnimationStyle = "Quad",
		AnimationDirection = "InOut",
		AnimationDuration = 0.3,
	},

	HealthValue = {
		Enabled = true,
		Size = 12,
		Font = Drawing.Fonts.Plex,
		Outline = true,
		OutlineColor = Color3_fromRGB(0, 0, 0),
		UseHealthBarColor = true,
		ShowOnlyOnChange = false,
		DisplayDuration = 2,
		ShowDamage = true,
		DamageColor = Color3_fromRGB(255, 50, 50),
	},

	Name = {
		Enabled = true,
		Size = 14,
		Font = Drawing.Fonts.Plex,
		Color = Color3_fromRGB(0, 85, 255),
		Outline = true,
		OutlineColor = Color3_fromRGB(0, 0, 0),
	},

	Distance = {
		Enabled = true,
		Size = 12,
		Font = Drawing.Fonts.Plex,
		Color = Color3_fromRGB(0, 85, 255),
		Outline = true,
		OutlineColor = Color3_fromRGB(0, 0, 0),
	},

	Tool = {
		Enabled = true,
		Size = 12,
		Font = Drawing.Fonts.Plex,
		Color = Color3_fromRGB(246, 255, 0),
		Outline = true,
		OutlineColor = Color3_fromRGB(0, 0, 0),
		ShowNoTool = false,
		ShowBackpack = true,
		BackpackColor = Color3_fromRGB(255, 145, 0),
		MaxBackpackDisplay = 5,
	},

	Stats = {
		Enabled = true,
		Size = 11,
		Font = Drawing.Fonts.Plex,
		Color = Color3_fromRGB(255, 255, 255),
		Outline = true,
		OutlineColor = Color3_fromRGB(0, 0, 0),
		Spacing = 13,
		OffsetY = 5,
		PlayerStats = {},
		ShowPlayerStats = false,
		StatBarWidth = 5,
		StatBarHeight = 4,
		StatBarOffset = 3,
		StatBarBackgroundColor = Color3_fromRGB(0, 0, 0),
		StatBarBackgroundTransparency = 0.5,
		StatBarGradientEnabled = false,
		StatBarGradientColors = {
			Color3_fromRGB(255, 0, 0),
			Color3_fromRGB(0, 255, 0),
		},
		StatBarPosition = "Right",
		StatBarSideOffset = 3,
		StatBarVerticalSpacing = 8,
	},

	Chams = {
		Enabled = true,
		VisibleColor = Color3_fromRGB(0, 255, 0),
		OccludedColor = Color3_fromRGB(255, 0, 0),
		FillTransparency = 0.8,
		UseTeamColors = false,
		OutlineEnabled = true,
		OutlineColor = Color3_fromRGB(0, 0, 0),
		OutlineTransparency = 0,
		SmoothTransition = true,
		TransitionSpeed = 0.1,
		CheckInterval = 0.08,
		UseVisibilityCheck = true,
	},
}

function ESPLibrary:SetPerformanceMode(enabled)
	self.PerformanceMode.Enabled = enabled

	if enabled then
		self:UpdateSettings({
			TargetFPS = 30,
			MaxDistance = 500,
			Chams = { Enabled = false },
			HealthAnimations = { PulseOnLowHealth = false },
			Box = {
				GradientEnabled = false,
				RotationEnabled = false,
			},
			BoxFill = {
				GradientEnabled = false,
				RotationEnabled = false,
			},
		})
	end
end

local RaycastParamsCache = nil
local function isPlayerOccluded(character, camera)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return false
	end

	local head = character:FindFirstChild("Head")
	local rayOrigin = camera.CFrame.Position

	if not RaycastParamsCache then
		RaycastParamsCache = RaycastParams.new()
		RaycastParamsCache.IgnoreWater = true
		RaycastParamsCache.FilterType = Enum.RaycastFilterType.Exclude
	end

	RaycastParamsCache.FilterDescendantsInstances = { character, camera, LocalPlayer.Character }

	local checkPoints = {
		{ offset = Vector3_new(0, 0, 0), weight = 4 },
		{ offset = Vector3_new(0, 1.5, 0), weight = 3 },
		{ offset = Vector3_new(0, -1, 0), weight = 2 },
		{ offset = Vector3_new(1, 0.5, 0), weight = 1.5 },
		{ offset = Vector3_new(-1, 0.5, 0), weight = 1.5 },
	}

	if head then
		local headOffset = head.Position - hrp.Position
		checkPoints[#checkPoints + 1] = { offset = headOffset, weight = 3 }
	end

	local totalWeight = 0
	local visibleWeight = 0

	for _, point in ipairs(checkPoints) do
		local targetPos = hrp.Position + point.offset
		local direction = targetPos - rayOrigin
		local distance = direction.Magnitude

		if distance > 1 then
			local rayResult = workspace:Raycast(rayOrigin, direction, RaycastParamsCache)

			totalWeight = totalWeight + point.weight

			if not rayResult or (rayResult.Position - rayOrigin).Magnitude > distance * 0.95 then
				visibleWeight = visibleWeight + point.weight
			end
		end
	end

	if totalWeight == 0 then
		return false
	end
	return (visibleWeight / totalWeight) < 0.35
end

local TweenFunctions = {}

TweenFunctions.Linear = function(t)
	return t
end

TweenFunctions.QuadIn = function(t)
	return t * t
end
TweenFunctions.QuadOut = function(t)
	return t * (2 - t)
end
TweenFunctions.QuadInOut = function(t)
	if t < 0.5 then
		return 2 * t * t
	else
		return -1 + (4 - 2 * t) * t
	end
end

TweenFunctions.CubicIn = function(t)
	return t * t * t
end
TweenFunctions.CubicOut = function(t)
	return (t - 1) * (t - 1) * (t - 1) + 1
end
TweenFunctions.CubicInOut = function(t)
	if t < 0.5 then
		return 4 * t * t * t
	else
		return (t - 1) * (2 * t - 2) * (2 * t - 2) + 1
	end
end

TweenFunctions.QuartIn = function(t)
	return t * t * t * t
end
TweenFunctions.QuartOut = function(t)
	return 1 - (t - 1) * (t - 1) * (t - 1) * (t - 1)
end
TweenFunctions.QuartInOut = function(t)
	if t < 0.5 then
		return 8 * t * t * t * t
	else
		return 1 - 8 * (t - 1) * (t - 1) * (t - 1) * (t - 1)
	end
end

TweenFunctions.QuintIn = function(t)
	return t * t * t * t * t
end
TweenFunctions.QuintOut = function(t)
	return 1 + (t - 1) * (t - 1) * (t - 1) * (t - 1) * (t - 1)
end
TweenFunctions.QuintInOut = function(t)
	if t < 0.5 then
		return 16 * t * t * t * t * t
	else
		return 1 + 16 * (t - 1) * (t - 1) * (t - 1) * (t - 1) * (t - 1)
	end
end

TweenFunctions.SineIn = function(t)
	return 1 - math_cos(t * math_pi / 2)
end
TweenFunctions.SineOut = function(t)
	return math_sin(t * math_pi / 2)
end
TweenFunctions.SineInOut = function(t)
	return -(math_cos(math_pi * t) - 1) / 2
end

TweenFunctions.ExpoIn = function(t)
	return t == 0 and 0 or math_pow(2, 10 * (t - 1))
end
TweenFunctions.ExpoOut = function(t)
	return t == 1 and 1 or 1 - math_pow(2, -10 * t)
end
TweenFunctions.ExpoInOut = function(t)
	if t == 0 or t == 1 then
		return t
	end
	if t < 0.5 then
		return math_pow(2, 20 * t - 10) / 2
	else
		return (2 - math_pow(2, -20 * t + 10)) / 2
	end
end

TweenFunctions.BackIn = function(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return c3 * t * t * t - c1 * t * t
end
TweenFunctions.BackOut = function(t)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * math_pow(t - 1, 3) + c1 * math_pow(t - 1, 2)
end
TweenFunctions.BackInOut = function(t)
	local c1 = 1.70158
	local c2 = c1 * 1.525
	if t < 0.5 then
		return (math_pow(2 * t, 2) * ((c2 + 1) * 2 * t - c2)) / 2
	else
		return (math_pow(2 * t - 2, 2) * ((c2 + 1) * (t * 2 - 2) + c2) + 2) / 2
	end
end

TweenFunctions.BounceOut = function(t)
	local n1 = 7.5625
	local d1 = 2.75
	if t < 1 / d1 then
		return n1 * t * t
	elseif t < 2 / d1 then
		t = t - 1.5 / d1
		return n1 * t * t + 0.75
	elseif t < 2.5 / d1 then
		t = t - 2.25 / d1
		return n1 * t * t + 0.9375
	else
		t = t - 2.625 / d1
		return n1 * t * t + 0.984375
	end
end
TweenFunctions.BounceIn = function(t)
	return 1 - TweenFunctions.BounceOut(1 - t)
end
TweenFunctions.BounceInOut = function(t)
	if t < 0.5 then
		return (1 - TweenFunctions.BounceOut(1 - 2 * t)) / 2
	else
		return (1 + TweenFunctions.BounceOut(2 * t - 1)) / 2
	end
end

TweenFunctions.ElasticIn = function(t)
	local c4 = (2 * math_pi) / 3
	if t == 0 or t == 1 then
		return t
	end
	return -math_pow(2, 10 * t - 10) * math_sin((t * 10 - 10.75) * c4)
end
TweenFunctions.ElasticOut = function(t)
	local c4 = (2 * math_pi) / 3
	if t == 0 or t == 1 then
		return t
	end
	return math_pow(2, -10 * t) * math_sin((t * 10 - 0.75) * c4) + 1
end
TweenFunctions.ElasticInOut = function(t)
	local c5 = (2 * math_pi) / 4.5
	if t == 0 or t == 1 then
		return t
	end
	if t < 0.5 then
		return -(math_pow(2, 20 * t - 10) * math_sin((20 * t - 11.125) * c5)) / 2
	else
		return (math_pow(2, -20 * t + 10) * math_sin((20 * t - 11.125) * c5)) / 2 + 1
	end
end

local function GetTweenFunction(style, direction)
	local key = style .. direction
	return TweenFunctions[key] or TweenFunctions.Linear
end

local IMPORTANT_PART_NAMES = {
	"Head",
	"Torso",
	"UpperTorso",
	"Left Arm",
	"LeftUpperArm",
	"Right Arm",
	"RightUpperArm",
	"Left Leg",
	"LeftUpperLeg",
	"Right Leg",
	"RightUpperLeg",
	"LeftFoot",
	"RightFoot",
	"LeftLowerLeg",
	"RightLowerLeg",
}

function ESPLibrary.new(customSettings)
	local self = {
		Settings = {},
		ESPObjects = {},
		StartTime = tick(),
		LastUpdateTime = 0,
		Connections = {},
		IsRunning = false,
		ToolCache = {},
		BackpackCache = {},
		Overrides = {
			GetTeam = nil,
			IsTeamMate = nil,
			GetColor = nil,
			GetPlrFromChar = nil,
			UpdateAllow = nil,
		},
		CustomObjects = {},
		CustomObjectListeners = {},
		CustomDrawingObjects = {},
		PerformanceMode = {
			Enabled = false,
			Settings = {
				MaxPlayersPerFrame = 20,
				UpdateInterval = 1 / 30,
				DisableChams = true,
				DisableGradients = true,
				DisableHealthPulse = true,
				ReducedDistanceChecks = true,
				MaxDistance = 500,
			},
		},
	}

	for k, v in pairs(DefaultSettings) do
		if type(v) == "table" then
			self.Settings[k] = {}
			for k2, v2 in pairs(v) do
				if type(v2) == "table" then
					self.Settings[k][k2] = {}
					for k3, v3 in pairs(v2) do
						self.Settings[k][k2][k3] = v3
					end
				else
					self.Settings[k][k2] = v2
				end
			end
		else
			self.Settings[k] = v
		end
	end

	if customSettings then
		for k, v in pairs(customSettings) do
			if type(v) == "table" and self.Settings[k] then
				for k2, v2 in pairs(v) do
					if type(v2) == "table" and (k2 == "Friendlies" or k2 == "Enemies") then
						self.Settings[k][k2] = v2
					else
						self.Settings[k][k2] = v2
					end
				end
			else
				self.Settings[k] = v
			end
		end
	end

	self.UpdateInterval = 1 / self.Settings.TargetFPS
	self.MAX_DISTANCE_SQUARED = self.Settings.MaxDistance * self.Settings.MaxDistance
	self.HEALTH_GRADIENT_MIDPOINT = 0.5
	self.HEALTH_GRADIENT_SCALE = 2

	local mt = {
		__index = function(t, key)
			if rawget(t, "Settings") and rawget(t, "Settings")[key] ~= nil then
				return rawget(t, "Settings")[key]
			end
			return ESPLibrary[key]
		end,

		__newindex = function(t, key, value)
			if rawget(t, "Settings") and rawget(t, "Settings")[key] ~= nil then
				if type(value) == "table" and type(rawget(t, "Settings")[key]) == "table" then
					for k, v in pairs(value) do
						rawget(t, "Settings")[key][k] = v

						if key == "TeamBasedColor" and k == "Enabled" and v == false then
							TeamColorCache = {}
							for player, esp in pairs(rawget(t, "ESPObjects")) do
								if player.Parent then
									t:ResetPlayerESPColors(player)
								end
							end
						end
					end
				else
					rawget(t, "Settings")[key] = value
				end

				if key == "MaxDistance" then
					rawset(t, "MAX_DISTANCE_SQUARED", value * value)
				elseif key == "TargetFPS" then
					rawset(t, "UpdateInterval", 1 / value)
				end
			else
				rawset(t, key, value)
			end
		end,
	}

	setmetatable(self, mt)

	return self
end

function ESPLibrary:SetOverride(overrideName, overrideFunction)
	if self.Overrides[overrideName] ~= nil then
		self.Overrides[overrideName] = overrideFunction
	end
end

function ESPLibrary:GetTeamOverride(player)
	if self.Overrides.GetTeam then
		return self.Overrides.GetTeam(player)
	end
	return player.Team
end

function ESPLibrary:IsTeamMateOverride(player)
	if self.Overrides.IsTeamMate then
		return self.Overrides.IsTeamMate(player)
	end
	return player.Team and LocalPlayer.Team and player.Team == LocalPlayer.Team
end

function ESPLibrary:GetColorOverride(object)
	if self.Overrides.GetColor then
		return self.Overrides.GetColor(object)
	end
	return nil
end

function ESPLibrary:GetPlrFromCharOverride(char)
	if self.Overrides.GetPlrFromChar then
		return self.Overrides.GetPlrFromChar(char)
	end
	return Players:GetPlayerFromCharacter(char)
end

function ESPLibrary:UpdateAllowOverride(box)
	if self.Overrides.UpdateAllow then
		return self.Overrides.UpdateAllow(box)
	end
	return true
end

function ESPLibrary:AddObjectListener(parent, options)
	if not parent then
		return
	end

	if not parent.Parent then
		return
	end

	options = options or {}
	local listenerData = {
		Parent = parent,
		Type = options.Type,
		Name = options.Name,
		Validator = options.Validator,
		PrimaryPart = options.PrimaryPart,
		Color = options.Color,
		ColorDynamic = options.ColorDynamic,
		CustomName = options.CustomName,
		IsEnabled = options.IsEnabled ~= nil and options.IsEnabled or true,
		Recursive = options.Recursive ~= false,
		ProcessedObjects = {},
		HumanoidPath = options.HumanoidPath,
		UseHealthBar = options.UseHealthBar ~= false,
		Stats = options.Stats or {},
		ShowStats = options.ShowStats ~= false,
		AllowMultipleSameName = options.AllowMultipleSameName ~= false,
	}

	self.CustomObjectListeners[#self.CustomObjectListeners + 1] = listenerData

	local function processChild(child)
		if not child or not child.Parent then
			return
		end

		if listenerData.ProcessedObjects[child] then
			return
		end

		if listenerData.Type and not child:IsA(listenerData.Type) then
			return
		end

		if listenerData.Name and child.Name ~= listenerData.Name then
			return
		end

		if listenerData.Validator then
			local success, result = pcall(listenerData.Validator, child)
			if not success or not result then
				return
			end
		end

		listenerData.ProcessedObjects[child] = true

		self:AddCustomObject(child, listenerData)
	end

	local processDepth = 0
	local MAX_DEPTH = 10

	local function processDescendants(container)
		processDepth = processDepth + 1

		if processDepth > MAX_DEPTH then
			processDepth = processDepth - 1
			return
		end

		if not container or not container.Parent then
			processDepth = processDepth - 1
			return
		end

		local success, children = pcall(function()
			return container:GetChildren()
		end)

		if not success then
			processDepth = processDepth - 1
			return
		end

		for _, child in ipairs(children) do
			if child and child.Parent then
				processChild(child)

				if listenerData.Recursive and processDepth < MAX_DEPTH then
					processDescendants(child)
				end
			end
		end

		processDepth = processDepth - 1
	end

	local success, err = pcall(function()
		processDescendants(parent)
	end)

	local conn = cache(parent.ChildAdded:Connect(function(child)
		task.spawn(function()
			task.wait(0.1)

			if child and child.Parent then
				local success, err = pcall(processChild, child)
			end
		end)
	end))

	self.Connections[#self.Connections + 1] = conn

	if listenerData.Recursive and parent ~= workspace then
		local descConn = cache(parent.DescendantAdded:Connect(function(child)
			task.spawn(function()
				task.wait(0.1)

				if child and child.Parent then
					local success, err = pcall(processChild, child)
				end
			end)
		end))
		self.Connections[#self.Connections + 1] = descConn
	end

	return listenerData
end

function ESPLibrary:GetCustomObjectHumanoid(object, listenerData)
	if listenerData.HumanoidPath then
		if type(listenerData.HumanoidPath) == "function" then
			local success, humanoid = pcall(listenerData.HumanoidPath, object)
			if success and humanoid and humanoid:IsA("Humanoid") then
				return humanoid
			end
		elseif type(listenerData.HumanoidPath) == "string" then
			local humanoid = object:FindFirstChild(listenerData.HumanoidPath)
			if humanoid and humanoid:IsA("Humanoid") then
				return humanoid
			end
		end
	end

	return object:FindFirstChildOfClass("Humanoid")
end

function ESPLibrary:GetCustomObjectSize(object, primaryPart)
	if not primaryPart then
		return nil
	end

	local hrpCF = primaryPart.CFrame
	local hrpPos = primaryPart.Position
	local minX, minY, minZ = math_huge, math_huge, math_huge
	local maxX, maxY, maxZ = -math_huge, -math_huge, -math_huge

	local MAX_PART_DISTANCE = 10
	local MAX_PART_DISTANCE_SQUARED = MAX_PART_DISTANCE * MAX_PART_DISTANCE

	local parts = {}
	for _, desc in ipairs(object:GetDescendants()) do
		if desc:IsA("BasePart") and desc ~= primaryPart then
			local diff = desc.Position - hrpPos
			local distSquared = diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z

			if distSquared <= MAX_PART_DISTANCE_SQUARED then
				parts[#parts + 1] = desc
			end
		end
	end

	parts[#parts + 1] = primaryPart

	for _, part in ipairs(parts) do
		local cf = part.CFrame
		local size = part.Size
		local sx, sy, sz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5

		local c1 = cf * CFrame_new(-sx, -sy, -sz)
		local c2 = cf * CFrame_new(sx, -sy, -sz)
		local c3 = cf * CFrame_new(-sx, sy, -sz)
		local c4 = cf * CFrame_new(sx, sy, -sz)
		local c5 = cf * CFrame_new(-sx, -sy, sz)
		local c6 = cf * CFrame_new(sx, -sy, sz)
		local c7 = cf * CFrame_new(-sx, sy, sz)
		local c8 = cf * CFrame_new(sx, sy, sz)

		local r1 = hrpCF:PointToObjectSpace(c1.Position)
		local r2 = hrpCF:PointToObjectSpace(c2.Position)
		local r3 = hrpCF:PointToObjectSpace(c3.Position)
		local r4 = hrpCF:PointToObjectSpace(c4.Position)
		local r5 = hrpCF:PointToObjectSpace(c5.Position)
		local r6 = hrpCF:PointToObjectSpace(c6.Position)
		local r7 = hrpCF:PointToObjectSpace(c7.Position)
		local r8 = hrpCF:PointToObjectSpace(c8.Position)

		minX = math_min(minX, r1.X, r2.X, r3.X, r4.X, r5.X, r6.X, r7.X, r8.X)
		minY = math_min(minY, r1.Y, r2.Y, r3.Y, r4.Y, r5.Y, r6.Y, r7.Y, r8.Y)
		minZ = math_min(minZ, r1.Z, r2.Z, r3.Z, r4.Z, r5.Z, r6.Z, r7.Z, r8.Z)
		maxX = math_max(maxX, r1.X, r2.X, r3.X, r4.X, r5.X, r6.X, r7.X, r8.X)
		maxY = math_max(maxY, r1.Y, r2.Y, r3.Y, r4.Y, r5.Y, r6.Y, r7.Y, r8.Y)
		maxZ = math_max(maxZ, r1.Z, r2.Z, r3.Z, r4.Z, r5.Z, r6.Z, r7.Z, r8.Z)
	end

	return Vector3_new((maxX - minX) * 1.05, (maxY - minY) * 1.08, (maxZ - minZ) * 1.05)
end

local function isDrawingValid(drawing)
	if not drawing then
		return false
	end
	local success = pcall(function()
		local _ = drawing.Visible
	end)
	return success
end

local function createHighlight(parent)
	local highlight = cache(Instance_new("Highlight"))
	highlight.Adornee = parent
	highlight.FillColor = Color3_fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.OutlineColor = Color3_fromRGB(0, 0, 0)
	highlight.OutlineTransparency = 0.5
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = true
	highlight.Parent = parent
	return highlight
end

function ESPLibrary:GetStatValue(object, statDef)
	if type(statDef.Path) == "function" then
		local success, value = pcall(statDef.Path, object)
		if success then
			return value
		end
		return nil
	end

	return nil
end

function ESPLibrary:GetPlayerStatValue(player, character, statDef)
	if type(statDef.Path) == "function" then
		local success, value = pcall(statDef.Path, player, character)
		if success then
			return value
		end
		return nil
	end

	return nil
end

function ESPLibrary:AddCustomObject(object, listenerData)
	if not object or not object.Parent then
		return
	end

	if self.CustomObjects[object] then
		return
	end

	local humanoid = self:GetCustomObjectHumanoid(object, listenerData)
	local isNPC = humanoid ~= nil and listenerData.UseHealthBar

	local objectData = {
		Object = object,
		ListenerData = listenerData,
		Type = isNPC and "NPC" or "CustomObject",
		Drawings = {},
		HealthAnimData = {
			CurrentHealth = isNPC and (humanoid.Health / humanoid.MaxHealth) or 1,
			TargetHealth = isNPC and (humanoid.Health / humanoid.MaxHealth) or 1,
		},
		FadeData = { IsFading = false, FadeAlpha = 1 },
		CachedSize = nil,
		SizeUpdateNeeded = true,
		Humanoid = humanoid,
		IsNPC = isNPC,
		StatTexts = {},
	}

	local success, err = pcall(function()
		objectData.Drawings.BoxOuterStroke = Drawing.new("Square")
		objectData.Drawings.BoxOutline = Drawing.new("Square")
		objectData.Drawings.BoxInnerStroke = Drawing.new("Square")

		objectData.Drawings.BoxFill = Drawing.new("Square")
		objectData.Drawings.Name = Drawing.new("Text")
		objectData.Drawings.Distance = Drawing.new("Text")

		if isNPC then
			objectData.Drawings.HealthBarBg = Drawing.new("Square")
			objectData.Drawings.HealthBar = Drawing.new("Square")
			objectData.Drawings.HealthValue = Drawing.new("Text")
		end

		if listenerData.ShowStats and #listenerData.Stats > 0 then
			for i = 1, #listenerData.Stats do
				local statText = Drawing.new("Text")
				statText.Size = self.Settings.Stats.Size
				statText.Font = self.Settings.Stats.Font
				statText.Color = self.Settings.Stats.Color
				statText.Outline = self.Settings.Stats.Outline
				statText.OutlineColor = self.Settings.Stats.OutlineColor
				statText.Center = true
				statText.ZIndex = 3
				statText.Visible = false
				objectData.StatTexts[#objectData.StatTexts + 1] = statText
			end
		end

		local outerStroke = objectData.Drawings.BoxOuterStroke
		outerStroke.Filled = false
		outerStroke.Thickness = 1
		outerStroke.Transparency = 1
		outerStroke.Color = Color3_fromRGB(0, 0, 0)
		outerStroke.ZIndex = 1
		outerStroke.Visible = false

		local outline = objectData.Drawings.BoxOutline
		outline.Filled = false
		outline.Thickness = self.Settings.Box.Thickness
		outline.Transparency = self.Settings.Box.Transparency
		outline.Color = self.Settings.Box.Color
		outline.ZIndex = 2
		outline.Visible = false
		outline.StrokeGradientEnabled = self.Settings.Box.GradientEnabled
		outline.StrokeGradientColors = self.Settings.Box.GradientColors
		outline.StrokeGradientRotation = self.Settings.Box.GradientRotation

		local innerStroke = objectData.Drawings.BoxInnerStroke
		innerStroke.Filled = false
		innerStroke.Thickness = 1
		innerStroke.Transparency = 1
		innerStroke.Color = Color3_fromRGB(0, 0, 0)
		innerStroke.ZIndex = 3
		innerStroke.Visible = false

		local fill = objectData.Drawings.BoxFill
		fill.Filled = true
		fill.Transparency = self.Settings.BoxFill.Transparency
		fill.GradientEnabled = self.Settings.BoxFill.GradientEnabled
		fill.GradientColors = self.Settings.BoxFill.GradientColors
		fill.GradientRotation = self.Settings.BoxFill.GradientRotation
		fill.Color = self.Settings.BoxFill.Color
		fill.ZIndex = 1
		fill.Visible = false

		local name = objectData.Drawings.Name
		name.Text = listenerData.CustomName and listenerData.CustomName(object) or object.Name
		name.Size = self.Settings.Name.Size
		name.Font = self.Settings.Name.Font
		name.Color = self.Settings.Name.Color
		name.Outline = self.Settings.Name.Outline
		name.OutlineColor = self.Settings.Name.OutlineColor
		name.Center = true
		name.ZIndex = 3
		name.Visible = false

		local dist = objectData.Drawings.Distance
		dist.Size = self.Settings.Distance.Size
		dist.Font = self.Settings.Distance.Font
		dist.Color = self.Settings.Distance.Color
		dist.Outline = self.Settings.Distance.Outline
		dist.OutlineColor = self.Settings.Distance.OutlineColor
		dist.Center = true
		dist.ZIndex = 3
		dist.Visible = false

		if isNPC then
			local hpBg = objectData.Drawings.HealthBarBg
			hpBg.Filled = true
			hpBg.Transparency = self.Settings.HealthBar.BackgroundTransparency
			hpBg.Color = self.Settings.HealthBar.BackgroundColor
			hpBg.ZIndex = 1
			hpBg.Visible = false

			local hp = objectData.Drawings.HealthBar
			hp.Filled = true
			hp.Transparency = 1
			hp.GradientEnabled = self.Settings.HealthBar.GradientEnabled
			hp.GradientColors = self.Settings.HealthBar.GradientColors
			hp.GradientRotation = self.Settings.HealthBar.GradientRotation
			hp.ZIndex = 2
			hp.Visible = false

			local hpVal = objectData.Drawings.HealthValue
			hpVal.Size = self.Settings.HealthValue.Size
			hpVal.Font = self.Settings.HealthValue.Font
			hpVal.Outline = self.Settings.HealthValue.Outline
			hpVal.OutlineColor = self.Settings.HealthValue.OutlineColor
			hpVal.Center = true
			hpVal.ZIndex = 3
			hpVal.Visible = false
		end
	end)

	if not success then
		return
	end

	self.CustomObjects[object] = objectData

	local conn = cache(object.AncestryChanged:Connect(function(_, parent)
		if not parent then
			pcall(function()
				self:RemoveCustomObject(object)
			end)
		end
	end))
	self.Connections[#self.Connections + 1] = conn

	if isNPC and humanoid then
		local healthConn = cache(humanoid.HealthChanged:Connect(function(health)
			if objectData and humanoid and humanoid.Parent then
				objectData.HealthAnimData.TargetHealth = health / humanoid.MaxHealth
			end
		end))
		self.Connections[#self.Connections + 1] = healthConn

		local diedConn = cache(humanoid.Died:Connect(function()
			if self.Settings.FadeOnDeath.Enabled and objectData then
				objectData.FadeData.IsFading = true
				objectData.FadeData.FadeStart = tick()
			end
		end))
		self.Connections[#self.Connections + 1] = diedConn
	end
end

function ESPLibrary:RemoveCustomObject(object)
	local objectData = self.CustomObjects[object]
	if objectData then
		pcall(function()
			if isDrawingValid(objectData.Drawings.BoxOuterStroke) then
				objectData.Drawings.BoxOuterStroke:Remove()
			end
			if isDrawingValid(objectData.Drawings.BoxOutline) then
				objectData.Drawings.BoxOutline:Remove()
			end
			if isDrawingValid(objectData.Drawings.BoxInnerStroke) then
				objectData.Drawings.BoxInnerStroke:Remove()
			end

			if isDrawingValid(objectData.Drawings.BoxFill) then
				objectData.Drawings.BoxFill:Remove()
			end
			if isDrawingValid(objectData.Drawings.Name) then
				objectData.Drawings.Name:Remove()
			end
			if isDrawingValid(objectData.Drawings.Distance) then
				objectData.Drawings.Distance:Remove()
			end

			if objectData.IsNPC then
				if isDrawingValid(objectData.Drawings.HealthBarBg) then
					objectData.Drawings.HealthBarBg:Remove()
				end
				if isDrawingValid(objectData.Drawings.HealthBar) then
					objectData.Drawings.HealthBar:Remove()
				end
				if isDrawingValid(objectData.Drawings.HealthValue) then
					objectData.Drawings.HealthValue:Remove()
				end
			end

			for _, statText in ipairs(objectData.StatTexts) do
				if isDrawingValid(statText) then
					statText:Remove()
				end
			end
		end)

		self.CustomObjects[object] = nil
	end
end

function ESPLibrary:UpdateCustomObject(objectData)
	local object = objectData.Object
	local listenerData = objectData.ListenerData

	if not object or not object.Parent then
		self:RemoveCustomObject(object)
		return
	end

	if not isDrawingValid(objectData.Drawings.BoxFill) then
		self:RemoveCustomObject(object)
		return
	end

	if listenerData.IsEnabled ~= nil then
		local enabled = false

		if type(listenerData.IsEnabled) == "boolean" then
			enabled = listenerData.IsEnabled
		elseif type(listenerData.IsEnabled) == "string" then
			local lowerEnabled = listenerData.IsEnabled:lower()
			if lowerEnabled == "true" then
				enabled = true
			elseif lowerEnabled == "false" then
				enabled = false
			else
				if self[listenerData.IsEnabled] ~= nil then
					enabled = self[listenerData.IsEnabled] == true
				else
					enabled = true
				end
			end
		elseif type(listenerData.IsEnabled) == "function" then
			local success, result = pcall(listenerData.IsEnabled, object)
			if success then
				enabled = result == true
			end
		end

		if not enabled then
			self:HideCustomObjectESP(objectData)
			return
		end
	end

	local primaryPart
	if listenerData.PrimaryPart then
		if type(listenerData.PrimaryPart) == "function" then
			primaryPart = listenerData.PrimaryPart(object)
		else
			primaryPart = object:FindFirstChild(listenerData.PrimaryPart)
		end
	else
		primaryPart = object:FindFirstChild("HumanoidRootPart") or object.PrimaryPart or object:FindFirstChildWhichIsA("BasePart")
	end

	if not primaryPart or not primaryPart:IsA("BasePart") then
		self:HideCustomObjectESP(objectData)
		return
	end

	local hrpPos = primaryPart.Position
	local camPos = CurrentCamera.CFrame.Position
	local diff = hrpPos - camPos
	local distSquared = diff.X * diff.X + diff.Y * diff.Y + diff.Z * diff.Z

	if distSquared > self.MAX_DISTANCE_SQUARED then
		self:HideCustomObjectESP(objectData)
		return
	end

	local distance = math_sqrt(distSquared)

	if objectData.SizeUpdateNeeded then
		objectData.CachedSize = self:GetCustomObjectSize(object, primaryPart)
		objectData.SizeUpdateNeeded = false
	end

	local humanoid = objectData.Humanoid
	if objectData.IsNPC and humanoid and humanoid.Parent then
		local healthPercent = humanoid.Health / humanoid.MaxHealth

		local isDead = humanoid.Health <= 0
		if isDead and self.Settings.FadeOnDeath.Enabled then
			if not objectData.FadeData.IsFading then
				objectData.FadeData.IsFading = true
				objectData.FadeData.FadeStart = tick()
			end

			local elapsed = tick() - objectData.FadeData.FadeStart
			objectData.FadeData.FadeAlpha = math_max(0, 1 - (elapsed / self.Settings.FadeOnDeath.FadeTime))

			if objectData.FadeData.FadeAlpha <= 0 then
				self:HideCustomObjectESP(objectData)
				return
			end
		else
			objectData.FadeData.IsFading = false
			objectData.FadeData.FadeAlpha = 1
		end

		if self.Settings.HealthAnimations.Enabled then
			objectData.HealthAnimData.TargetHealth = healthPercent
			local diff = objectData.HealthAnimData.TargetHealth - objectData.HealthAnimData.CurrentHealth
			objectData.HealthAnimData.CurrentHealth = objectData.HealthAnimData.CurrentHealth + (diff * self.Settings.HealthAnimations.TweenSpeed)
		else
			objectData.HealthAnimData.CurrentHealth = healthPercent
		end
	end

	local baseFadeAlpha = objectData.FadeData.FadeAlpha
	local healthBarPulse = 1

	if objectData.IsNPC and humanoid and humanoid.Parent then
		local healthPercent = humanoid.Health / humanoid.MaxHealth
		if self.Settings.HealthAnimations.PulseOnLowHealth and healthPercent < self.Settings.HealthAnimations.LowHealthThreshold then
			local pulse = math_abs(math_sin(tick() * self.Settings.HealthAnimations.PulseSpeed))
			healthBarPulse = 0.5 + pulse * 0.5
			objectData.FadeData.FadeAlpha = baseFadeAlpha * healthBarPulse
		else
			objectData.FadeData.FadeAlpha = baseFadeAlpha
		end
	end

	local customColor
	if listenerData.Color then
		if type(listenerData.Color) == "function" then
			customColor = listenerData.Color(object)
		else
			customColor = listenerData.Color
		end
	end

	if listenerData.ColorDynamic and type(listenerData.ColorDynamic) == "function" then
		customColor = listenerData.ColorDynamic(object)
	end

	local box = self:GetBoundingBox(primaryPart, objectData.CachedSize)
	if not box then
		self:HideCustomObjectESP(objectData)
		return
	end

	local pos = box.Position
	local size = box.Size

	local currentTime = tick() - self.StartTime
	local boxRotation = self.Settings.Box.RotationEnabled and (currentTime * self.Settings.Box.RotationSpeed) % 360 or self.Settings.Box.GradientRotation
	local boxFillRotation = self.Settings.BoxFill.RotationEnabled and (currentTime * self.Settings.BoxFill.RotationSpeed) % 360 or self.Settings.BoxFill.GradientRotation

	if self.Settings.Box.Enabled then
		local thickness = self.Settings.Box.Thickness

		local outerStroke = objectData.Drawings.BoxOuterStroke
		outerStroke.Position = Vector2_new(pos.X - 1, pos.Y - 1)
		outerStroke.Size = Vector2_new(size.X + 2, size.Y + 2)
		outerStroke.Transparency = 1 * objectData.FadeData.FadeAlpha
		outerStroke.Visible = true

		local outline = objectData.Drawings.BoxOutline
		outline.Position = pos
		outline.Size = size
		outline.Transparency = self.Settings.Box.Transparency * objectData.FadeData.FadeAlpha
		outline.Thickness = thickness
		outline.StrokeGradientRotation = boxRotation

		if customColor then
			outline.StrokeGradientEnabled = false
			outline.Color = customColor
		else
			outline.StrokeGradientEnabled = self.Settings.Box.GradientEnabled
			outline.StrokeGradientColors = self.Settings.Box.GradientColors
			outline.Color = self.Settings.Box.Color
		end

		outline.Visible = true

		local innerStroke = objectData.Drawings.BoxInnerStroke
		innerStroke.Position = Vector2_new(pos.X + 1, pos.Y + 1)
		innerStroke.Size = Vector2_new(size.X - 2, size.Y - 2)
		innerStroke.Transparency = 1 * objectData.FadeData.FadeAlpha
		innerStroke.Visible = true
	else
		objectData.Drawings.BoxOuterStroke.Visible = false
		objectData.Drawings.BoxOutline.Visible = false
		objectData.Drawings.BoxInnerStroke.Visible = false
	end

	if self.Settings.BoxFill.Enabled then
		local fill = objectData.Drawings.BoxFill
		fill.Position = pos
		fill.Size = size
		fill.Transparency = self.Settings.BoxFill.Transparency * objectData.FadeData.FadeAlpha
		fill.GradientRotation = boxFillRotation

		if customColor then
			fill.GradientEnabled = false
			fill.Color = customColor
		else
			fill.GradientEnabled = self.Settings.BoxFill.GradientEnabled
			fill.GradientColors = self.Settings.BoxFill.GradientColors
			fill.Color = self.Settings.BoxFill.Color
		end

		fill.Visible = true
	else
		objectData.Drawings.BoxFill.Visible = false
	end

	if objectData.IsNPC and self.Settings.HealthBar.Enabled and humanoid and humanoid.Parent then
		local barHeight = size.Y
		local barWidth = self.Settings.HealthBar.Width
		local offset = self.Settings.HealthBar.Offset

		local hpBg = objectData.Drawings.HealthBarBg
		hpBg.Position = Vector2_new(pos.X - offset - barWidth, pos.Y)
		hpBg.Size = Vector2_new(barWidth, barHeight)
		hpBg.Transparency = self.Settings.HealthBar.BackgroundTransparency * baseFadeAlpha
		hpBg.Visible = true

		local hp = objectData.Drawings.HealthBar
		local currentHeight = barHeight * objectData.HealthAnimData.CurrentHealth
		hp.Position = Vector2_new(pos.X - offset - barWidth, pos.Y + barHeight - currentHeight)
		hp.Size = Vector2_new(barWidth, currentHeight)
		hp.Transparency = 1 * baseFadeAlpha * healthBarPulse
		hp.Visible = true
	elseif objectData.IsNPC then
		objectData.Drawings.HealthBarBg.Visible = false
		objectData.Drawings.HealthBar.Visible = false
	end

	if objectData.IsNPC and self.Settings.HealthValue.Enabled and humanoid and humanoid.Parent then
		local hpVal = objectData.Drawings.HealthValue
		local healthInt = math_floor(humanoid.Health)
		hpVal.Text = tostring(healthInt)

		if self.Settings.HealthValue.UseHealthBarColor then
			hpVal.Color = self:GetHealthBarColor(objectData.HealthAnimData.CurrentHealth)
		end

		local barWidth = self.Settings.HealthBar.Width
		local offset = self.Settings.HealthBar.Offset
		hpVal.Position = Vector2_new(pos.X - offset - barWidth - 15, pos.Y + size.Y * 0.5)
		hpVal.Transparency = 1 * baseFadeAlpha * healthBarPulse
		hpVal.Visible = true
	elseif objectData.IsNPC then
		objectData.Drawings.HealthValue.Visible = false
	end

	if self.Settings.Name.Enabled then
		local name = objectData.Drawings.Name
		if listenerData.CustomName then
			name.Text = listenerData.CustomName(object)
		end
		name.Position = Vector2_new(pos.X + size.X * 0.5, pos.Y - 18)
		name.Transparency = 1 * objectData.FadeData.FadeAlpha
		if customColor then
			name.Color = customColor
		end
		name.Visible = true
	else
		objectData.Drawings.Name.Visible = false
	end

	if self.Settings.Distance.Enabled then
		local dist = objectData.Drawings.Distance
		dist.Text = string_format("%.0f studs", distance)
		dist.Position = Vector2_new(pos.X + size.X * 0.5, pos.Y + size.Y + 2)
		dist.Transparency = 1 * objectData.FadeData.FadeAlpha
		if customColor then
			dist.Color = customColor
		end
		dist.Visible = true
	else
		objectData.Drawings.Distance.Visible = false
	end

	if self.Settings.Stats.Enabled and listenerData.ShowStats and #listenerData.Stats > 0 then
		local startY = pos.Y + size.Y + (self.Settings.Distance.Enabled and (self.Settings.Distance.Size + 2) or 0) + self.Settings.Stats.OffsetY

		for i = 1, #listenerData.Stats do
			local statDef = listenerData.Stats[i]
			local statText = objectData.StatTexts[i]

			if statText and isDrawingValid(statText) then
				local statValue = self:GetStatValue(object, statDef)

				if statValue ~= nil then
					local displayText = statDef.Name and (statDef.Name .. ": ") or ""

					if statDef.Format then
						if type(statDef.Format) == "function" then
							displayText = displayText .. statDef.Format(statValue)
						elseif type(statDef.Format) == "string" then
							displayText = displayText .. string_format(statDef.Format, statValue)
						else
							displayText = displayText .. tostring(statValue)
						end
					else
						displayText = displayText .. tostring(statValue)
					end

					statText.Text = displayText
					statText.Position = Vector2_new(pos.X + size.X * 0.5, startY)
					statText.Transparency = 1 * objectData.FadeData.FadeAlpha

					if statDef.Color then
						statText.Color = statDef.Color
					elseif customColor then
						statText.Color = customColor
					else
						statText.Color = self.Settings.Stats.Color
					end

					statText.Visible = true

					startY = startY + self.Settings.Stats.Spacing
				else
					statText.Visible = false
				end
			end
		end
	else
		for _, statText in ipairs(objectData.StatTexts) do
			if isDrawingValid(statText) then
				statText.Visible = false
			end
		end
	end
end

function ESPLibrary:HideCustomObjectESP(objectData)
	if isDrawingValid(objectData.Drawings.BoxOuterStroke) then
		objectData.Drawings.BoxOuterStroke.Visible = false
	end
	if isDrawingValid(objectData.Drawings.BoxOutline) then
		objectData.Drawings.BoxOutline.Visible = false
	end
	if isDrawingValid(objectData.Drawings.BoxInnerStroke) then
		objectData.Drawings.BoxInnerStroke.Visible = false
	end

	for _, statText in ipairs(objectData.StatTexts) do
		if isDrawingValid(statText) then
			statText.Visible = false
		end
	end
	objectData.Drawings.BoxFill.Visible = false
	objectData.Drawings.Name.Visible = false
	objectData.Drawings.Distance.Visible = false

	if objectData.IsNPC then
		objectData.Drawings.HealthBarBg.Visible = false
		objectData.Drawings.HealthBar.Visible = false
		objectData.Drawings.HealthValue.Visible = false
	end
end

function ESPLibrary:AddCustomDrawing(drawingObject, updateFunction)
	if not drawingObject or not updateFunction then
		return
	end

	local customDrawing = {
		Drawing = drawingObject,
		Update = updateFunction,
	}

	self.CustomDrawingObjects[#self.CustomDrawingObjects + 1] = customDrawing
	return customDrawing
end

function ESPLibrary:RemoveCustomDrawing(customDrawing)
	for i, drawing in ipairs(self.CustomDrawingObjects) do
		if drawing == customDrawing then
			table.remove(self.CustomDrawingObjects, i)
			return true
		end
	end
	return false
end

function ESPLibrary:UpdateSettings(newSettings)
	for k, v in pairs(newSettings) do
		if type(v) == "table" and self.Settings[k] then
			for k2, v2 in pairs(v) do
				self.Settings[k][k2] = v2
			end
		else
			self.Settings[k] = v
		end
	end

	if newSettings.MaxDistance then
		self.MAX_DISTANCE_SQUARED = newSettings.MaxDistance * newSettings.MaxDistance
	end

	if newSettings.TargetFPS then
		self.UpdateInterval = 1 / newSettings.TargetFPS
	end

	if newSettings.Box and (newSettings.Box.GradientColors or newSettings.Box.GradientRotation) then
		self:InvalidateGradientCache()
	end
	if newSettings.BoxFill and (newSettings.BoxFill.GradientColors or newSettings.BoxFill.GradientRotation) then
		self:InvalidateGradientCache()
	end
end

function ESPLibrary:SetPerformanceMode(enabled)
	self.PerformanceMode.Enabled = enabled

	if enabled then
		self:UpdateSettings({
			TargetFPS = 30,
			MaxDistance = 500,
			Chams = { Enabled = false },
			HealthAnimations = { PulseOnLowHealth = false },
			Box = {
				GradientEnabled = false,
				RotationEnabled = false,
			},
			BoxFill = {
				GradientEnabled = false,
				RotationEnabled = false,
			},
		})
	end
end

function ESPLibrary:FindPlayer(searchName)
	if not searchName or type(searchName) ~= "string" or searchName == "" then
		return nil
	end

	local lower = trimLower(searchName)
	if lower == "" then
		return nil
	end

	local startsMatch, containsMatch

	for _, player in ipairs(Players:GetPlayers()) do
		local name = trimLower(player.Name)
		local display = trimLower(player.DisplayName)

		if name == lower or display == lower then
			return player
		end

		if not startsMatch then
			if string_sub(name, 1, #lower) == lower or string_sub(display, 1, #lower) == lower then
				startsMatch = player
			end
		end

		if not containsMatch then
			if string_find(name, lower, 1, true) or string_find(display, lower, 1, true) then
				containsMatch = player
			end
		end
	end

	return startsMatch or containsMatch
end

function ESPLibrary:GetPlayerType(player)
	local playerName = player.Name
	local targetList = self.Settings.TargetList

	if not targetList._friendlyLookup then
		targetList._friendlyLookup = {}
		for i = 1, #targetList.Friendlies do
			targetList._friendlyLookup[targetList.Friendlies[i]] = true
		end
	end

	if not targetList._enemyLookup then
		targetList._enemyLookup = {}
		for i = 1, #targetList.Enemies do
			targetList._enemyLookup[targetList.Enemies[i]] = true
		end
	end

	if targetList._friendlyLookup[playerName] then
		return "friendly"
	end

	if targetList._enemyLookup[playerName] then
		return "enemy"
	end

	return "other"
end

function ESPLibrary:GetPlayerColor(player)
	if not self.Settings.TargetList.UseDifferentColors then
		return nil
	end

	local playerType = self:GetPlayerType(player)

	if playerType == "friendly" then
		return self.Settings.TargetList.FriendlyColor
	elseif playerType == "enemy" then
		return self.Settings.TargetList.EnemyColor
	end

	return nil
end

function ESPLibrary:GetPlayerGradientColors(playerColor)
	if not playerColor then
		return nil
	end

	return {
		Color3_fromRGB(0, 0, 0),
		playerColor,
		Color3_fromRGB(0, 0, 0),
	}
end

local TeamColorCache = {}
function ESPLibrary:GetTeamColor(player)
	if not self.Settings.TeamBasedColor.Enabled then
		return nil
	end

	local cacheKey = player.UserId
	local cached = TeamColorCache[cacheKey]

	if cached and tick() - cached.Time < 1 then
		return cached.Color
	end

	local color
	if self.Settings.TeamBasedColor.UseTeamColor then
		local team = self:GetTeamOverride(player)
		if team and team.TeamColor then
			color = team.TeamColor.Color
		else
			color = Color3_fromRGB(255, 255, 255)
		end
	else
		if self:IsTeamMateOverride(player) then
			color = self.Settings.TeamBasedColor.AllyColor
		else
			color = self.Settings.TeamBasedColor.EnemyColor
		end
	end

	TeamColorCache[cacheKey] = { Color = color, Time = tick() }
	return color
end

local TeamGradientCache = {}
function ESPLibrary:GetTeamGradientColors(teamColor)
	if not self.Settings.TeamBasedColor.GradientStyle or not teamColor then
		return nil
	end

	local key = tostring(teamColor)
	if TeamGradientCache[key] then
		return TeamGradientCache[key]
	end

	local gradient = { Color3_fromRGB(0, 0, 0), teamColor, Color3_fromRGB(0, 0, 0) }
	TeamGradientCache[key] = gradient
	return gradient
end

function ESPLibrary:WorldToViewportPoint(pos)
	local screenPos, onScreen = CurrentCamera:WorldToViewportPoint(pos)
	return Vector2_new(screenPos.X, screenPos.Y), onScreen, screenPos.Z
end

function ESPLibrary:GetCharacterSize(character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end

	local hrpCF = hrp.CFrame
	local hrpPos = hrp.Position

	local minX, minY, minZ = math_huge, math_huge, math_huge
	local maxX, maxY, maxZ = -math_huge, -math_huge, -math_huge

	local parts = table.create(20)
	local partCount = 0

	for i = 1, #IMPORTANT_PART_NAMES do
		local part = character:FindFirstChild(IMPORTANT_PART_NAMES[i])
		if part and part:IsA("BasePart") then
			partCount = partCount + 1
			parts[partCount] = part
		end
	end

	partCount = partCount + 1
	parts[partCount] = hrp

	local children = character:GetChildren()
	local accessoryCount = 0
	for i = 1, #children do
		if accessoryCount >= 5 then
			break
		end

		local child = children[i]
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local dx = handle.Position.X - hrpPos.X
				local dy = handle.Position.Y - hrpPos.Y
				local dz = handle.Position.Z - hrpPos.Z

				if dx * dx + dy * dy + dz * dz <= 16 then
					partCount = partCount + 1
					parts[partCount] = handle
					accessoryCount = accessoryCount + 1
				end
			end
		end
	end

	for i = 1, partCount do
		local part = parts[i]
		local cf = part.CFrame
		local size = part.Size
		local sx, sy, sz = size.X * 0.5, size.Y * 0.5, size.Z * 0.5

		local c1 = hrpCF:PointToObjectSpace((cf * CFrame_new(-sx, sy, 0)).Position)
		local c2 = hrpCF:PointToObjectSpace((cf * CFrame_new(sx, sy, 0)).Position)
		local c3 = hrpCF:PointToObjectSpace((cf * CFrame_new(sx, -sy, 0)).Position)
		local c4 = hrpCF:PointToObjectSpace((cf * CFrame_new(-sx, -sy, 0)).Position)

		minX = math_min(minX, c1.X, c2.X, c3.X, c4.X)
		minY = math_min(minY, c1.Y, c2.Y, c3.Y, c4.Y)
		minZ = math_min(minZ, c1.Z, c2.Z, c3.Z, c4.Z)
		maxX = math_max(maxX, c1.X, c2.X, c3.X, c4.X)
		maxY = math_max(maxY, c1.Y, c2.Y, c3.Y, c4.Y)
		maxZ = math_max(maxZ, c1.Z, c2.Z, c3.Z, c4.Z)
	end

	return Vector3_new((maxX - minX) * 1.05, (maxY - minY) * 1.08, (maxZ - minZ) * 1.05)
end

function ESPLibrary:GetBoundingBox(hrp, size)
	if not hrp or not size then
		return nil
	end

	local cf = hrp.CFrame
	local sx, sy = size.X * 0.5, size.Y * 0.5

	local c1 = cf * CFrame_new(-sx, sy, 0)
	local c2 = cf * CFrame_new(sx, sy, 0)
	local c3 = cf * CFrame_new(sx, -sy, 0)
	local c4 = cf * CFrame_new(-sx, -sy, 0)

	local s1, vis1 = self:WorldToViewportPoint(c1.Position)
	local s2, vis2 = self:WorldToViewportPoint(c2.Position)
	local s3, vis3 = self:WorldToViewportPoint(c3.Position)
	local s4, vis4 = self:WorldToViewportPoint(c4.Position)

	if not (vis1 and vis2 and vis3 and vis4) then
		return nil
	end

	local minX = math_min(s1.X, s2.X, s3.X, s4.X)
	local minY = math_min(s1.Y, s2.Y, s3.Y, s4.Y)
	local maxX = math_max(s1.X, s2.X, s3.X, s4.X)
	local maxY = math_max(s1.Y, s2.Y, s3.Y, s4.Y)

	return {
		Position = Vector2_new(minX, minY),
		Size = Vector2_new(maxX - minX, maxY - minY),
	}
end

function ESPLibrary:CheckBodyPartSizeChanges(character, esp)
	local sizeChanged = false

	for i = 1, #IMPORTANT_PART_NAMES do
		local part = character:FindFirstChild(IMPORTANT_PART_NAMES[i])
		if part and part:IsA("BasePart") then
			local currentSize = part.Size
			local cachedSize = esp.BodyPartSizes[part]

			if not cachedSize or math_abs(cachedSize.X - currentSize.X) > 0.01 or math_abs(cachedSize.Y - currentSize.Y) > 0.01 or math_abs(cachedSize.Z - currentSize.Z) > 0.01 then
				esp.BodyPartSizes[part] = currentSize
				sizeChanged = true
			end
		end
	end

	local children = character:GetChildren()
	for i = 1, #children do
		local child = children[i]
		if child:IsA("Accessory") then
			local handle = child:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				local currentSize = handle.Size
				local cachedSize = esp.BodyPartSizes[handle]

				if not cachedSize or math_abs(cachedSize.X - currentSize.X) > 0.01 or math_abs(cachedSize.Y - currentSize.Y) > 0.01 or math_abs(cachedSize.Z - currentSize.Z) > 0.01 then
					esp.BodyPartSizes[handle] = currentSize
					sizeChanged = true
				end
			end
		end
	end

	return sizeChanged
end

function ESPLibrary:GetEquippedTool(character)
	if not character then
		return nil
	end

	local cacheKey = tostring(character)
	local cached = self.ToolCache[cacheKey]

	if cached and tick() - cached.Time < 0.5 then
		return cached.Tool
	end

	local toolName = nil
	local children = character:GetChildren()
	for i = 1, #children do
		if children[i]:IsA("Tool") then
			toolName = children[i].Name
			break
		end
	end

	self.ToolCache[cacheKey] = { Tool = toolName, Time = tick() }
	return toolName
end

function ESPLibrary:GetBackpackTools(player)
	if not player then
		return {}
	end

	local cacheKey = player.UserId
	local cached = self.BackpackCache[cacheKey]

	if cached and tick() - cached.Time < 0.5 then
		return cached.Tools
	end

	local backpack = player:FindFirstChild("Backpack")
	if not backpack then
		return {}
	end

	local tools = {}
	local children = backpack:GetChildren()
	for i = 1, #children do
		if children[i]:IsA("Tool") then
			tools[#tools + 1] = children[i].Name
		end
	end

	self.BackpackCache[cacheKey] = { Tools = tools, Time = tick() }
	return tools
end

function ESPLibrary:GetHealthBarColor(healthPercent)
	if not self.Settings.HealthBar.GradientEnabled then
		return self.Settings.HealthBar.GradientColors[1]
	end

	local colors = self.Settings.HealthBar.GradientColors
	if healthPercent >= self.HEALTH_GRADIENT_MIDPOINT then
		local t = (healthPercent - self.HEALTH_GRADIENT_MIDPOINT) * self.HEALTH_GRADIENT_SCALE
		return colors[2]:Lerp(colors[3], t)
	else
		local t = healthPercent * self.HEALTH_GRADIENT_SCALE
		return colors[1]:Lerp(colors[2], t)
	end
end

function ESPLibrary:CreateESP(player)
	local esp = {
		Player = player,
		Drawings = {},
		HealthAnimData = {
			CurrentHealth = 100,
			TargetHealth = 100,
			StartHealth = 100,
			AnimationStart = 0,
			IsAnimating = false,
		},
		HealthValueData = {
			LastHealth = 100,
			LastChangeTime = 0,
			DamageAmount = 0,
		},
		FadeData = { IsFading = false, FadeAlpha = 1 },
		BackpackTexts = {},
		CachedSize = nil,
		SizeUpdateNeeded = true,
		LastToolText = "",
		StatTexts = {},
		StatBars = {},
		StatBarBackgrounds = {},
		Chams = {
			Highlight = nil,
			CurrentColor = Color3_fromRGB(0, 255, 0),
			TargetColor = Color3_fromRGB(0, 255, 0),
			IsOccluded = false,
			OcclusionConfidence = 0,
			LastCheckTime = 0,
			CheckInterval = 0.1,
		},
	}

	esp.Drawings.BoxOuterStroke = Drawing.new("Square")
	esp.Drawings.BoxOutline = Drawing.new("Square")
	esp.Drawings.BoxInnerStroke = Drawing.new("Square")
	esp.Drawings.BoxFill = Drawing.new("Square")
	esp.Drawings.HealthBarBg = Drawing.new("Square")
	esp.Drawings.HealthBar = Drawing.new("Square")
	esp.Drawings.HealthValue = Drawing.new("Text")
	esp.Drawings.Name = Drawing.new("Text")
	esp.Drawings.Distance = Drawing.new("Text")
	esp.Drawings.Tool = Drawing.new("Text")

	esp.StatTexts = {}
	esp.StatBars = {}
	esp.StatBarBackgrounds = {}
	esp.BodyPartSizes = {}
	esp.SizeChangeDetected = false

	local outerStroke = esp.Drawings.BoxOuterStroke
	outerStroke.Filled = false
	outerStroke.Thickness = 1
	outerStroke.Transparency = 1
	outerStroke.Color = Color3_fromRGB(0, 0, 0)
	outerStroke.ZIndex = 1
	outerStroke.Visible = false

	local outline = esp.Drawings.BoxOutline
	outline.Filled = false
	outline.Thickness = self.Settings.Box.Thickness
	outline.Transparency = self.Settings.Box.Transparency
	outline.Color = self.Settings.Box.Color
	outline.ZIndex = 2
	outline.Visible = false
	outline.StrokeGradientEnabled = self.Settings.Box.GradientEnabled
	outline.StrokeGradientColors = self.Settings.Box.GradientColors
	outline.StrokeGradientRotation = self.Settings.Box.GradientRotation

	local innerStroke = esp.Drawings.BoxInnerStroke
	innerStroke.Filled = false
	innerStroke.Thickness = 1
	innerStroke.Transparency = 1
	innerStroke.Color = Color3_fromRGB(0, 0, 0)
	innerStroke.ZIndex = 3
	innerStroke.Visible = false

	local fill = esp.Drawings.BoxFill
	fill.Filled = true
	fill.Transparency = self.Settings.BoxFill.Transparency
	fill.GradientEnabled = self.Settings.BoxFill.GradientEnabled
	fill.GradientColors = self.Settings.BoxFill.GradientColors
	fill.GradientRotation = self.Settings.BoxFill.GradientRotation
	fill.Color = self.Settings.BoxFill.Color
	fill.ZIndex = 1
	fill.Visible = false

	local hpBg = esp.Drawings.HealthBarBg
	hpBg.Filled = true
	hpBg.Transparency = self.Settings.HealthBar.BackgroundTransparency
	hpBg.Color = self.Settings.HealthBar.BackgroundColor
	hpBg.ZIndex = 1
	hpBg.Visible = false

	local hp = esp.Drawings.HealthBar
	hp.Filled = true
	hp.Transparency = 1
	hp.GradientEnabled = self.Settings.HealthBar.GradientEnabled
	hp.GradientColors = self.Settings.HealthBar.GradientColors
	hp.GradientRotation = self.Settings.HealthBar.GradientRotation
	hp.ZIndex = 2
	hp.Visible = false

	local hpVal = esp.Drawings.HealthValue
	hpVal.Size = self.Settings.HealthValue.Size
	hpVal.Font = self.Settings.HealthValue.Font
	hpVal.Outline = self.Settings.HealthValue.Outline
	hpVal.OutlineColor = self.Settings.HealthValue.OutlineColor
	hpVal.Center = true
	hpVal.ZIndex = 3
	hpVal.Visible = false

	local name = esp.Drawings.Name
	name.Text = player.Name
	name.Size = self.Settings.Name.Size
	name.Font = self.Settings.Name.Font
	name.Color = self.Settings.Name.Color
	name.Outline = self.Settings.Name.Outline
	name.OutlineColor = self.Settings.Name.OutlineColor
	name.Center = true
	name.ZIndex = 3
	name.Visible = false

	local dist = esp.Drawings.Distance
	dist.Size = self.Settings.Distance.Size
	dist.Font = self.Settings.Distance.Font
	dist.Color = self.Settings.Distance.Color
	dist.Outline = self.Settings.Distance.Outline
	dist.OutlineColor = self.Settings.Distance.OutlineColor
	dist.Center = true
	dist.ZIndex = 3
	dist.Visible = false

	local tool = esp.Drawings.Tool
	tool.Size = self.Settings.Tool.Size
	tool.Font = self.Settings.Tool.Font
	tool.Color = self.Settings.Tool.Color
	tool.Outline = self.Settings.Tool.Outline
	tool.OutlineColor = self.Settings.Tool.OutlineColor
	tool.Center = true
	tool.ZIndex = 3
	tool.Visible = false

	self.ESPObjects[player] = esp
	return esp
end

function ESPLibrary:RemoveESP(player)
	local esp = self.ESPObjects[player]
	if esp then
		if isDrawingValid(esp.Drawings.BoxOuterStroke) then
			esp.Drawings.BoxOuterStroke:Remove()
		end
		if isDrawingValid(esp.Drawings.BoxOutline) then
			esp.Drawings.BoxOutline:Remove()
		end
		if isDrawingValid(esp.Drawings.BoxInnerStroke) then
			esp.Drawings.BoxInnerStroke:Remove()
		end

		esp.Drawings.BoxFill:Remove()
		esp.Drawings.HealthBarBg:Remove()
		esp.Drawings.HealthBar:Remove()
		esp.Drawings.HealthValue:Remove()
		esp.Drawings.Name:Remove()
		esp.Drawings.Distance:Remove()
		esp.Drawings.Tool:Remove()

		for _, text in ipairs(esp.BackpackTexts) do
			if isDrawingValid(text) then
				text:Remove()
			end
		end

		for _, statText in ipairs(esp.StatTexts) do
			if isDrawingValid(statText) then
				statText:Remove()
			end
		end
		for _, statBarBg in ipairs(esp.StatBarBackgrounds) do
			if isDrawingValid(statBarBg) then
				statBarBg:Remove()
			end
		end
		for _, statBar in ipairs(esp.StatBars) do
			if isDrawingValid(statBar) then
				statBar:Remove()
			end
		end

		self.ESPObjects[player] = nil
	end
end

function ESPLibrary:HideESP(esp)
	if isDrawingValid(esp.Drawings.BoxOuterStroke) then
		esp.Drawings.BoxOuterStroke.Visible = false
	end
	if isDrawingValid(esp.Drawings.BoxOutline) then
		esp.Drawings.BoxOutline.Visible = false
	end
	if isDrawingValid(esp.Drawings.BoxInnerStroke) then
		esp.Drawings.BoxInnerStroke.Visible = false
	end

	esp.Drawings.BoxFill.Visible = false
	esp.Drawings.HealthBarBg.Visible = false
	esp.Drawings.HealthBar.Visible = false
	esp.Drawings.HealthValue.Visible = false
	esp.Drawings.Name.Visible = false
	esp.Drawings.Distance.Visible = false
	esp.Drawings.Tool.Visible = false

	for _, statText in ipairs(esp.StatTexts) do
		if isDrawingValid(statText) then
			statText.Visible = false
		end
	end
	for _, statBarBg in ipairs(esp.StatBarBackgrounds) do
		if isDrawingValid(statBarBg) then
			statBarBg.Visible = false
		end
	end
	for _, statBar in ipairs(esp.StatBars) do
		if isDrawingValid(statBar) then
			statBar.Visible = false
		end
	end
	if esp.Chams and esp.Chams.Highlight then
		esp.Chams.Highlight.Enabled = false
	end
end

function ESPLibrary:UpdateChams(esp, character)
	if not self.Settings.Chams.Enabled then
		if esp.Chams.Highlight then
			pcall(function()
				esp.Chams.Highlight:Destroy()
			end)
			esp.Chams.Highlight = nil
		end
		return
	end

	if not character or not character.Parent then
		if esp.Chams.Highlight then
			esp.Chams.Highlight.Enabled = false
		end
		return
	end

	local player = esp.Player
	local hrp = character:FindFirstChild("HumanoidRootPart")

	if not hrp then
		if esp.Chams.Highlight then
			esp.Chams.Highlight.Enabled = false
		end
		return
	end

	if not esp.Chams.Highlight or not esp.Chams.Highlight.Parent then
		if esp.Chams.Highlight then
			pcall(function()
				esp.Chams.Highlight:Destroy()
			end)
		end
		esp.Chams.Highlight = createHighlight(character)
		esp.Chams.Highlight.Name = "ESP_Chams"
	end

	local visibleColor = self.Settings.Chams.VisibleColor
	local occludedColor = self.Settings.Chams.OccludedColor

	if self.Settings.Chams.UseVisibilityCheck then
		local currentTime = tick()
		if currentTime - esp.Chams.LastCheckTime >= esp.Chams.CheckInterval then
			local isOccluded = isPlayerOccluded(character, CurrentCamera)

			if isOccluded then
				esp.Chams.OcclusionConfidence = math_min(esp.Chams.OcclusionConfidence + 0.35, 1)
			else
				esp.Chams.OcclusionConfidence = math_max(esp.Chams.OcclusionConfidence - 0.35, -1)
			end

			if esp.Chams.OcclusionConfidence > 0.6 then
				esp.Chams.IsOccluded = true
			elseif esp.Chams.OcclusionConfidence < -0.6 then
				esp.Chams.IsOccluded = false
			end

			esp.Chams.LastCheckTime = currentTime
		end
	else
		esp.Chams.IsOccluded = false
	end

	if self.Settings.Chams.UseTeamColors then
		local teamColor = self:GetTeamColor(player)
		if teamColor then
			visibleColor = teamColor
			occludedColor = Color3_new(math_clamp(teamColor.R * 0.5, 0, 1), math_clamp(teamColor.G * 0.5, 0, 1), math_clamp(teamColor.B * 0.5, 0, 1))
		end
	else
		local playerColor = self:GetPlayerColor(player)
		if playerColor then
			visibleColor = playerColor
			occludedColor = Color3_new(math_clamp(playerColor.R * 0.6, 0, 1), math_clamp(playerColor.G * 0.6, 0, 1), math_clamp(playerColor.B * 0.6, 0, 1))
		end
	end

	local overrideColor = self:GetColorOverride(character)
	if overrideColor then
		visibleColor = overrideColor
		occludedColor = Color3_new(math_clamp(overrideColor.R * 0.5, 0, 1), math_clamp(overrideColor.G * 0.5, 0, 1), math_clamp(overrideColor.B * 0.5, 0, 1))
	end

	esp.Chams.TargetColor = esp.Chams.IsOccluded and occludedColor or visibleColor

	if self.Settings.Chams.SmoothTransition then
		esp.Chams.CurrentColor = Color3_new(esp.Chams.CurrentColor.R + (esp.Chams.TargetColor.R - esp.Chams.CurrentColor.R) * self.Settings.Chams.TransitionSpeed, esp.Chams.CurrentColor.G + (esp.Chams.TargetColor.G - esp.Chams.CurrentColor.G) * self.Settings.Chams.TransitionSpeed, esp.Chams.CurrentColor.B + (esp.Chams.TargetColor.B - esp.Chams.CurrentColor.B) * self.Settings.Chams.TransitionSpeed)
	else
		esp.Chams.CurrentColor = esp.Chams.TargetColor
	end

	esp.Chams.Highlight.FillColor = esp.Chams.CurrentColor
	esp.Chams.Highlight.FillTransparency = self.Settings.Chams.FillTransparency
	esp.Chams.Highlight.OutlineColor = self.Settings.Chams.OutlineColor
	esp.Chams.Highlight.OutlineTransparency = self.Settings.Chams.OutlineEnabled and self.Settings.Chams.OutlineTransparency or 1
	esp.Chams.Highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	esp.Chams.Highlight.Enabled = true
end

function ESPLibrary:UpdateESP(esp)
	local player = esp.Player

	if not player or not player.Parent then
		self:HideESP(esp)
		return
	end

	if not self.Settings.Enabled then
		self:HideESP(esp)
		return
	end

	local character = player.Character
	if not character then
		self:HideESP(esp)
		return
	end

	if player == LocalPlayer and not self.Settings.ShowSelf then
		self:HideESP(esp)
		if esp.Chams and esp.Chams.Highlight then
			esp.Chams.Highlight.Enabled = false
		end
		return
	end

	local playerType = self:GetPlayerType(player)
	if playerType == "friendly" and not self.Settings.TargetList.ShowFriendlies then
		self:HideESP(esp)
		return
	end
	if playerType == "enemy" and not self.Settings.TargetList.ShowEnemies then
		self:HideESP(esp)
		return
	end
	if playerType == "other" and not self.Settings.TargetList.ShowOthers then
		self:HideESP(esp)
		return
	end

	local hrp = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if not hrp or not humanoid then
		self:HideESP(esp)
		return
	end

	local hrpPos = hrp.Position
	local camPos = CurrentCamera.CFrame.Position

	local dx = hrpPos.X - camPos.X
	local dy = hrpPos.Y - camPos.Y
	local dz = hrpPos.Z - camPos.Z
	local distSquared = dx * dx + dy * dy + dz * dz

	if distSquared > self.MAX_DISTANCE_SQUARED then
		self:HideESP(esp)
		return
	end

	self:UpdateChams(esp, character)

	local currentTime = tick()
	if esp.SizeUpdateNeeded or (currentTime - (esp.LastSizeCheck or 0) > 2) then
		if esp.SizeUpdateNeeded or self:CheckBodyPartSizeChanges(character, esp) then
			esp.CachedSize = self:GetCharacterSize(character)
			esp.SizeUpdateNeeded = false
		end
		esp.LastSizeCheck = currentTime
	end

	local distance
	if self.Settings.Distance.Enabled then
		if self.Settings.DistanceCheck == "Character" then
			local localChar = LocalPlayer.Character
			if localChar and localChar:FindFirstChild("HumanoidRootPart") then
				local localPos = localChar.HumanoidRootPart.Position
				local ldx = hrpPos.X - localPos.X
				local ldy = hrpPos.Y - localPos.Y
				local ldz = hrpPos.Z - localPos.Z
				distance = math_sqrt(ldx * ldx + ldy * ldy + ldz * ldz)
			else
				distance = math_sqrt(distSquared)
			end
		else
			distance = math_sqrt(distSquared)
		end
	end

	local isDead = humanoid.Health <= 0
	if isDead and self.Settings.FadeOnDeath.Enabled then
		if not esp.FadeData.IsFading then
			esp.FadeData.IsFading = true
			esp.FadeData.FadeStart = tick()
		end

		local elapsed = tick() - esp.FadeData.FadeStart
		esp.FadeData.FadeAlpha = math_max(0, 1 - (elapsed / self.Settings.FadeOnDeath.FadeTime))

		if esp.FadeData.FadeAlpha <= 0 then
			self:HideESP(esp)
			return
		end
	else
		esp.FadeData.IsFading = false
		esp.FadeData.FadeAlpha = 1
	end

	local healthPercent = humanoid.Health / humanoid.MaxHealth
	local currentTime2 = tick()

	if self.Settings.HealthBar.AnimationEnabled then
		if esp.HealthAnimData.TargetHealth ~= healthPercent then
			esp.HealthAnimData.StartHealth = esp.HealthAnimData.CurrentHealth
			esp.HealthAnimData.TargetHealth = healthPercent
			esp.HealthAnimData.AnimationStart = currentTime2
			esp.HealthAnimData.IsAnimating = true

			if self.Settings.HealthValue.ShowOnlyOnChange then
				local healthDiff = (healthPercent - esp.HealthValueData.LastHealth) * humanoid.MaxHealth
				esp.HealthValueData.DamageAmount = math_floor(math_abs(healthDiff))
				esp.HealthValueData.LastHealth = healthPercent
				esp.HealthValueData.LastChangeTime = currentTime2
			end
		end

		if esp.HealthAnimData.IsAnimating then
			local elapsed = currentTime2 - esp.HealthAnimData.AnimationStart
			local progress = math_min(elapsed / self.Settings.HealthBar.AnimationDuration, 1)

			local tweenFunc = GetTweenFunction(self.Settings.HealthBar.AnimationStyle, self.Settings.HealthBar.AnimationDirection)
			local easedProgress = tweenFunc(progress)

			local healthDiff = esp.HealthAnimData.TargetHealth - esp.HealthAnimData.StartHealth
			esp.HealthAnimData.CurrentHealth = esp.HealthAnimData.StartHealth + (healthDiff * easedProgress)

			if progress >= 1 then
				esp.HealthAnimData.IsAnimating = false
				esp.HealthAnimData.CurrentHealth = esp.HealthAnimData.TargetHealth
			end
		end
	else
		esp.HealthAnimData.CurrentHealth = healthPercent
		esp.HealthAnimData.TargetHealth = healthPercent
	end

	local baseFadeAlpha = esp.FadeData.FadeAlpha
	local healthBarPulse = 1

	if self.Settings.HealthAnimations.PulseOnLowHealth and healthPercent < self.Settings.HealthAnimations.LowHealthThreshold then
		local pulse = math_abs(math_sin(tick() * self.Settings.HealthAnimations.PulseSpeed))
		healthBarPulse = 0.5 + pulse * 0.5
		esp.FadeData.FadeAlpha = baseFadeAlpha * healthBarPulse
	else
		esp.FadeData.FadeAlpha = baseFadeAlpha
	end

	local colorCache = esp.ColorCache
	local currentTime3 = tick()
	local cacheValid = colorCache and (currentTime3 - (colorCache.lastUpdate or 0)) <= COLOR_CACHE_DURATION

	if not cacheValid then
		local playerColor = nil
		local playerGradient = nil
		local teamColor = nil
		local teamGradient = nil
		local overrideColor = self:GetColorOverride(character)

		if overrideColor then
			playerColor = overrideColor
			teamColor = overrideColor
		else
			if self.Settings.TargetList.UseDifferentColors then
				local targetListColor = self:GetPlayerColor(player)
				if targetListColor then
					playerColor = targetListColor
					playerGradient = self:GetPlayerGradientColors(targetListColor)
					teamColor = targetListColor
					teamGradient = playerGradient
				end
			end

			if not playerColor and self.Settings.TeamBasedColor.Enabled then
				local cacheKey = player.UserId
				local teamCache = TEAM_COLOR_CACHE[cacheKey]

				if teamCache and (currentTime3 - teamCache.time) < COLOR_CACHE_DURATION then
					teamColor = teamCache.color
					teamGradient = teamCache.gradient
				else
					local tempTeamColor = self:GetTeamColor(player)
					if tempTeamColor then
						teamColor = tempTeamColor
						teamGradient = self:GetTeamGradientColors(teamColor)

						TEAM_COLOR_CACHE[cacheKey] = {
							color = teamColor,
							gradient = teamGradient,
							time = currentTime3,
						}
					end
				end

				playerColor = teamColor
				playerGradient = teamGradient
			end
		end

		esp.ColorCache = {
			playerColor = playerColor,
			playerGradient = playerGradient,
			teamColor = teamColor,
			teamGradient = teamGradient,
			lastUpdate = currentTime3,
		}
		colorCache = esp.ColorCache
	end

	local playerColor = colorCache.playerColor
	local playerGradient = colorCache.playerGradient
	local teamColor = colorCache.teamColor
	local teamGradient = colorCache.teamGradient

	local currentTime4 = tick() - self.StartTime
	local boxRotation = self.Settings.Box.RotationEnabled and (currentTime4 * self.Settings.Box.RotationSpeed) % 360 or self.Settings.Box.GradientRotation
	local boxFillRotation = self.Settings.BoxFill.RotationEnabled and (currentTime4 * self.Settings.BoxFill.RotationSpeed) % 360 or self.Settings.BoxFill.GradientRotation

	local box = self:GetBoundingBox(hrp, esp.CachedSize)
	if not box then
		self:HideESP(esp)
		return
	end

	if not self:UpdateAllowOverride(box) then
		self:HideESP(esp)
		return
	end

	local pos = box.Position
	local size = box.Size

	if self.Settings.Box.Enabled then
		local thickness = self.Settings.Box.Thickness
		local boxSettings = self.Settings.Box

		if not esp._drawingCache then
			esp._drawingCache = {}
		end
		local cache = esp._drawingCache

		local outerStroke = esp.Drawings.BoxOuterStroke
		local outerPos = Vector2_new(pos.X - 1, pos.Y - 1)
		local outerSize = Vector2_new(size.X + 2, size.Y + 2)

		updateDrawingPosition(outerStroke, outerPos, cache, "outerPos")
		updateDrawingSize(outerStroke, outerSize, cache, "outerSize")
		updateDrawingIfChanged(outerStroke, "Transparency", 1 * esp.FadeData.FadeAlpha)
		updateDrawingIfChanged(outerStroke, "Visible", true)

		local outline = esp.Drawings.BoxOutline
		local alpha = boxSettings.Transparency * esp.FadeData.FadeAlpha

		updateDrawingPosition(outline, pos, cache, "boxPos")
		updateDrawingSize(outline, size, cache, "boxSize")
		updateDrawingIfChanged(outline, "Transparency", alpha)
		updateDrawingIfChanged(outline, "Thickness", thickness)
		updateDrawingIfChanged(outline, "StrokeGradientRotation", boxRotation)

		if teamGradient and #teamGradient > 0 then
			if not cache.lastTeamGradient or cache.lastTeamGradient ~= teamGradient then
				local gradColor = createGradient(teamGradient)
				if gradColor then
					outline.StrokeGradientEnabled = true
					outline.StrokeGradientColors = teamGradient
					outline.Color = Color3_new(1, 1, 1)
					cache.lastTeamGradient = teamGradient
				end
			end
		elseif teamColor then
			if not cache.lastTeamColor or cache.lastTeamColor ~= teamColor then
				outline.StrokeGradientEnabled = false
				outline.Color = teamColor
				cache.lastTeamColor = teamColor
			end
		elseif playerGradient and #playerGradient > 0 then
			if not cache.lastPlayerGradient or cache.lastPlayerGradient ~= playerGradient then
				local gradColor = createGradient(playerGradient)
				if gradColor then
					outline.StrokeGradientEnabled = true
					outline.StrokeGradientColors = playerGradient
					outline.Color = Color3_new(1, 1, 1)
					cache.lastPlayerGradient = playerGradient
				end
			end
		elseif playerColor then
			if not cache.lastPlayerColor or cache.lastPlayerColor ~= playerColor then
				outline.StrokeGradientEnabled = false
				outline.Color = playerColor
				cache.lastPlayerColor = playerColor
			end
		else
			if not cache.lastBoxMode or cache.lastBoxMode ~= "default" then
				outline.StrokeGradientEnabled = boxSettings.GradientEnabled
				if boxSettings.GradientEnabled then
					if boxSettings.GradientColors and #boxSettings.GradientColors > 0 then
						local gradColor = createGradient(boxSettings.GradientColors)
						if gradColor then
							outline.StrokeGradientColors = boxSettings.GradientColors
							outline.Color = Color3_new(1, 1, 1)
						end
					end
				else
					outline.Color = boxSettings.Color
				end
				cache.lastBoxMode = "default"
			end
		end

		updateDrawingIfChanged(outline, "Visible", true)

		local innerStroke = esp.Drawings.BoxInnerStroke
		local innerPos = Vector2_new(pos.X + 1, pos.Y + 1)
		local innerSize = Vector2_new(size.X - 2, size.Y - 2)

		updateDrawingPosition(innerStroke, innerPos, cache, "innerPos")
		updateDrawingSize(innerStroke, innerSize, cache, "innerSize")
		updateDrawingIfChanged(innerStroke, "Transparency", 1 * esp.FadeData.FadeAlpha)
		updateDrawingIfChanged(innerStroke, "Visible", true)
	else
		esp.Drawings.BoxOuterStroke.Visible = false
		esp.Drawings.BoxOutline.Visible = false
		esp.Drawings.BoxInnerStroke.Visible = false
	end

	if self.Settings.BoxFill.Enabled then
		local fill = esp.Drawings.BoxFill
		fill.Position = pos
		fill.Size = size
		fill.Transparency = self.Settings.BoxFill.Transparency * esp.FadeData.FadeAlpha
		fill.GradientRotation = boxFillRotation

		if teamGradient and #teamGradient > 0 then
			local gradColor = createGradient(teamGradient)
			if gradColor then
				fill.GradientEnabled = true
				fill.GradientColors = teamGradient
				fill.Color = Color3_new(1, 1, 1)
			else
				fill.GradientEnabled = false
				fill.Color = teamColor or self.Settings.BoxFill.Color
			end
		elseif teamColor then
			fill.GradientEnabled = false
			fill.Color = teamColor
		elseif playerGradient and #playerGradient > 0 then
			local gradColor = createGradient(playerGradient)
			if gradColor then
				fill.GradientEnabled = true
				fill.GradientColors = playerGradient
				fill.Color = Color3_new(1, 1, 1)
			else
				fill.GradientEnabled = false
				fill.Color = playerColor or self.Settings.BoxFill.Color
			end
		elseif playerColor then
			fill.GradientEnabled = false
			fill.Color = playerColor
		else
			fill.GradientEnabled = self.Settings.BoxFill.GradientEnabled
			if self.Settings.BoxFill.GradientEnabled then
				if self.Settings.BoxFill.GradientColors and #self.Settings.BoxFill.GradientColors > 0 then
					local gradColor = createGradient(self.Settings.BoxFill.GradientColors)
					if gradColor then
						fill.GradientColors = self.Settings.BoxFill.GradientColors
						fill.Color = Color3_new(1, 1, 1)
					else
						fill.GradientEnabled = false
						fill.Color = self.Settings.BoxFill.Color
					end
				else
					fill.GradientEnabled = false
					fill.Color = self.Settings.BoxFill.Color
				end
			else
				fill.Color = self.Settings.BoxFill.Color
			end
		end

		fill.Visible = true
	else
		esp.Drawings.BoxFill.Visible = false
	end

	if self.Settings.HealthBar.Enabled then
		local barPosition = self.Settings.HealthBar.Position or "Left"
		local barWidth = self.Settings.HealthBar.Width
		local offset = self.Settings.HealthBar.Offset

		if barPosition == "Left" then
			local barHeight = size.Y
			local hpBg = esp.Drawings.HealthBarBg
			hpBg.Position = Vector2_new(pos.X - offset - barWidth, pos.Y)
			hpBg.Size = Vector2_new(barWidth, barHeight)
			hpBg.Transparency = self.Settings.HealthBar.BackgroundTransparency * baseFadeAlpha
			hpBg.Visible = true

			local hp = esp.Drawings.HealthBar
			local currentHeight = barHeight * esp.HealthAnimData.CurrentHealth
			hp.Position = Vector2_new(pos.X - offset - barWidth, pos.Y + barHeight - currentHeight)
			hp.Size = Vector2_new(barWidth, currentHeight)
			hp.Transparency = 1 * baseFadeAlpha * healthBarPulse
			hp.Visible = true
		elseif barPosition == "Right" then
			local barHeight = size.Y
			local hpBg = esp.Drawings.HealthBarBg
			hpBg.Position = Vector2_new(pos.X + size.X + offset, pos.Y)
			hpBg.Size = Vector2_new(barWidth, barHeight)
			hpBg.Transparency = self.Settings.HealthBar.BackgroundTransparency * baseFadeAlpha
			hpBg.Visible = true

			local hp = esp.Drawings.HealthBar
			local currentHeight = barHeight * esp.HealthAnimData.CurrentHealth
			hp.Position = Vector2_new(pos.X + size.X + offset, pos.Y + barHeight - currentHeight)
			hp.Size = Vector2_new(barWidth, currentHeight)
			hp.Transparency = 1 * baseFadeAlpha * healthBarPulse
			hp.Visible = true
		elseif barPosition == "Top" then
			local barHeight = self.Settings.HealthBar.Width
			local barLength = size.X
			local hpBg = esp.Drawings.HealthBarBg
			hpBg.Position = Vector2_new(pos.X, pos.Y - offset - barHeight)
			hpBg.Size = Vector2_new(barLength, barHeight)
			hpBg.Transparency = self.Settings.HealthBar.BackgroundTransparency * baseFadeAlpha
			hpBg.Visible = true

			local hp = esp.Drawings.HealthBar
			local currentWidth = barLength * esp.HealthAnimData.CurrentHealth
			hp.Position = Vector2_new(pos.X, pos.Y - offset - barHeight)
			hp.Size = Vector2_new(currentWidth, barHeight)
			hp.Transparency = 1 * baseFadeAlpha * healthBarPulse
			hp.Visible = true
		elseif barPosition == "Bottom" then
			local barHeight = self.Settings.HealthBar.Width
			local barLength = size.X
			local hpBg = esp.Drawings.HealthBarBg
			hpBg.Position = Vector2_new(pos.X, pos.Y + size.Y + offset)
			hpBg.Size = Vector2_new(barLength, barHeight)
			hpBg.Transparency = self.Settings.HealthBar.BackgroundTransparency * baseFadeAlpha
			hpBg.Visible = true

			local hp = esp.Drawings.HealthBar
			local currentWidth = barLength * esp.HealthAnimData.CurrentHealth
			hp.Position = Vector2_new(pos.X, pos.Y + size.Y + offset)
			hp.Size = Vector2_new(currentWidth, barHeight)
			hp.Transparency = 1 * baseFadeAlpha * healthBarPulse
			hp.Visible = true
		end
	else
		esp.Drawings.HealthBarBg.Visible = false
		esp.Drawings.HealthBar.Visible = false
	end

	if self.Settings.HealthValue.Enabled then
		local hpVal = esp.Drawings.HealthValue
		local healthInt = math_floor(humanoid.Health)
		local shouldShow = true

		if self.Settings.HealthValue.ShowOnlyOnChange then
			local timeSinceChange = currentTime - esp.HealthValueData.LastChangeTime
			shouldShow = timeSinceChange < self.Settings.HealthValue.DisplayDuration
		end

		if shouldShow then
			hpVal.Text = tostring(healthInt)

			if self.Settings.HealthValue.UseHealthBarColor then
				hpVal.Color = self:GetHealthBarColor(esp.HealthAnimData.CurrentHealth)
			end

			local barPosition = self.Settings.HealthBar.Position or "Left"
			local valuePosition = self.Settings.HealthValue.ValuePosition or "Middle"
			local valueOffset = self.Settings.HealthValue.ValueOffset or 20
			local barWidth = self.Settings.HealthBar.Width
			local offset = self.Settings.HealthBar.Offset

			if barPosition == "Left" then
				local xPos = pos.X - offset - barWidth - valueOffset
				local yPos

				if valuePosition == "Top" then
					yPos = pos.Y + 10
				elseif valuePosition == "Bottom" then
					yPos = pos.Y + size.Y - 10
				else
					yPos = pos.Y + size.Y * 0.5
				end

				hpVal.Position = Vector2_new(xPos, yPos)
			elseif barPosition == "Right" then
				local xPos = pos.X + size.X + offset + barWidth + valueOffset
				local yPos

				if valuePosition == "Top" then
					yPos = pos.Y + 10
				elseif valuePosition == "Bottom" then
					yPos = pos.Y + size.Y - 10
				else
					yPos = pos.Y + size.Y * 0.5
				end

				hpVal.Position = Vector2_new(xPos, yPos)
			elseif barPosition == "Top" then
				local barHeight = self.Settings.HealthBar.Width
				local barLength = size.X
				local barY = pos.Y - offset - barHeight
				local yPos = barY - valueOffset
				local xPos

				if valuePosition == "Right" then
					xPos = pos.X + barLength
				else
					xPos = pos.X
				end

				hpVal.Position = Vector2_new(xPos, yPos)
			elseif barPosition == "Bottom" then
				local barHeight = self.Settings.HealthBar.Width
				local barLength = size.X
				local barY = pos.Y + size.Y + offset
				local yPos = barY + barHeight + valueOffset
				local xPos

				if valuePosition == "Right" then
					xPos = pos.X + barLength
				else
					xPos = pos.X
				end

				hpVal.Position = Vector2_new(xPos, yPos)
			end

			hpVal.Center = true
			hpVal.Transparency = 1 * baseFadeAlpha * healthBarPulse
			hpVal.Visible = true
		else
			hpVal.Visible = false
		end
	else
		esp.Drawings.HealthValue.Visible = false
	end

	if self.Settings.Name.Enabled then
		local name = esp.Drawings.Name
		name.Position = Vector2_new(pos.X + size.X * 0.5, pos.Y - 18)
		name.Transparency = 1 * baseFadeAlpha
		if teamColor then
			name.Color = teamColor
		elseif playerColor then
			name.Color = playerColor
		else
			name.Color = self.Settings.Name.Color
		end
		name.Visible = true
	else
		esp.Drawings.Name.Visible = false
	end

	if self.Settings.Distance.Enabled then
		local dist = esp.Drawings.Distance
		local distanceInt = math_floor(distance)
		if not esp.LastDistanceInt or esp.LastDistanceInt ~= distanceInt then
			dist.Text = string_format("%.0f studs", distanceInt)
			esp.LastDistanceInt = distanceInt
		end
		dist.Position = Vector2_new(pos.X + size.X * 0.5, pos.Y + size.Y + 2)
		dist.Transparency = 1 * baseFadeAlpha
		if teamColor then
			dist.Color = teamColor
		elseif playerColor then
			dist.Color = playerColor
		else
			dist.Color = self.Settings.Distance.Color
		end
		dist.Visible = true
	else
		esp.Drawings.Distance.Visible = false
	end

	if self.Settings.Tool.Enabled then
		local toolName = self:GetEquippedTool(character)
		local backpackTools = self:GetBackpackTools(player)
		local tool = esp.Drawings.Tool

		local toolText = ""
		local toolColor = self.Settings.Tool.Color

		if toolName then
			toolText = "C: " .. toolName
		elseif self.Settings.Tool.ShowNoTool then
			toolText = "C: No Tool"
		end

		if self.Settings.Tool.ShowBackpack and #backpackTools > 0 then
			local displayCount = math_min(#backpackTools, self.Settings.Tool.MaxBackpackDisplay)
			local backpackList = {}

			for i = 1, displayCount do
				backpackList[i] = backpackTools[i]
			end

			local backpackString = table_concat(backpackList, ", ")

			if toolText ~= "" then
				toolText = toolText .. "\nBP: " .. backpackString
			else
				toolText = "BP: " .. backpackString
			end

			if #backpackTools > self.Settings.Tool.MaxBackpackDisplay then
				toolText = toolText .. "..."
			end

			toolColor = self.Settings.Tool.BackpackColor
		end

		if toolText ~= esp.LastToolText then
			tool.Text = toolText
			esp.LastToolText = toolText
		end

		if toolText ~= "" then
			tool.Color = toolColor
			local yOffset = self.Settings.Distance.Enabled and (self.Settings.Distance.Size + 4) or 2
			tool.Position = Vector2_new(pos.X + size.X * 0.5, pos.Y + size.Y + yOffset)
			tool.Transparency = 1 * baseFadeAlpha
			tool.Visible = true
		else
			tool.Visible = false
		end
	else
		esp.Drawings.Tool.Visible = false
	end

	if self.Settings.Stats.Enabled and self.Settings.Stats.ShowPlayerStats and #self.Settings.Stats.PlayerStats > 0 then
		local statsToShow = self.Settings.Stats.PlayerStats
		local statBarPosition = self.Settings.Stats.StatBarPosition

		local sideBarStats = {}
		local bottomStats = {}

		for i, statDef in ipairs(statsToShow) do
			local useBar = statDef.UseStatBar ~= false
			local barPos = statDef.StatBarPosition or statBarPosition

			if useBar then
				sideBarStats[#sideBarStats + 1] = { index = i, def = statDef, position = barPos }
			else
				bottomStats[#bottomStats + 1] = { index = i, def = statDef }
			end
		end

		while #esp.StatTexts < #statsToShow do
			local statText = Drawing.new("Text")
			statText.Size = self.Settings.Stats.Size
			statText.Font = self.Settings.Stats.Font
			statText.Color = self.Settings.Stats.Color
			statText.Outline = self.Settings.Stats.Outline
			statText.OutlineColor = self.Settings.Stats.OutlineColor
			statText.Center = true
			statText.ZIndex = 3
			statText.Visible = false
			esp.StatTexts[#esp.StatTexts + 1] = statText

			local statBarBg = Drawing.new("Square")
			statBarBg.Filled = true
			statBarBg.Transparency = self.Settings.Stats.StatBarBackgroundTransparency
			statBarBg.Color = self.Settings.Stats.StatBarBackgroundColor
			statBarBg.ZIndex = 1
			statBarBg.Visible = false
			esp.StatBarBackgrounds[#esp.StatBarBackgrounds + 1] = statBarBg

			local statBar = Drawing.new("Square")
			statBar.Filled = true
			statBar.Transparency = 1
			statBar.ZIndex = 2
			statBar.Visible = false
			esp.StatBars[#esp.StatBars + 1] = statBar
		end

		local rightBarIndex = 0
		local leftBarIndex = 0
		local topBarIndex = 0
		local bottomBarIndex = 0

		for _, statData in ipairs(sideBarStats) do
			local i = statData.index
			local statDef = statData.def
			local barPos = statData.position
			local statText = esp.StatTexts[i]

			if statText and isDrawingValid(statText) then
				local statValue = self:GetPlayerStatValue(player, character, statDef)

				if statValue ~= nil then
					local numericValue = tonumber(statValue)
					local statPercent = 1

					if numericValue and statDef.MaxValue then
						statPercent = math_clamp(numericValue / statDef.MaxValue, 0, 1)
					end

					local barWidth = statDef.StatBarWidth or self.Settings.HealthBar.Width
					local barHeight = size.Y
					local offset = statDef.StatBarOffset or self.Settings.Stats.StatBarSideOffset or 3
					local spacing = self.Settings.Stats.StatBarVerticalSpacing or 8

					local valuePosition = statDef.StatValuePosition or self.Settings.Stats.StatValuePosition or "Middle"
					local valueOffset = statDef.StatValueOffset or self.Settings.Stats.StatValueOffset or 20

					if barPos == "Right" then
						local healthBarOffset = self.Settings.HealthBar.Offset
						local barX = pos.X + size.X + healthBarOffset + (barWidth + spacing) * rightBarIndex
						rightBarIndex = rightBarIndex + 1

						local statBarBg = esp.StatBarBackgrounds[i]
						if statBarBg and isDrawingValid(statBarBg) then
							statBarBg.Position = Vector2_new(barX, pos.Y)
							statBarBg.Size = Vector2_new(barWidth, barHeight)
							statBarBg.Transparency = (statDef.StatBarBackgroundTransparency or self.Settings.Stats.StatBarBackgroundTransparency) * baseFadeAlpha
							statBarBg.Color = statDef.StatBarBackgroundColor or self.Settings.Stats.StatBarBackgroundColor
							statBarBg.Visible = true
						end

						local statBar = esp.StatBars[i]
						if statBar and isDrawingValid(statBar) then
							local currentHeight = barHeight * statPercent
							statBar.Position = Vector2_new(barX, pos.Y + barHeight - currentHeight)
							statBar.Size = Vector2_new(barWidth, currentHeight)
							statBar.Transparency = 1 * baseFadeAlpha

							if statDef.StatBarGradientEnabled then
								statBar.GradientEnabled = true
								statBar.GradientColors = statDef.StatBarGradientColors or self.Settings.Stats.StatBarGradientColors
								statBar.GradientRotation = 270
							else
								statBar.GradientEnabled = false
								statBar.Color = statDef.Color or self.Settings.Stats.Color
							end
							statBar.Visible = true
						end

						if statDef.ShowValue ~= false then
							local displayText = ""
							if statDef.Format then
								if type(statDef.Format) == "function" then
									displayText = statDef.Format(statValue)
								elseif type(statDef.Format) == "string" then
									displayText = string_format(statDef.Format, statValue)
								else
									displayText = tostring(statValue)
								end
							else
								displayText = tostring(math_floor(numericValue or statValue))
							end

							statText.Text = displayText
							statText.Transparency = 1 * baseFadeAlpha
							statText.Color = statDef.Color or self.Settings.Stats.Color
							statText.Center = true

							local textX = barX + barWidth + valueOffset
							local textY

							if valuePosition == "Top" then
								textY = pos.Y + 10
							elseif valuePosition == "Bottom" then
								textY = pos.Y + barHeight - 10
							else
								textY = pos.Y + barHeight * 0.5
							end

							statText.Position = Vector2_new(textX, textY)
							statText.Visible = true
						else
							statText.Visible = false
						end
					elseif barPos == "Left" then
						local healthBarWidth = self.Settings.HealthBar.Width
						local healthBarOffset = self.Settings.HealthBar.Offset
						local barX = pos.X - healthBarOffset - healthBarWidth - offset - (barWidth + spacing) * (leftBarIndex + 1)
						leftBarIndex = leftBarIndex + 1

						local statBarBg = esp.StatBarBackgrounds[i]
						if statBarBg and isDrawingValid(statBarBg) then
							statBarBg.Position = Vector2_new(barX, pos.Y)
							statBarBg.Size = Vector2_new(barWidth, barHeight)
							statBarBg.Transparency = (statDef.StatBarBackgroundTransparency or self.Settings.Stats.StatBarBackgroundTransparency) * baseFadeAlpha
							statBarBg.Color = statDef.StatBarBackgroundColor or self.Settings.Stats.StatBarBackgroundColor
							statBarBg.Visible = true
						end

						local statBar = esp.StatBars[i]
						if statBar and isDrawingValid(statBar) then
							local currentHeight = barHeight * statPercent
							statBar.Position = Vector2_new(barX, pos.Y + barHeight - currentHeight)
							statBar.Size = Vector2_new(barWidth, currentHeight)
							statBar.Transparency = 1 * baseFadeAlpha

							if statDef.StatBarGradientEnabled then
								statBar.GradientEnabled = true
								statBar.GradientColors = statDef.StatBarGradientColors or self.Settings.Stats.StatBarGradientColors
								statBar.GradientRotation = 270
							else
								statBar.GradientEnabled = false
								statBar.Color = statDef.Color or self.Settings.Stats.Color
							end
							statBar.Visible = true
						end

						if statDef.ShowValue ~= false then
							local displayText = ""
							if statDef.Format then
								if type(statDef.Format) == "function" then
									displayText = statDef.Format(statValue)
								elseif type(statDef.Format) == "string" then
									displayText = string_format(statDef.Format, statValue)
								else
									displayText = tostring(statValue)
								end
							else
								displayText = tostring(math_floor(numericValue or statValue))
							end

							statText.Text = displayText
							statText.Transparency = 1 * baseFadeAlpha
							statText.Color = statDef.Color or self.Settings.Stats.Color
							statText.Center = true

							local textX = barX - valueOffset
							local textY

							if valuePosition == "Top" then
								textY = pos.Y + 10
							elseif valuePosition == "Bottom" then
								textY = pos.Y + barHeight - 10
							else
								textY = pos.Y + barHeight * 0.5
							end

							statText.Position = Vector2_new(textX, textY)
							statText.Visible = true
						else
							statText.Visible = false
						end
					elseif barPos == "Top" then
						local barY = pos.Y - offset - (barWidth + spacing) * (topBarIndex + 1)
						local barLength = size.X
						topBarIndex = topBarIndex + 1

						local statBarBg = esp.StatBarBackgrounds[i]
						if statBarBg and isDrawingValid(statBarBg) then
							statBarBg.Position = Vector2_new(pos.X, barY)
							statBarBg.Size = Vector2_new(barLength, barWidth)
							statBarBg.Transparency = (statDef.StatBarBackgroundTransparency or self.Settings.Stats.StatBarBackgroundTransparency) * baseFadeAlpha
							statBarBg.Color = statDef.StatBarBackgroundColor or self.Settings.Stats.StatBarBackgroundColor
							statBarBg.Visible = true
						end

						local statBar = esp.StatBars[i]
						if statBar and isDrawingValid(statBar) then
							local currentLength = barLength * statPercent
							statBar.Position = Vector2_new(pos.X, barY)
							statBar.Size = Vector2_new(currentLength, barWidth)
							statBar.Transparency = 1 * baseFadeAlpha

							if statDef.StatBarGradientEnabled then
								statBar.GradientEnabled = true
								statBar.GradientColors = statDef.StatBarGradientColors or self.Settings.Stats.StatBarGradientColors
								statBar.GradientRotation = 0
							else
								statBar.GradientEnabled = false
								statBar.Color = statDef.Color or self.Settings.Stats.Color
							end
							statBar.Visible = true
						end

						if statDef.ShowValue ~= false then
							local displayText = ""
							if statDef.Format then
								if type(statDef.Format) == "function" then
									displayText = statDef.Format(statValue)
								elseif type(statDef.Format) == "string" then
									displayText = string_format(statDef.Format, statValue)
								else
									displayText = tostring(statValue)
								end
							else
								displayText = tostring(math_floor(numericValue or statValue))
							end

							statText.Text = displayText
							statText.Transparency = 1 * baseFadeAlpha
							statText.Color = statDef.Color or self.Settings.Stats.Color
							statText.Center = true

							local textY = barY - valueOffset
							local textX

							if valuePosition == "Right" then
								textX = pos.X + barLength
							else
								textX = pos.X
							end

							statText.Position = Vector2_new(textX, textY)
							statText.Visible = true
						else
							statText.Visible = false
						end
					elseif barPos == "Bottom" then
						local distanceTextHeight = self.Settings.Distance.Enabled and (self.Settings.Distance.Size + 2) or 0
						local toolTextHeight = 0
						if self.Settings.Tool.Enabled and esp.LastToolText ~= "" then
							local toolLines = 1
							for _ in string_gmatch(esp.LastToolText, "\n") do
								toolLines = toolLines + 1
							end
							toolTextHeight = (self.Settings.Tool.Size * toolLines) + 4
						end

						local barY = pos.Y + size.Y + distanceTextHeight + toolTextHeight + offset + (barWidth + spacing) * bottomBarIndex
						local barLength = size.X
						bottomBarIndex = bottomBarIndex + 1

						local statBarBg = esp.StatBarBackgrounds[i]
						if statBarBg and isDrawingValid(statBarBg) then
							statBarBg.Position = Vector2_new(pos.X, barY)
							statBarBg.Size = Vector2_new(barLength, barWidth)
							statBarBg.Transparency = (statDef.StatBarBackgroundTransparency or self.Settings.Stats.StatBarBackgroundTransparency) * baseFadeAlpha
							statBarBg.Color = statDef.StatBarBackgroundColor or self.Settings.Stats.StatBarBackgroundColor
							statBarBg.Visible = true
						end

						local statBar = esp.StatBars[i]
						if statBar and isDrawingValid(statBar) then
							local currentLength = barLength * statPercent
							statBar.Position = Vector2_new(pos.X, barY)
							statBar.Size = Vector2_new(currentLength, barWidth)
							statBar.Transparency = 1 * baseFadeAlpha

							if statDef.StatBarGradientEnabled then
								statBar.GradientEnabled = true
								statBar.GradientColors = statDef.StatBarGradientColors or self.Settings.Stats.StatBarGradientColors
								statBar.GradientRotation = 0
							else
								statBar.GradientEnabled = false
								statBar.Color = statDef.Color or self.Settings.Stats.Color
							end
							statBar.Visible = true
						end

						if statDef.ShowValue ~= false then
							local displayText = ""
							if statDef.Format then
								if type(statDef.Format) == "function" then
									displayText = statDef.Format(statValue)
								elseif type(statDef.Format) == "string" then
									displayText = string_format(statDef.Format, statValue)
								else
									displayText = tostring(statValue)
								end
							else
								displayText = tostring(math_floor(numericValue or statValue))
							end

							statText.Text = displayText
							statText.Transparency = 1 * baseFadeAlpha
							statText.Color = statDef.Color or self.Settings.Stats.Color
							statText.Center = true

							local textY = barY + barWidth + valueOffset
							local textX

							if valuePosition == "Right" then
								textX = pos.X + barLength
							else
								textX = pos.X
							end

							statText.Position = Vector2_new(textX, textY)
							statText.Visible = true
						else
							statText.Visible = false
						end
					end
				else
					statText.Visible = false
					if esp.StatBarBackgrounds[i] and isDrawingValid(esp.StatBarBackgrounds[i]) then
						esp.StatBarBackgrounds[i].Visible = false
					end
					if esp.StatBars[i] and isDrawingValid(esp.StatBars[i]) then
						esp.StatBars[i].Visible = false
					end
				end
			end
		end

		if #bottomStats > 0 then
			local startY = pos.Y + size.Y
			if self.Settings.Distance.Enabled then
				startY = startY + self.Settings.Distance.Size + 2
			end
			if self.Settings.Tool.Enabled and esp.LastToolText ~= "" then
				local toolLines = 1
				for _ in string_gmatch(esp.LastToolText, "\n") do
					toolLines = toolLines + 1
				end
				startY = startY + (self.Settings.Tool.Size * toolLines) + 4
			end
			startY = startY + self.Settings.Stats.OffsetY

			for _, statData in ipairs(bottomStats) do
				local i = statData.index
				local statDef = statData.def
				local statText = esp.StatTexts[i]

				if statText and isDrawingValid(statText) then
					local statValue = self:GetPlayerStatValue(player, character, statDef)

					if statValue ~= nil then
						local displayText = statDef.Name and (statDef.Name .. ": ") or ""

						if statDef.Format then
							if type(statDef.Format) == "function" then
								displayText = displayText .. statDef.Format(statValue)
							elseif type(statDef.Format) == "string" then
								displayText = displayText .. string_format(statDef.Format, statValue)
							else
								displayText = displayText .. tostring(statValue)
							end
						else
							displayText = displayText .. tostring(statValue)
						end

						statText.Text = displayText
						statText.Position = Vector2_new(pos.X + size.X * 0.5, startY)
						statText.Transparency = 1 * baseFadeAlpha
						statText.Color = statDef.Color or self.Settings.Stats.Color
						statText.Center = true
						statText.Visible = true

						if esp.StatBarBackgrounds[i] and isDrawingValid(esp.StatBarBackgrounds[i]) then
							esp.StatBarBackgrounds[i].Visible = false
						end
						if esp.StatBars[i] and isDrawingValid(esp.StatBars[i]) then
							esp.StatBars[i].Visible = false
						end

						startY = startY + self.Settings.Stats.Spacing
					else
						statText.Visible = false
					end
				end
			end
		end

		for i = #statsToShow + 1, #esp.StatTexts do
			if esp.StatTexts[i] and isDrawingValid(esp.StatTexts[i]) then
				esp.StatTexts[i].Visible = false
			end
			if esp.StatBarBackgrounds[i] and isDrawingValid(esp.StatBarBackgrounds[i]) then
				esp.StatBarBackgrounds[i].Visible = false
			end
			if esp.StatBars[i] and isDrawingValid(esp.StatBars[i]) then
				esp.StatBars[i].Visible = false
			end
		end
	else
		for _, statText in ipairs(esp.StatTexts) do
			if isDrawingValid(statText) then
				statText.Visible = false
			end
		end
		for _, statBarBg in ipairs(esp.StatBarBackgrounds) do
			if isDrawingValid(statBarBg) then
				statBarBg.Visible = false
			end
		end
		for _, statBar in ipairs(esp.StatBars) do
			if isDrawingValid(statBar) then
				statBar.Visible = false
			end
		end
	end
end

function ESPLibrary:OnCharacterAdded(player)
	local esp = self.ESPObjects[player]
	if esp.Chams.Highlight then
		pcall(function()
			esp.Chams.Highlight:Destroy()
		end)
		esp.Chams.Highlight = nil
	end

	if esp then
		esp.FadeData.IsFading = false
		esp.FadeData.FadeAlpha = 1
		esp.HealthAnimData.CurrentHealth = 100
		esp.HealthAnimData.TargetHealth = 100
		esp.SizeUpdateNeeded = true
		esp.CachedSize = nil
	end
end

function ESPLibrary:OnHumanoidDied(player)
	local esp = self.ESPObjects[player]
	if esp then
		esp.SizeUpdateNeeded = true
	end
end

function ESPLibrary:SetupCharacterChangeDetection(player, character)
	local esp = self.ESPObjects[player]
	if not esp then
		return
	end

	esp.BodyPartSizes = {}

	local lastChangeTime = 0
	local function markSizeChange()
		local now = tick()
		if now - lastChangeTime > 0.3 then
			if esp then
				esp.SizeUpdateNeeded = true
				esp.CachedSize = nil
			end
			lastChangeTime = now
		end
	end

	local conn = cache(character.ChildAdded:Connect(function(child)
		if child:IsA("Accessory") then
			task.delay(0.15, markSizeChange)
		end
	end))

	self.Connections[#self.Connections + 1] = conn
end

function ESPLibrary:CheckCustomObjectSizeChanges(object, objectData, primaryPart)
	if not objectData.PartSizes then
		objectData.PartSizes = {}
	end

	local sizeChanged = false

	if primaryPart then
		local currentSize = primaryPart.Size
		local cachedSize = objectData.PartSizes[primaryPart]

		if not cachedSize or math_abs(cachedSize.X - currentSize.X) > 0.01 or math_abs(cachedSize.Y - currentSize.Y) > 0.01 or math_abs(cachedSize.Z - currentSize.Z) > 0.01 then
			objectData.PartSizes[primaryPart] = currentSize
			sizeChanged = true
		end
	end

	local descendants = object:GetDescendants()
	local checkInterval = math_max(1, math_floor(#descendants / 10))

	for i = 1, #descendants, checkInterval do
		local desc = descendants[i]
		if desc:IsA("BasePart") then
			local currentSize = desc.Size
			local cachedSize = objectData.PartSizes[desc]

			if not cachedSize or math_abs(cachedSize.X - currentSize.X) > 0.01 or math_abs(cachedSize.Y - currentSize.Y) > 0.01 or math_abs(cachedSize.Z - currentSize.Z) > 0.01 then
				objectData.PartSizes[desc] = currentSize
				sizeChanged = true
			end
		end
	end

	return sizeChanged
end

function ESPLibrary:InvalidateGradientCache()
	GradientCache = {}
	for _, esp in pairs(self.ESPObjects) do
		esp._cachedBoxGradient = nil
		esp._cachedFillGradient = nil
	end
end

function ESPLibrary:Load()
	if self.IsRunning then
		return
	end

	self.IsRunning = true

	RunService:UnbindFromRenderStep("ESPLibraryUpdate")

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:CreateESP(player)
		end)
	end

	local playerAddedConn = cache(Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:CreateESP(player)
		end)
	end))
	self.Connections[#self.Connections + 1] = playerAddedConn

	local playerRemovingConn = cache(Players.PlayerRemoving:Connect(function(player)
		task.spawn(function()
			self:RemoveESP(player)
		end)
	end))
	self.Connections[#self.Connections + 1] = playerRemovingConn

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			if player.Character then
				self:SetupCharacterChangeDetection(player, player.Character)
				local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local diedConn = cache(humanoid.Died:Connect(function()
						self:OnHumanoidDied(player)
					end))
					self.Connections[#self.Connections + 1] = diedConn
				end
			end

			local charAddedConn = cache(player.CharacterAdded:Connect(function(char)
				task.spawn(function()
					self:OnCharacterAdded(player)
					self:SetupCharacterChangeDetection(player, char)
					local humanoid = char:WaitForChild("Humanoid")
					local diedConn = cache(humanoid.Died:Connect(function()
						self:OnHumanoidDied(player)
					end))
					self.Connections[#self.Connections + 1] = diedConn
				end)
			end))
			self.Connections[#self.Connections + 1] = charAddedConn
		end)
	end

	local playerAddedCharConn = cache(Players.PlayerAdded:Connect(function(player)
		local charAddedConn = cache(player.CharacterAdded:Connect(function(char)
			task.spawn(function()
				self:OnCharacterAdded(player)
				self:SetupCharacterChangeDetection(player, char)
				local humanoid = char:WaitForChild("Humanoid")
				local diedConn = cache(humanoid.Died:Connect(function()
					self:OnHumanoidDied(player)
				end))
				self.Connections[#self.Connections + 1] = diedConn
			end)
		end))
		self.Connections[#self.Connections + 1] = charAddedConn
	end))
	self.Connections[#self.Connections + 1] = playerAddedCharConn

	local lastRenderTime = tick()

	local activePlayers = table.create(100)
	local activeObjects = table.create(50)

	RunService:BindToRenderStep("ESPLibraryUpdate", Enum.RenderPriority.Camera.Value + 1, function()
		local currentTime = tick()
		local deltaTime = currentTime - lastRenderTime
		lastRenderTime = currentTime

		local playerCount = 0
		for player, esp in pairs(self.ESPObjects) do
			if player.Parent then
				playerCount = playerCount + 1
				activePlayers[playerCount] = esp
			end
		end

		for i = 1, playerCount do
			local esp = activePlayers[i]
			if esp and esp.Player.Parent then
				self:UpdateESP(esp, deltaTime)
			end
		end

		for i = 1, playerCount do
			activePlayers[i] = nil
		end

		local objCount = 0
		for object, objectData in pairs(self.CustomObjects) do
			if object.Parent then
				objCount = objCount + 1
				activeObjects[objCount] = objectData

				if objCount >= 25 then
					break
				end
			end
		end

		for i = 1, objCount do
			self:UpdateCustomObject(activeObjects[i])
			activeObjects[i] = nil
		end

		for i = 1, #self.CustomDrawingObjects do
			local customDrawing = self.CustomDrawingObjects[i]
			if customDrawing.Update then
				pcall(customDrawing.Update, customDrawing.Drawing)
			end
		end
	end)
end

function ESPLibrary:Unload()
	if not self.IsRunning then
		return
	end

	self.IsRunning = false

	RunService:UnbindFromRenderStep("ESPLibraryUpdate")

	for _, conn in ipairs(self.Connections) do
		conn:Disconnect()
	end
	self.Connections = {}

	for player, _ in pairs(self.ESPObjects) do
		self:RemoveESP(player)
	end

	for object, _ in pairs(self.CustomObjects) do
		self:RemoveCustomObject(object)
	end

	state.UNLOAD()
end

function ESPLibrary:ResetPlayerESPColors(player)
	local esp = self.ESPObjects[player]
	if not esp then
		return
	end

	if self.Settings.Box.Enabled then
		local outline = esp.Drawings.BoxOutline
		outline.StrokeGradientEnabled = self.Settings.Box.GradientEnabled
		outline.StrokeGradientColors = self.Settings.Box.GradientColors
		outline.StrokeGradientRotation = self.Settings.Box.GradientRotation
		outline.Color = self.Settings.Box.Color
	end

	if self.Settings.BoxFill.Enabled then
		local fill = esp.Drawings.BoxFill
		fill.GradientEnabled = self.Settings.BoxFill.GradientEnabled
		fill.GradientColors = self.Settings.BoxFill.GradientColors
		fill.GradientRotation = self.Settings.BoxFill.GradientRotation
		fill.Color = self.Settings.BoxFill.Color
	end

	if self.Settings.Name.Enabled then
		esp.Drawings.Name.Color = self.Settings.Name.Color
	end

	if self.Settings.Distance.Enabled then
		esp.Drawings.Distance.Color = self.Settings.Distance.Color
	end

	if self.Settings.TargetList then
		self.Settings.TargetList._friendlyLookup = nil
		self.Settings.TargetList._enemyLookup = nil
	end

	for player, esp in pairs(self.ESPObjects) do
		esp.ColorCache = nil
		esp.LastDistanceInt = nil
		esp.LastSizeCheck = nil
	end
end

function ESPLibrary:InvalidateLookupTables()
	if self.Settings.TargetList then
		self.Settings.TargetList._friendlyLookup = nil
		self.Settings.TargetList._enemyLookup = nil
	end
end

function ESPLibrary:AddFriendly(searchName)
	local player = self:FindPlayer(searchName)

	if not player then
		return false
	end

	local playerName = player.Name

	for _, name in ipairs(self.Settings.TargetList.Friendlies) do
		if name == playerName then
			return false
		end
	end

	for i, name in ipairs(self.Settings.TargetList.Enemies) do
		if name == playerName then
			table.remove(self.Settings.TargetList.Enemies, i)
			break
		end
	end

	self.Settings.TargetList.Friendlies[#self.Settings.TargetList.Friendlies + 1] = playerName

	self:InvalidateLookupTables()

	TeamColorCache[player.UserId] = nil

	local esp = self.ESPObjects[player]
	if esp then
		self:UpdateESP(esp)
	end

	return true
end

function ESPLibrary:AddEnemy(searchName)
	local player = self:FindPlayer(searchName)

	if not player then
		return false
	end

	local playerName = player.Name

	for _, name in ipairs(self.Settings.TargetList.Enemies) do
		if name == playerName then
			return false
		end
	end

	for i, name in ipairs(self.Settings.TargetList.Friendlies) do
		if name == playerName then
			table.remove(self.Settings.TargetList.Friendlies, i)
			break
		end
	end

	self.Settings.TargetList.Enemies[#self.Settings.TargetList.Enemies + 1] = playerName

	self:InvalidateLookupTables()

	TeamColorCache[player.UserId] = nil

	local esp = self.ESPObjects[player]
	if esp then
		self:UpdateESP(esp)
	end

	return true
end

function ESPLibrary:RemoveFriendly(searchName)
	local player = self:FindPlayer(searchName)

	if not player then
		return false
	end

	local playerName = player.Name
	local wasRemoved = false

	for i, name in ipairs(self.Settings.TargetList.Friendlies) do
		if name == playerName then
			table.remove(self.Settings.TargetList.Friendlies, i)
			wasRemoved = true
			break
		end
	end

	TeamColorCache[player.UserId] = nil

	self:ResetPlayerESPColors(player)
	local esp = self.ESPObjects[player]
	if esp then
		self:UpdateESP(esp)
	end

	return wasRemoved
end

function ESPLibrary:RemoveEnemy(searchName)
	local player = self:FindPlayer(searchName)

	if not player then
		return false
	end

	local playerName = player.Name
	local wasRemoved = false

	for i, name in ipairs(self.Settings.TargetList.Enemies) do
		if name == playerName then
			table.remove(self.Settings.TargetList.Enemies, i)
			wasRemoved = true
			break
		end
	end

	TeamColorCache[player.UserId] = nil

	self:ResetPlayerESPColors(player)
	local esp = self.ESPObjects[player]
	if esp then
		self:UpdateESP(esp)
	end

	return wasRemoved
end

function ESPLibrary:ClearFriendlies()
	self.Settings.TargetList.Friendlies = {}

	TeamColorCache = {}

	for player, esp in pairs(self.ESPObjects) do
		if player.Parent then
			self:ResetPlayerESPColors(player)
			self:UpdateESP(esp)
		end
	end
end

function ESPLibrary:ClearEnemies()
	self.Settings.TargetList.Enemies = {}

	TeamColorCache = {}

	for player, esp in pairs(self.ESPObjects) do
		if player.Parent then
			self:ResetPlayerESPColors(player)
			self:UpdateESP(esp)
		end
	end
end

function ESPLibrary:ShowOnlyFriendlies()
	self:UpdateSettings({
		TargetList = {
			ShowFriendlies = true,
			ShowEnemies = false,
			ShowOthers = false,
		},
	})
end

function ESPLibrary:ShowOnlyEnemies()
	self:UpdateSettings({
		TargetList = {
			ShowFriendlies = false,
			ShowEnemies = true,
			ShowOthers = false,
		},
	})
end

function ESPLibrary:ShowOnlyOthers()
	self:UpdateSettings({
		TargetList = {
			ShowFriendlies = false,
			ShowEnemies = false,
			ShowOthers = true,
		},
	})
end

function ESPLibrary:ShowAll()
	self:UpdateSettings({
		TargetList = {
			ShowFriendlies = true,
			ShowEnemies = true,
			ShowOthers = true,
		},
	})
end

function ESPLibrary:ToggleColoredESP(enabled)
	self:UpdateSettings({
		TargetList = {
			UseDifferentColors = enabled,
		},
	})
end

function ESPLibrary:GetFriendlies()
	return self.Settings.TargetList.Friendlies
end

function ESPLibrary:GetEnemies()
	return self.Settings.TargetList.Enemies
end

return ESPLibrary, Drawing
