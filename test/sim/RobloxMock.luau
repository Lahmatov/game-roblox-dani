--!nocheck
-- Упрощённая имитация Roblox для автоматического плейтеста без Roblox Studio.
-- Есть: экземпляры (Instance), атрибуты, сигналы, сервисы, task-планировщик с виртуальным временем,
-- Vector3/CFrame, простое движение гуманоидов (MoveTo) и летящих деталей.
-- Нет: настоящей физики, столкновений, рендера. Поэтому стены здесь проходимы.

local Mock = {}

local realTypeof = typeof
local now = 1000
local STEP = 1 / 20

Mock.errors = {}
Mock.warnings = {}
Mock.announcements = {}

local function record(kind, msg)
	table.insert(kind == "error" and Mock.errors or Mock.warnings, msg)
	print(string.format("[%s @%.1f] %s", kind, now - 1000, tostring(msg)))
end

----------------------------------------------------------------------
-- Типы данных
----------------------------------------------------------------------

local V3mt = { __type = "Vector3" }
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, V3mt)
end
V3mt.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then
			return v3(0 / 0, 0 / 0, 0 / 0)
		end
		return v3(v.X / m, v.Y / m, v.Z / m)
	elseif k == "Dot" then
		return function(a, b)
			return a.X * b.X + a.Y * b.Y + a.Z * b.Z
		end
	elseif k == "Cross" then
		return function(a, b)
			return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X)
		end
	end
	error(tostring(k) .. " is not a valid member of Vector3", 2)
end
V3mt.__add = function(a, b)
	return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end
V3mt.__sub = function(a, b)
	return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end
V3mt.__mul = function(a, b)
	if type(a) == "number" then
		return v3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return v3(a.X * b, a.Y * b, a.Z * b)
	end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then
		return v3(a.X / b, a.Y / b, a.Z / b)
	end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3mt.__unm = function(a)
	return v3(-a.X, -a.Y, -a.Z)
end
V3mt.__eq = function(a, b)
	return a.X == b.X and a.Y == b.Y and a.Z == b.Z
end
V3mt.__tostring = function(v)
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1) }

