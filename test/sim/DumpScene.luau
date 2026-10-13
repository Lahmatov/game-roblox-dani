--!nocheck
-- Собирает стадион в имитации и выгружает все детали в JSON — для картинок-превью.
local Mock = compile(readSource("test/sim/RobloxMock.luau"), "RobloxMock")()
Mock.compile = compile
Mock.files = {}
for _, path in string.split(listSources(), "\n") do
	Mock.files[path] = readSource(path)
end
local game = Mock.game
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local shared = Mock.Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = RS
local server = Mock.Instance.new("Folder")
server.Name = "Server"
server.Parent = SSS
for path in Mock.files do
	local dir, file = string.match(path, "^src/(%w+)/(.+)%.luau$")
	if dir == "shared" then
		Mock.addScript(shared, file, "ModuleScript", path)
	elseif dir == "server" then
		local name, kind = string.match(file, "^(.-)%.(%a+)$")
		if kind == "server" then
			Mock.addScript(server, name, "Script", path)
		else
			Mock.addScript(server, file, "ModuleScript", path)
		end
	end
end
local Config = Mock.require(shared.Config, "server")
Config.HERO_USER_ID = 1
Mock.runScript(server.Main, "server")
Mock.advance(1)

local out = {}
local function num(n)
	return string.format("%.3f", n)
end
local function color(c)
	return "[" .. num(c and c.R or 0.6) .. "," .. num(c and c.G or 0.6) .. "," .. num(c and c.B or 0.6) .. "]"
end
local function cframe(cf)
	local p, r = cf._p, cf._r
	local parts = { num(p.X), num(p.Y), num(p.Z) }
	for i = 1, 9 do
		table.insert(parts, num(r[i]))
	end
	return "[" .. table.concat(parts, ",") .. "]"
end
local function str(s)
	return '"' .. string.gsub(tostring(s), '[%c"\\]', " ") .. '"'
end
for _, d in Mock.workspace:GetDescendants() do
	if d:IsA("BasePart") then
		local shape = d.Shape and d.Shape.Name or "Block"
		local material = d.Material and d.Material.Name or "Plastic"
		table.insert(out, "{" .. table.concat({
			'"k":' .. str(d.ClassName),
			'"s":' .. str(shape),
			'"m":' .. str(material),
			'"z":[' .. num(d.Size.X) .. "," .. num(d.Size.Y) .. "," .. num(d.Size.Z) .. "]",
			'"cf":' .. cframe(d.CFrame),
			'"c":' .. color(d.Color),
			'"t":' .. num(d.Transparency or 0),
			'"n":' .. str(d.Name),
		}, ",") .. "}")
	elseif d.ClassName == "SpotLight" or d.ClassName == "PointLight" or d.ClassName == "SurfaceLight" then
		local p = d.Parent
		if p and p:IsA("BasePart") then
			table.insert(out, "{" .. table.concat({
				'"k":' .. str(d.ClassName),
				'"cf":' .. cframe(p.CFrame),
				'"c":' .. color(d.Color or Mock.Color3.new(1, 1, 1)),
				'"r":' .. num(d.Range or 8),
				'"b":' .. num(d.Brightness or 1),
				'"f":' .. str(d.Face and d.Face.Name or "Front"),
				'"a":' .. num(d.Angle or 90),
			}, ",") .. "}")
		end
	elseif d.ClassName == "TextLabel" and d.Text ~= "" then
		local gui = d.Parent
		local p = gui and gui.Parent
		if p and p:IsA("BasePart") and gui.ClassName == "SurfaceGui" then
			table.insert(out, "{" .. table.concat({
				'"k":"Text"',
				'"cf":' .. cframe(p.CFrame),
				'"z":[' .. num(p.Size.X) .. "," .. num(p.Size.Y) .. "," .. num(p.Size.Z) .. "]",
				'"f":' .. str(gui.Face and gui.Face.Name or "Front"),
				'"x":' .. str(d.Text),
				'"c":' .. color(d.TextColor3),
				'"bg":' .. color(d.BackgroundColor3),
				'"bt":' .. num(d.BackgroundTransparency or 0),
			}, ",") .. "}")
		end
	end
end
local L = game:GetService("Lighting")
writeOutput("{\"lighting\":{\"clock\":" .. num(L.ClockTime or 14) .. "},\"items\":[" .. table.concat(out, ",\n") .. "]}")
print("деталей: " .. #out .. ", ошибок: " .. #Mock.errors)
return #Mock.errors