-- CFrame: позиция p и матрица поворота r (по строкам)
local CFmt = { __type = "CFrame" }
local function cf(p, r)
	return setmetatable({ _p = p, _r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CFmt)
end
local function rotate(r, v)
	return v3(r[1] * v.X + r[2] * v.Y + r[3] * v.Z, r[4] * v.X + r[5] * v.Y + r[6] * v.Z, r[7] * v.X + r[8] * v.Y + r[9] * v.Z)
end
local function matmul(a, b)
	local out = {}
	for i = 0, 2 do
		for j = 0, 2 do
			local s = 0
			for k = 0, 2 do
				s += a[i * 3 + k + 1] * b[k * 3 + j + 1]
			end
			out[i * 3 + j + 1] = s
		end
	end
	return out
end
local function transpose(r)
	return { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
end
CFmt.__index = function(c, k)
	if k == "Position" then
		return c._p
	elseif k == "X" then
		return c._p.X
	elseif k == "Y" then
		return c._p.Y
	elseif k == "Z" then
		return c._p.Z
	elseif k == "LookVector" then
		return v3(-c._r[3], -c._r[6], -c._r[9])
	elseif k == "RightVector" then
		return v3(c._r[1], c._r[4], c._r[7])
	elseif k == "UpVector" then
		return v3(c._r[2], c._r[5], c._r[8])
	elseif k == "Inverse" then
		return function(self)
			local rt = transpose(self._r)
			return cf(-rotate(rt, self._p), rt)
		end
	elseif k == "PointToWorldSpace" then
		return function(self, v)
			return self * v
		end
	end
	error(tostring(k) .. " is not a valid member of CFrame", 2)
end
CFmt.__mul = function(a, b)
	if getmetatable(b) == V3mt then
		return a._p + rotate(a._r, b)
	end
	return cf(a._p + rotate(a._r, b._p), matmul(a._r, b._r))
end
CFmt.__add = function(a, b)
	return cf(a._p + b, a._r)
end
CFmt.__sub = function(a, b)
	return cf(a._p - b, a._r)
end
CFmt.__tostring = function(c)
	return "CFrame" .. tostring(c._p)
end

local CFrame = {}
function CFrame.new(x, y, z)
	if x == nil then
		return cf(v3(0, 0, 0))
	elseif getmetatable(x) == V3mt then
		return cf(x)
	end
	return cf(v3(x, y, z))
end
function CFrame.Angles(rx, ry, rz)
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(v3(0, 0, 0), matmul(matmul(Rx, Ry), Rz))
end
CFrame.fromEulerAnglesXYZ = CFrame.Angles
function CFrame.lookAt(at, target)
	local look = (target - at).Unit
	local back = -look
	local up = v3(0, 1, 0)
	local right = up:Cross(back).Unit
	local newUp = back:Cross(right)
	return cf(at, { right.X, newUp.X, back.X, right.Y, newUp.Y, back.Y, right.Z, newUp.Z, back.Z })
end

local C3mt = { __type = "Color3" }
C3mt.__eq = function(a, b)
	return math.abs(a.R - b.R) < 1e-6 and math.abs(a.G - b.G) < 1e-6 and math.abs(a.B - b.B) < 1e-6
end
local Color3 = {
	new = function(r, g, b)
		return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, C3mt)
	end,
}
Color3.fromRGB = function(r, g, b)
	return Color3.new(r / 255, g / 255, b / 255)
end

local UDim = {
	new = function(s, o)
		return setmetatable({ Scale = s, Offset = o }, { __type = "UDim" })
	end,
}
local UDim2mt = { __type = "UDim2" }
local UDim2 = {
	new = function(xs, xo, ys, yo)
		return setmetatable({ X = UDim.new(xs or 0, xo or 0), Y = UDim.new(ys or 0, yo or 0) }, UDim2mt)
	end,
}
UDim2.fromOffset = function(x, y)
	return UDim2.new(0, x, 0, y)
end
UDim2.fromScale = function(x, y)
	return UDim2.new(x, 0, y, 0)
end

local TweenInfo = {
	new = function(time, ...)
		return { Time = time or 1, Args = { ... } }
	end,
}
local RaycastParams = {
	new = function()
		return {}
	end,
}

local enumCache = {}
local Enum = setmetatable({}, {
	__index = function(_, enumName)
		local items = enumCache[enumName]
		if not items then
			items = setmetatable({}, {
				__index = function(t, item)
					local token = setmetatable({ Name = item, EnumType = enumName }, {
						__type = "EnumItem",
						__tostring = function()
							return "Enum." .. enumName .. "." .. item
						end,
					})
					rawset(t, item, token)
					return token
				end,
			})
			enumCache[enumName] = items
		end
		return items
	end,
})

local function mockTypeof(x)
	local mt = getmetatable(x)
	if type(mt) == "table" and rawget(mt, "__type") then
		return rawget(mt, "__type")
	end
	return realTypeof(x)
end

----------------------------------------------------------------------
-- Планировщик task
----------------------------------------------------------------------

local scheduled = {} -- { {co, at, args} }
local cancelled = setmetatable({}, { __mode = "k" })

local function resume(co, ...)
	if cancelled[co] or coroutine.status(co) == "dead" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		record("error", err)
	end
end

local function wrap(fn)
	return coroutine.create(function(...)
		local ok, err = xpcall(fn, debug.traceback, ...)
		if not ok then
			record("error", err)
		end
	end)
end

local task = {}
function task.spawn(f, ...)
	local co = if type(f) == "thread" then f else wrap(f)
	resume(co, ...)
	return co
end
function task.defer(f, ...)
	local co = if type(f) == "thread" then f else wrap(f)
	table.insert(scheduled, { co = co, at = now, args = table.pack(...) })
	return co
end
function task.delay(t, f, ...)
	local co = if type(f) == "thread" then f else wrap(f)
	table.insert(scheduled, { co = co, at = now + (t or 0), args = table.pack(...) })
	return co
end
function task.wait(t)
	local co = coroutine.running()
	local start = now
	table.insert(scheduled, { co = co, at = now + math.max(t or 0, 0.001), args = table.pack() })
	coroutine.yield()
	return now - start
end
function task.cancel(co)
	cancelled[co] = true
end

----------------------------------------------------------------------
-- Сигналы
----------------------------------------------------------------------

local Signal = {}
Signal.__index = Signal
function Signal.new()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true }
	local handlers = self.handlers
	function conn.Disconnect()
		conn.Connected = false
		local i = table.find(handlers, conn)
		if i then
			table.remove(handlers, i)
		end
	end
	conn.fn = fn
	table.insert(handlers, conn)
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Fire(...)
	for _, conn in table.clone(self.handlers) do
		if conn.Connected then
			task.spawn(conn.fn, ...)
		end
	end
end
function Signal:Wait()
	local co = coroutine.running()
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		resume(co, ...)
	end)
	return coroutine.yield()
end

----------------------------------------------------------------------
-- Instance
----------------------------------------------------------------------

local INHERITS = {
	Part = "BasePart",
	WedgePart = "BasePart",
	TrussPart = "BasePart",
	SpawnLocation = "Part",
	BasePart = "PVInstance",
	Model = "PVInstance",
	Workspace = "Model",
	Script = "LuaSourceContainer",
	LocalScript = "Script",
	ModuleScript = "LuaSourceContainer",
	SpotLight = "Light",
	PointLight = "Light",
	Shirt = "Clothing",
	Pants = "Clothing",
	TextLabel = "GuiObject",
	TextButton = "GuiButton",
	GuiButton = "GuiObject",
	Frame = "GuiObject",
	ScrollingFrame = "GuiObject",
	ScreenGui = "LayerCollector",
	SurfaceGui = "LayerCollector",
	BillboardGui = "LayerCollector",
	IntValue = "ValueBase",
}

local function isA(className, target)
	if target == "Instance" then
		return true
	end
	local c = className
	while c do
		if c == target then
			return true
		end
		c = INHERITS[c]
	end
	return false
end

local DEFAULTS = {
	BasePart = {
		Anchored = false,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
		Transparency = 0,
		Massless = false,
		Size = v3(4, 1, 2),
		AssemblyLinearVelocity = v3(0, 0, 0),
	},
	Humanoid = { Health = 100, MaxHealth = 100, WalkSpeed = 16, JumpHeight = 7.2, HipHeight = 2 },
	Light = { Enabled = true, Brightness = 1, Range = 8 },
	Sparkles = { Enabled = true },
	GuiObject = { Visible = true, Text = "", BackgroundTransparency = 0, TextTransparency = 0 },
	IntValue = { Value = 0 },
	Players = { RespawnTime = 5 },
}

local SIGNALS = {
	Heartbeat = true,
	RenderStepped = true,
	Stepped = true,
	PlayerAdded = true,
	PlayerRemoving = true,
	CharacterAdded = true,
	CharacterAppearanceLoaded = true,
	OnServerEvent = true,
	OnClientEvent = true,
	Activated = true,
	MouseButton1Click = true,
	InputBegan = true,
	Touched = true,
	ChildAdded = true,
	Died = true,
	Running = true,
}

local data = setmetatable({}, { __mode = "k" })
local Instance = {}
local methods = {}
local IMt = { __type = "Instance" }
local moving = {} -- детали, у которых есть скорость
local humanoids = setmetatable({}, { __mode = "k" })

local function new(className)
	local obj = setmetatable({}, IMt)
	data[obj] = {
		ClassName = className,
		Name = className,
		Parent = nil,
		children = {},
		props = {},
		attrs = {},
		attrSignals = {},
		signals = {},
		destroyed = false,
	}
	return obj
end
Instance.new = function(className, parent)
	local obj = new(className)
	if className == "Part" or className == "SpawnLocation" or className == "WedgePart" or className == "TrussPart" then
		data[obj].props.CFrame = CFrame.new()
	end
	if className == "Humanoid" then
		humanoids[obj] = true
	end
	if parent then
		obj.Parent = parent
	end
	return obj
end

local function default(d, k)
	local c = d.ClassName
	while c do
		local t = DEFAULTS[c]
		if t and t[k] ~= nil then
			return t[k]
		end
		c = INHERITS[c]
	end
	return nil
end

IMt.__index = function(obj, k)
	local d = data[obj]
	if methods[k] then
		return methods[k]
	elseif k == "Name" or k == "ClassName" or k == "Parent" then
		return d[k]
	elseif k == "Position" and isA(d.ClassName, "BasePart") then
		return d.props.CFrame.Position
	end
	local v = d.props[k]
	if v ~= nil then
		return v
	end
	if SIGNALS[k] then
		local s = d.signals[k]
		if not s then
			s = Signal.new()
			d.signals[k] = s
		end
		return s
	end
	for _, child in d.children do
		if data[child].Name == k then
			return child
		end
	end
	return default(d, k)
end

IMt.__newindex = function(obj, k, v)
	local d = data[obj]
	if k == "Parent" then
		if d.destroyed then
			error("The Parent property of " .. d.Name .. " is locked", 2)
		end
		if d.Parent then
			local siblings = data[d.Parent].children
			local i = table.find(siblings, obj)
			if i then
				table.remove(siblings, i)
			end
		end
		d.Parent = v
		if v then
			table.insert(data[v].children, obj)
			local s = data[v].signals.ChildAdded
			if s then
				s:Fire(obj)
			end
		end
	elseif k == "Name" then
		d.Name = v
	elseif k == "Position" and isA(d.ClassName, "BasePart") then
		d.props.CFrame = cf(v, d.props.CFrame._r)
	else
		if k == "AssemblyLinearVelocity" then
			moving[obj] = true
		end
		d.props[k] = v
	end
end

IMt.__tostring = function(obj)
	return data[obj].Name
end

function methods.IsA(self, className)
	return isA(data[self].ClassName, className)
end
function methods.GetChildren(self)
	return table.clone(data[self].children)
end
function methods.GetDescendants(self)
	local out = {}
	local function walk(o)
		for _, c in data[o].children do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function methods.FindFirstChild(self, name, recursive)
	local list = if recursive then self:GetDescendants() else data[self].children
	for _, c in list do
		if data[c].Name == name then
			return c
		end
	end
	return nil
end
function methods.FindFirstChildOfClass(self, className)
	for _, c in data[self].children do
		if data[c].ClassName == className then
			return c
		end
	end
	return nil
end
function methods.FindFirstChildWhichIsA(self, className, recursive)
	local list = if recursive then self:GetDescendants() else data[self].children
	for _, c in list do
		if isA(data[c].ClassName, className) then
			return c
		end
	end
	return nil
end
function methods.WaitForChild(self, name, timeout)
	local deadline = now + (timeout or 10)
	while true do
		local c = self:FindFirstChild(name)
		if c then
			return c
		end
		if now >= deadline then
			record("warning", "Infinite yield possible on " .. data[self].Name .. ":WaitForChild(\"" .. name .. "\")")
			if timeout then
				return nil
			end
			deadline = math.huge
		end
		task.wait(0.05)
	end
end
function methods.Destroy(self)
	local d = data[self]
	if d.destroyed then
		return
	end
	for _, c in table.clone(d.children) do
		c:Destroy()
	end
	if d.Parent then
		self.Parent = nil
	end
	d.destroyed = true
	moving[self] = nil
	for _, s in d.signals do
		table.clear(s.handlers)
	end
end
function methods.ClearAllChildren(self)
	for _, c in table.clone(data[self].children) do
		c:Destroy()
	end
end
function methods.GetAttribute(self, name)
	return data[self].attrs[name]
end
function methods.GetAttributes(self)
	return table.clone(data[self].attrs)
end
function methods.SetAttribute(self, name, value)
	local d = data[self]
	if d.attrs[name] == value then
		return
	end
	d.attrs[name] = value
	local s = d.attrSignals[name]
	if s then
		s:Fire()
	end
end
function methods.GetAttributeChangedSignal(self, name)
	local d = data[self]
	local s = d.attrSignals[name]
	if not s then
		s = Signal.new()
		d.attrSignals[name] = s
	end
	return s
end
function methods.GetPropertyChangedSignal(_self, _name)
	return Signal.new()
end
function methods.GetFullName(self)
	local names = {}
	local o = self
	while o and data[o].ClassName ~= "DataModel" do
		table.insert(names, 1, data[o].Name)
		o = data[o].Parent
	end
	return table.concat(names, ".")
end
function methods.GetPivot(self)
	local d = data[self]
	if isA(d.ClassName, "BasePart") then
		return d.props.CFrame
	end
	local primary = d.props.PrimaryPart or self:FindFirstChild("HumanoidRootPart") or self:FindFirstChildWhichIsA("BasePart", true)
	return if primary then primary.CFrame else CFrame.new()
end
function methods.PivotTo(self, target)
	local d = data[self]
	if isA(d.ClassName, "BasePart") then
		d.props.CFrame = target
		return
	end
	local delta = target * self:GetPivot():Inverse()
	for _, p in self:GetDescendants() do
		if isA(data[p].ClassName, "BasePart") then
			data[p].props.CFrame = delta * data[p].props.CFrame
		end
	end
	-- Бот после телепорта останавливается (как игрок, которого перенесли)
	local humanoid = self:FindFirstChildOfClass("Humanoid")
	if humanoid then
		data[humanoid].props.MoveTarget = nil
	end
end
function methods.SetNetworkOwner(self, _owner)
	if data[self].props.Anchored then
		error("Network Ownership API cannot be called on Anchored parts", 2)
	end
end
-- Humanoid
function methods.MoveTo(self, position)
	data[self].props.MoveTarget = position
end
-- Sound
function methods.Play(self)
	data[self].props.Playing = true
end
-- RemoteEvent
function methods.FireServer(self, ...)
	self.OnServerEvent:Fire(Mock.localPlayer, ...)
end
function methods.FireAllClients(self, ...)
	if self.Name == "Announce" then
		local text = ...
		table.insert(Mock.announcements, { t = now - 1000, text = text })
		print(string.format("  📣 [%.1f] %s", now - 1000, tostring(text)))
	end
	self.OnClientEvent:Fire(...)
end
function methods.FireClient(self, player, ...)
	if player == Mock.localPlayer then
		self.OnClientEvent:Fire(...)
	end
end

----------------------------------------------------------------------
-- Сервисы
----------------------------------------------------------------------

local game = new("DataModel")
data[game].Name = "Game"
local services = {}

local stores = {}
local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = deepCopy(v)
	end
	return out
end

local function makeService(name)
	local s = new(name)
	data[s].Name = name
	s.Parent = game
	services[name] = s
	return s
end

function methods.GetService(_self, name)
	return services[name] or makeService(name)
end
function methods.BindToClose(_self, fn)
	Mock.closeHandlers = Mock.closeHandlers or {}
	table.insert(Mock.closeHandlers, fn)
end
-- Players
function methods.GetPlayers(self)
	local out = {}
	for _, c in data[self].children do
		if data[c].ClassName == "Player" then
			table.insert(out, c)
		end
	end
	return out
end
-- RunService
function methods.IsServer(_self)
	return Mock.context == "server"
end
function methods.IsClient(_self)
	return Mock.context == "client"
end
function methods.IsStudio(_self)
	return true
end
-- Workspace
function methods.GetServerTimeNow(_self)
	return now
end
function methods.Raycast(_self, origin, direction, _params)
	-- Единственное, во что попадает луч в имитации, — земля (y = 0)
	local endY = origin.Y + direction.Y
	if origin.Y >= 0 and endY <= 0 and direction.Y < 0 then
		local t = origin.Y / -direction.Y
		return { Position = origin + direction * t }
	end
	return nil
end
-- PathfindingService: путь — прямая линия (стен в имитации нет)
function methods.CreatePath(_self, _params)
	local path = { Status = Enum.PathStatus.Success, _points = {} }
	function path.ComputeAsync(self, from, to)
		self._points = {
			{ Position = from, Action = Enum.PathWaypointAction.Walk },
			{ Position = to, Action = Enum.PathWaypointAction.Walk },
		}
	end
	function path.GetWaypoints(self)
		return self._points
	end
	return path
end
-- Players:CreateHumanoidModelFromDescription
function methods.CreateHumanoidModelFromDescription(_self, _description, _rigType)
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = character
	local head = Instance.new("Part")
	head.Name = "Head"
	head.CFrame = CFrame.new(0, 1.5, 0)
	head.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	Instance.new("Animator").Parent = humanoid
	Instance.new("LocalScript").Name = "Animate"
	character.PrimaryPart = root
	return character
end
function methods.GetHumanoidDescriptionFromUserId(_self, userId)
	local d = Instance.new("HumanoidDescription")
	d.UserId = userId
	return d
end
function methods.ScaleTo(self, scale)
	data[self].props.Scale = scale
end
function methods.GetBoundingBox(self)
	return self:GetPivot(), v3(4, 5, 2)
end
function methods.LoadAnimation(_self, _animation)
	local track = { IsPlaying = false }
	function track.Play(t)
		t.IsPlaying = true
	end
	function track.Stop(t)
		t.IsPlaying = false
	end
	return track
end
-- DataStoreService
function methods.GetDataStore(_self, name)
	stores[name] = stores[name] or {}
	local store = stores[name]
	return {
		GetAsync = function(_, key)
			return deepCopy(store[key])
		end,
		SetAsync = function(_, key, value)
			store[key] = deepCopy(value)
		end,
	}
end
-- Debris
function methods.AddItem(_self, item, lifetime)
	task.delay(lifetime, function()
		item:Destroy()
	end)
end
-- TweenService
function methods.Create(_self, inst, _info, goals)
	return {
		Play = function()
			for k, v in goals do
				inst[k] = v
			end
		end,
		Cancel = function() end,
	}
end

local workspace = makeService("Workspace")
local camera = new("Camera")
data[camera].props.CFrame = CFrame.new()
camera.Parent = workspace
workspace.CurrentCamera = camera
for _, name in { "Players", "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "Lighting", "RunService" } do
	makeService(name)
end

----------------------------------------------------------------------
-- Загрузка скриптов (как Rojo)
----------------------------------------------------------------------

local caches = { server = {}, client = {} }
local mockOs = setmetatable({
	clock = function()
		return now
	end,
	time = function()
		return math.floor(now)
	end,
}, { __index = os })

local G -- окружение для скриптов

local function load(inst)
	local path = data[inst].props.__path
	local source = Mock.files[path]
	assert(source, "нет файла " .. tostring(path))
	local fn = Mock.compile(source, path)
	if type(fn) == "string" then
		error("Ошибка компиляции " .. path .. ": " .. fn)
	end
	setfenv(fn, setmetatable({ script = inst }, { __index = G }))
	return fn
end

local function mockRequire(inst)
	local cache = caches[Mock.context]
	if cache[inst] == nil then
		cache[inst] = load(inst)()
	end
	return cache[inst]
end

G = setmetatable({
	game = game,
	workspace = workspace,
	Instance = Instance,
	Vector3 = Vector3,
	CFrame = CFrame,
	Color3 = Color3,
	UDim = UDim,
	UDim2 = UDim2,
	TweenInfo = TweenInfo,
	RaycastParams = RaycastParams,
	Enum = Enum,
	task = task,
	typeof = mockTypeof,
	require = mockRequire,
	os = mockOs,
	tick = function()
		return now
	end,
	warn = function(...)
		local parts = {}
		for i = 1, select("#", ...) do
			table.insert(parts, tostring((select(i, ...))))
		end
		record("warning", table.concat(parts, " "))
	end,
}, { __index = getfenv(0) })

function Mock.addScript(parent, name, className, path)
	local s = Instance.new(className)
	s.Name = name
	data[s].props.__path = path
	s.Parent = parent
	return s
end

function Mock.runScript(inst, context)
	Mock.context = context
	local fn = load(inst)
	task.spawn(fn)
end

function Mock.require(inst, context)
	Mock.context = context or "server"
	return mockRequire(inst)
end

----------------------------------------------------------------------
-- Игроки-боты
----------------------------------------------------------------------

local nextUserId = 1
function Mock.addPlayer(name, userId)
	local players = services.Players
	local p = new("Player")
	data[p].Name = name
	p.DisplayName = name
	p.UserId = userId or nextUserId
	nextUserId += 1
	local playerGui = new("PlayerGui")
	data[playerGui].Name = "PlayerGui"
	playerGui.Parent = p
	p.Parent = players
	players.PlayerAdded:Fire(p)
	return p
end

function Mock.spawnCharacter(player)
	local old = player.Character
	if old then
		old:Destroy()
	end
	local spawnCF = CFrame.new(0, 0, 0)
	for _, d in workspace:GetDescendants() do
		if d.ClassName == "SpawnLocation" then
			spawnCF = d.CFrame + v3(0, 3, 0)
			break
		end
	end
	local character = Instance.new("Model")
	character.Name = player.Name
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = spawnCF
	root.Parent = character
	local head = Instance.new("Part")
	head.Name = "Head"
	head.CFrame = spawnCF + v3(0, 1.5, 0)
	head.Parent = character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	Instance.new("BodyColors").Parent = character
	Instance.new("Shirt").Parent = character
	character.PrimaryPart = root
	player.Character = character
	character.Parent = workspace
	player.CharacterAdded:Fire(character)
	player.CharacterAppearanceLoaded:Fire(character)
	return character
end

function Mock.removePlayer(player)
	services.Players.PlayerRemoving:Fire(player)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
	player.Parent = nil
end

----------------------------------------------------------------------
-- Ход времени
----------------------------------------------------------------------

local function moveHumanoids(dt)
	for d in humanoids do
		if not data[d].destroyed then
			local target = data[d].props.MoveTarget
			local model = data[d].Parent
			local root = model and model:FindFirstChild("HumanoidRootPart")
			if target and root and not root.Anchored and d.Health > 0 then
				local pos = root.Position
				local flat = v3(target.X - pos.X, 0, target.Z - pos.Z)
				local dist = flat.Magnitude
				local stepLen = d.WalkSpeed * dt
				if dist > 0.05 and stepLen > 0 then
					local move = if dist <= stepLen then flat else flat.Unit * stepLen
					-- Вертикаль: идём к высоте цели (у нас нет настоящего пола)
					local y = pos.Y + (target.Y + 3 - pos.Y) * math.min(1, stepLen / math.max(dist, 0.001))
					local newPos = v3(pos.X + move.X, y, pos.Z + move.Z)
					local delta = newPos - pos
					for _, part in model:GetDescendants() do
						if isA(data[part].ClassName, "BasePart") then
							data[part].props.CFrame = data[part].props.CFrame + delta
						end
					end
				end
			end
		end
	end
end

local function moveParts(dt)
	for part in table.clone(moving) do
		local d = data[part]
		if d.destroyed or d.props.Anchored then
			moving[part] = nil
		else
			local v = d.props.AssemblyLinearVelocity
			d.props.CFrame = d.props.CFrame + v * dt
		end
	end
end

function Mock.step()
	now += STEP
	moveHumanoids(STEP)
	moveParts(STEP)
	local rs = services.RunService
	rs.Heartbeat:Fire(STEP)
	rs.RenderStepped:Fire(STEP)
	local due = {}
	local rest = {}
	for _, item in scheduled do
		if item.at <= now then
			table.insert(due, item)
		else
			table.insert(rest, item)
		end
	end
	scheduled = rest
	table.sort(due, function(a, b)
		return a.at < b.at
	end)
	for _, item in due do
		resume(item.co, table.unpack(item.args, 1, item.args.n))
	end
end

function Mock.advance(seconds)
	local target = now + seconds
	while now < target do
		Mock.step()
	end
end

-- Ждать, пока условие не станет верным. Возвращает true, если дождались.
function Mock.advanceUntil(cond, maxSeconds)
	local target = now + maxSeconds
	while now < target do
		if cond() then
			return true
		end
		Mock.step()
	end
	return cond()
end

function Mock.time()
	return now - 1000
end

Mock.game = game
Mock.Instance = Instance
Mock.workspace = workspace
Mock.services = services
Mock.Vector3 = Vector3
Mock.CFrame = CFrame
Mock.Color3 = Color3
Mock.data = data

return Mock
