--!nocheck
-- Автоматический плейтест: боты играют несколько раундов, а мы проверяем правила.
-- Запуск: node test/run-playtest.mjs

local Mock = compile(readSource("test/sim/RobloxMock.luau"), "RobloxMock")()
Mock.compile = compile
Mock.files = {}
for _, path in string.split(listSources(), "\n") do
	Mock.files[path] = readSource(path)
end
local V = Mock.Vector3.new
local game = Mock.game
local Instance = Mock.Instance
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local passed, failed = 0, 0
local function check(ok, what)
	if ok then
		passed += 1
		print("  ✅ " .. what)
	else
		failed += 1
		print("  ❌ " .. what)
	end
end
local function section(name)
	print(string.format("\n=== %s (время игры %.0f с) ===", name, Mock.time()))
end

-- Дерево как в default.project.json
local shared = Instance.new("Folder")
shared.Name = "Shared"
shared.Parent = RS
local server = Instance.new("Folder")
server.Name = "Server"
server.Parent = SSS
local playerScripts = Instance.new("Folder")
playerScripts.Name = "StarterPlayerScripts"
playerScripts.Parent = StarterPlayer
for path in Mock.files do
	local dir, file = string.match(path, "^src/(%w+)/(.+)%.luau$")
	if dir then
		local name, kind = string.match(file, "^(.-)%.(%a+)$")
		if dir == "shared" then
			Mock.addScript(shared, file, "ModuleScript", path)
		elseif dir == "server" then
			if kind == "server" then
				Mock.addScript(server, name, "Script", path)
			else
				Mock.addScript(server, file, "ModuleScript", path)
			end
		elseif dir == "client" then
			Mock.addScript(playerScripts, name, "LocalScript", path)
		end
	end
end

local Config = Mock.require(shared.Config, "server")
Config.HERO_USER_ID = 777 -- проверим статую сына
-- Статуи пока спят, чтобы не мешать первым проверкам
Config.STATUE_WAKE_MIN = 10000
Config.STATUE_WAKE_MAX = 10001

section("Запуск сервера")
Mock.runScript(server.Main, "server")
Mock.advance(0.5)
check(#Mock.errors == 0, "сервер запустился без ошибок")
local stadium = Mock.workspace:FindFirstChild("Stadium")
check(stadium ~= nil, "стадион построен")
local partCount = 0
for _, d in stadium:GetDescendants() do
	if d:IsA("BasePart") then
		partCount += 1
	end
end
print("  деталей на стадионе: " .. partCount)
check(partCount > 300 and partCount < 9000, "размер стадиона разумный (300..9000 деталей)")
local statueCount = 0
for _, s in stadium.Statues:GetChildren() do
	if s:IsA("Model") then
		statueCount += 1
	end
end
check(statueCount == 8, "8 статуй футболистов")
local GameState = RS:WaitForChild("GameState")
local MAP = Mock.require(server.StadiumBuilder, "server").lastMap
local heroes = {}
for _, d in stadium:GetDescendants() do
	if d.Name == "HeroStatue" then
		table.insert(heroes, d)
	end
end
check(#heroes == 2, "статуя сына стоит в лобби и на стадионе")
check(heroes[1] and heroes[1].Pedestal.SurfaceGui.Title.Text == Config.HERO_TITLE, "на постаменте надпись «" .. Config.HERO_TITLE .. "»")
check(GameState:GetAttribute("BotLevel") == "dumb", "по умолчанию боты глупые")
local Remotes = RS:WaitForChild("Remotes")

local function Participants()
	return Mock.require(server.Participants, "server").all()
end
local function role(p)
	return p:GetAttribute("Role")
end
local function phase()
	return GameState:GetAttribute("Phase")
end
local function pos(p)
	return p.Character.HumanoidRootPart.Position
end
local function hum(p)
	return p.Character.Humanoid
end
local function goTo(p, v)
	hum(p):MoveTo(v)
end
local function stop(p)
	hum(p):MoveTo(pos(p))
end
local function teleport(p, v)
	p.Character:PivotTo(Mock.CFrame.new(v + V(0, 3, 0)))
	stop(p)
end
local function fire(name, player, ...)
	Remotes[name].OnServerEvent:Fire(player, ...)
end
local function announced(pattern, since)
	for _, a in Mock.announcements do
		if a.t >= (since or 0) and string.find(a.text, pattern, 1, true) then
			return true
		end
	end
	return false
end
local function findGui(player, predicate)
	for _, d in player.PlayerGui:GetDescendants() do
		if predicate(d) then
			return d
		end
	end
	return nil
end
local function trophy()
	return Mock.workspace:FindFirstChild("WorldCup")
end

check(GameState:GetAttribute("BotsEnabled") == true, "боты включены по умолчанию")
fire("ToggleBots", nil, false)
Mock.advance(0.1)
check(GameState:GetAttribute("BotsEnabled") == false, "ботов можно выключить (для проверок с живыми игроками)")

section("Игроки заходят")
local ana = Mock.addPlayer("Ana")
local bo = Mock.addPlayer("Bo")
local cid = Mock.addPlayer("Cid")
local dani = Mock.addPlayer("Dani")
local all = { ana, bo, cid, dani }
for _, p in all do
	Mock.spawnCharacter(p)
end
Mock.localPlayer = dani
Players.LocalPlayer = dani
Mock.runScript(playerScripts.Main, "client")
Mock.advance(0.5)
check(#Mock.errors == 0, "экран игрока (клиент) запустился без ошибок")
check(dani.PlayerGui:FindFirstChild("PryatkiUI") ~= nil, "у Дани появился экран игры")
check(role(ana) == "Lobby" and pos(ana).Y > 150, "игроки ждут в стеклянной ложе")
check(dani.leaderstats["Монеты"].Value == 0, "у новичка 0 монет")
check(phase() == "Intermission", "4 игрока — пошёл отсчёт до раунда")

section("Кнопка «Хочу водить»")
local volunteerButton = findGui(dani, function(d)
	return d.ClassName == "TextButton" and d.Text == "Хочу водить!"
end)
check(volunteerButton ~= nil, "кнопка «Хочу водить!» видна в лобби")
volunteerButton.Activated:Fire()
Mock.advance(0.3)
check(dani:GetAttribute("Volunteer") == true, "Даня нажал — он в списке желающих")
volunteerButton.Activated:Fire()
Mock.advance(0.3)
check(dani:GetAttribute("Volunteer") == false, "нажал ещё раз — передумал")
fire("Volunteer", bo, true)

-- РАУНД 1 ---------------------------------------------------------------
section("Раунд 1: прятки")
check(Mock.advanceUntil(function()
	return phase() == "Hiding"
end, 25), "после перерыва начались прятки")
check(role(bo) == "Seeker", "водит Bo — единственный желающий")
check(role(ana) == "Hider" and role(cid) == "Hider" and role(dani) == "Hider", "остальные прячутся")
check(pos(bo).Y > 290, "водящий заперт в будке и не подглядывает")
check((pos(ana) - V(0, 3, 0)).Magnitude < 20, "прячущиеся появились в центре поля")
Mock.advance(1)
check(findGui(dani, function(d)
	return d.ClassName == "TextButton" and string.find(d.Text, "Рывок", 1, true) ~= nil
end) ~= nil, "у прячущегося на экране кнопка «Рывок»")

goTo(ana, V(40, 0, -30))
goTo(cid, V(-60, 0, 40))
goTo(dani, V(10, 0, 10))

section("Раунд 1: поиски")
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 50), "через 45 секунд водящего выпустили")
check((pos(bo) - MAP.SeekerReleaseCFrame.Position).Magnitude < 5, "водящий выходит из туннеля")
check(bo.Character.Head:FindFirstChild("Flashlight") ~= nil, "у водящего фонарик")
check(bo.Character.Head:FindFirstChild("SeekerTag") ~= nil, "над водящим надпись ВОДЯЩИЙ")
check(trophy() ~= nil, "Кубок мира спрятан на стадионе")
local trophyPos = trophy().PrimaryPart.Position
print("  Кубок спрятан в точке " .. tostring(trophyPos))

-- Рывок
fire("Dash", ana)
Mock.advance(0.3)
check(hum(ana).WalkSpeed == Config.HIDER_SPEED + Config.DASH_BONUS, "рывок: Ana бежит быстрее (" .. hum(ana).WalkSpeed .. ")")
local readyAt = ana:GetAttribute("DashReadyAt")
fire("Dash", ana)
Mock.advance(0.1)
check(ana:GetAttribute("DashReadyAt") == readyAt, "второй рывок сразу нельзя — ждём 30 секунд")
Mock.advance(Config.DASH_DURATION + 0.3)
check(hum(ana).WalkSpeed == Config.HIDER_SPEED, "рывок закончился, скорость обычная")
fire("Dash", bo)
Mock.advance(0.2)
check(hum(bo).WalkSpeed == Config.SEEKER_SPEED, "водящий рывок не может")

-- Дразнилка
local anaCoins = ana:GetAttribute("Coins") or 0
local tauntsBefore = 0
for name, n in Mock.sfx do
	if string.find(name, "Taunt", 1, true) then
		tauntsBefore += n
	end
end
fire("Taunt", ana)
Mock.advance(0.2)
local tauntsAfter = 0
for name, n in Mock.sfx do
	if string.find(name, "Taunt", 1, true) then
		tauntsAfter += n
	end
end
check(tauntsAfter == tauntsBefore + 1, "дразнилка: у Ana прозвучал смешной звук")
check(ana:GetAttribute("Coins") == anaCoins + Config.COINS.TAUNT, "за дразнилку дали монеты")
fire("Taunt", ana)
Mock.advance(0.2)
check(ana:GetAttribute("Coins") == anaCoins + Config.COINS.TAUNT, "вторую дразнилку сразу нельзя (ждать 20 секунд)")

-- Мяч
teleport(ana, V(40, 0, -30))
teleport(bo, V(55, 0, -30))
fire("Kick", ana, V(1, 0, 0))
Mock.advance(0.5)
check(bo:GetAttribute("Frozen") == true and hum(bo).WalkSpeed == 0, "мяч попал — водящий замер")
check(announced("попал мячом"), "сообщение «попал мячом в водящего»")
local kickReady = ana:GetAttribute("KickReadyAt")
fire("Kick", ana, V(1, 0, 0))
Mock.advance(0.1)
check(ana:GetAttribute("KickReadyAt") == kickReady, "второй мяч сразу нельзя")
fire("Kick", ana, V(0 / 0, 0, 0))
Mock.advance(0.1)
check(#Mock.errors == 0, "мяч с неправильным направлением не ломает сервер")

-- Поимка
goTo(bo, pos(ana))
Mock.advance(1)
check(role(ana) == "Hider", "замёрзший водящий не может поймать")
check(Mock.advanceUntil(function()
	return role(ana) == "Jailed"
end, 6), "водящий отмёрз и поймал Ana")
local jail = MAP.JailCenter
check((pos(ana) - jail).Magnitude < 9, "Ana в тюрьме")
check(announced("поймал Ana"), "сообщение «Водящий поймал Ana»")
Mock.advance(0.3)
check(findGui(dani, function(d)
	return d.ClassName == "TextLabel" and string.find(d.Text, "в тюрьме 1/3", 1, true) ~= nil
end) ~= nil, "на экране «в тюрьме 1/3»")

-- Персонаж Ana пересоздался — снова в тюрьме
Mock.spawnCharacter(ana)
Mock.advance(0.5)
check(role(ana) == "Jailed" and (pos(ana) - jail).Magnitude < 9, "если пойманный перезашёл персонажем, он всё равно в тюрьме")

-- Освобождение
teleport(bo, V(100, 0, 60))
teleport(ana, jail + V(6, 0, 0)) -- Ana подошла к решётке изнутри
teleport(cid, jail + V(20, 0, 0))
goTo(cid, jail + V(8.5, 0, 0)) -- Cid подбегает снаружи
check(Mock.advanceUntil(function()
	return role(ana) == "Hider"
end, 5), "Cid коснулся Ana через решётку — Ana свободна")
check((pos(ana) - V(0, 3, 0)).Magnitude < 20, "освобождённая Ana появилась в центре поля")
check(announced("Cid освободил Ana"), "сообщение «Cid освободил Ana»")
teleport(bo, pos(ana) + V(2, 0, 0))
Mock.advance(0.5)
check(role(ana) == "Hider", "сразу после освобождения Ana нельзя поймать (защита 4 с)")
teleport(bo, V(-160, 0, -180))
teleport(ana, V(60, 0, -60))
teleport(cid, V(-60, 0, -60)) -- Cid уходит от тюрьмы

-- Кубок
teleport(dani, trophyPos + V(10, 0, 0))
goTo(dani, trophyPos)
check(Mock.advanceUntil(function()
	return GameState:GetAttribute("TrophyCarrier") == "Dani"
end, 5), "Даня нашёл Кубок и подобрал его")
check(announced("Dani нашёл Кубок"), "сообщение «Dani нашёл Кубок мира!»")
Mock.advance(0.3)
check(findGui(dani, function(d)
	return d.ClassName == "TextLabel" and string.find(d.Text, "У тебя Кубок", 1, true) ~= nil
end) ~= nil, "у Дани на экране «У тебя Кубок! Беги к воротам!»")
check(role(bo) == "Seeker" and not announced("ГООО"), "пока не забил — гола нет")
fire("Transform", dani)
Mock.advance(0.3)
check(dani:GetAttribute("Prop") == nil, "с Кубком в предмет не превратишься")

-- Пробуем: водящий ловит Даню с Кубком — Кубок падает
teleport(dani, V(20, 0, 20))
goTo(bo, V(20, 0, 20))
teleport(bo, V(24, 0, 20))
check(Mock.advanceUntil(function()
	return role(dani) == "Jailed"
end, 3), "водящий поймал Даню с Кубком")
check(GameState:GetAttribute("TrophyCarrier") == "", "Кубок выпал")
check(announced("Dani уронил Кубок"), "сообщение «Dani уронил Кубок!»")
local dropped = trophy().PrimaryPart.Position
check((V(dropped.X, 0, dropped.Z) - V(20, 0, 20)).Magnitude < 4, "Кубок лежит там, где поймали")

-- Пойманный Даня смотрит за другими
Mock.advance(0.3)
local camera = Mock.workspace.CurrentCamera
local spectateNext = findGui(dani, function(d)
	return d.ClassName == "TextButton" and d.Text == "▶"
end)
check(spectateNext and spectateNext.Parent.Visible, "в тюрьме появились кнопки наблюдения")
spectateNext.Activated:Fire()
Mock.advance(0.3)
local subject = camera.CameraSubject
check(subject and subject.Parent ~= dani.Character and subject.Parent:GetAttribute("Participant"), "Даня смотрит глазами другого игрока (" .. (subject and subject.Parent.Name or "?") .. ")")
check(findGui(dani, function(d)
	return d.ClassName == "TextButton" and string.find(d.Text, "Смотришь:", 1, true) ~= nil
end) ~= nil, "на кнопке написано, за кем смотрит")
teleport(bo, V(-160, 0, -180))

-- Освобождённый игрок подбирает
teleport(cid, dropped + V(5, 0, 0))
goTo(cid, dropped)
check(Mock.advanceUntil(function()
	return GameState:GetAttribute("TrophyCarrier") == "Cid"
end, 4), "Cid подобрал упавший Кубок")
goTo(cid, V((MAP.Goals[1].XMin + MAP.Goals[1].XMax) / 2, 0, 0)) -- в восточные ворота
check(Mock.advanceUntil(function()
	return phase() == "End"
end, 20), "Cid добежал до ворот")
check(announced("ГООООЛ! Cid забил Кубок"), "ГОЛ! Прячущиеся победили")
Mock.advance(0.2)
local C = Config.COINS
check(cid:GetAttribute("Coins") == C.RESCUE + C.PLAY + C.WIN + C.GOAL, "Cid получил монеты: спасение + раунд + победа + гол (" .. tostring(cid:GetAttribute("Coins")) .. ")")
check(dani:GetAttribute("Coins") == C.PLAY + C.WIN, "Даня (из тюрьмы) тоже получил монеты за победу команды")
check(bo:GetAttribute("Coins") == C.CATCH * 2 + C.PLAY, "водящий получил монеты за двух пойманных")
Mock.advance(Config.END_TIME + 0.5)
check(phase() == "Intermission", "новый перерыв перед раундом")
check(role(bo) == "Lobby" and role(dani) == "Lobby", "все снова в лобби")
check(pos(dani).Y > 150 and pos(bo).Y > 150, "все вернулись в ложу")
check(trophy() == nil, "Кубок убран")
check(bo.Character.Head:FindFirstChild("Flashlight") == nil, "фонарик у бывшего водящего забрали")

-- РАУНД 2 ---------------------------------------------------------------
section("Раунд 2: водящий ловит всех")
fire("Volunteer", bo, false)
fire("Volunteer", cid, true)
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 80), "раунд 2 начался")
check(role(cid) == "Seeker", "водит Cid (новый желающий)")
check(cid.Character.Head:FindFirstChild("Crown") ~= nil, "Cid забил гол в прошлом раунде — теперь он в короне")
check(announced("СИИИУ!"), "после гола было празднование «СИИИУ!»")
local victims = { ana, bo, dani }
for i, p in victims do
	teleport(p, V(-80 + i * 40, 0, -40))
end

-- Превращение в предмет
fire("Transform", ana)
Mock.advance(0.3)
check(ana:GetAttribute("Prop") == "Конус", "Ana превратилась в конус")
check(ana.Character:FindFirstChild("Prop") ~= nil and ana.Character.Head.Transparency == 1, "вместо Ana стоит конус, сама она невидима")
fire("Transform", ana)
Mock.advance(0.3)
check(ana:GetAttribute("Prop") == "Конус", "сразу снова нажать нельзя (подождать 3 секунды)")
Mock.advance(Config.TRANSFORM_COOLDOWN)
fire("Transform", ana)
Mock.advance(0.3)
check(ana:GetAttribute("Prop") == nil and ana.Character.Head.Transparency == 0, "Ana снова стала собой")
Mock.advance(Config.TRANSFORM_COOLDOWN)
fire("Transform", ana)
Mock.advance(0.3)
check(ana:GetAttribute("Prop") == "Мяч", "следующее превращение — мяч")

-- Сердцебиение у Дани, когда водящий рядом
local heart = findGui(dani, function(d)
	return d.ClassName == "UIStroke"
end)
check(heart and heart.Transparency == 1, "пока водящий далеко, сердце не стучит")
teleport(cid, pos(dani) + V(20, -3, 0))
check(Mock.advanceUntil(function()
	return heart.Transparency < 1
end, 2), "водящий в 20 шагах — края экрана красные, стучит сердце")
teleport(cid, V(150, 0, 150))
for _, p in victims do
	teleport(cid, pos(p) + V(10, 0, 0))
	goTo(cid, pos(p))
	Mock.advanceUntil(function()
		return role(p) == "Jailed" or phase() ~= "Seeking"
	end, 3)
end
Mock.advance(0.3)
check(announced("Водящий поймал всех"), "водящий поймал всех — победа водящего")
check(ana:GetAttribute("Prop") == nil and ana.Character.Head.Transparency == 0, "предмет Ana пойман — превращение снято")
Mock.advance(0.2)
check(cid:GetAttribute("Coins") == C.RESCUE + C.PLAY + C.WIN + C.GOAL + 3 * C.CATCH + C.PLAY + C.WIN, "водящий получил монеты за победу")

-- РАУНД 3 ---------------------------------------------------------------
section("Раунд 3: статуи и конец времени")
Config.ROUND_TIME = 90
Config.STATUE_WAKE_MIN = 3
Config.STATUE_WAKE_MAX = 4
fire("Volunteer", cid, false)
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 80), "раунд 3 начался")
local seeker
for _, p in all do
	if role(p) == "Seeker" then
		seeker = p
	end
end
check(seeker ~= nil and seeker ~= cid, "без желающих водящий выбран случайно, но не тот, кто водил прошлый раз (" .. (seeker and seeker.Name or "?") .. ")")
teleport(seeker, V(-160, 0, -180))
local hiders = {}
for _, p in all do
	if p ~= seeker then
		table.insert(hiders, p)
	end
end
-- Все прячущиеся стоят возле статуй
local homes = { MAP.StatueHomes[1].Position, MAP.StatueHomes[2].Position, MAP.StatueHomes[3].Position }
for i, p in hiders do
	teleport(p, homes[i] + V(0, 0, -6))
end
check(Mock.advanceUntil(function()
	return announced("Статуи ожили")
end, 10), "статуи ожили")
local awakeStatue
for _, s in stadium.Statues:GetChildren() do
	if s:IsA("Model") and not s.HumanoidRootPart.Anchored then
		awakeStatue = s
	end
end
check(awakeStatue ~= nil, "ожившая статуя может двигаться")
local helped = Mock.advanceUntil(function()
	for _, p in hiders do
		if p:GetAttribute("Boosted") or p:GetAttribute("Frozen") then
			return true
		end
	end
	return false
end, Config.STATUE_AWAKE_TIME)
check(helped, "статуя подбежала и кого-то ускорила (зелёная) или заморозила (красная)")
Config.STATUE_WAKE_MIN = 10000
Config.STATUE_WAKE_MAX = 10001
Mock.advance(Config.STATUE_AWAKE_TIME + 10)
local allAsleep = true
for _, s in stadium.Statues:GetChildren() do
	if s:IsA("Model") and not s.HumanoidRootPart.Anchored then
		allAsleep = false
	end
end
check(allAsleep, "статуи вернулись на место и снова окаменели")
-- В следующем раунде водит кто-то из ботов-людей, но не Даня
for _, p in { ana, bo, cid } do
	if p ~= seeker then
		fire("Volunteer", p, true)
		break
	end
end
check(Mock.advanceUntil(function()
	return phase() == "End"
end, 120), "время раунда кончилось")
check(announced("Время вышло"), "время вышло — водящий победил")
check(announced("Осталась 1 минута"), "за минуту до конца — сообщение и нарезка песни")

-- РАУНД 4 ---------------------------------------------------------------
section("Раунд 4: игроки уходят")
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 80), "раунд 4 начался")
seeker = nil
hiders = {}
for _, p in all do
	if role(p) == "Seeker" then
		seeker = p
	else
		table.insert(hiders, p)
	end
end
teleport(seeker, V(-160, 0, -180))
check(role(dani) == "Hider", "Даня прячется")
local carrier = hiders[1] == dani and hiders[2] or hiders[1]
local tp = trophy().PrimaryPart.Position
teleport(carrier, tp + V(5, 0, 0))
goTo(carrier, tp)
check(Mock.advanceUntil(function()
	return GameState:GetAttribute("TrophyCarrier") == carrier.Name
end, 4), carrier.Name .. " взял Кубок")
goTo(carrier, V(30, 0, 30))
Mock.advance(2)
Mock.removePlayer(carrier)
Mock.advance(0.5)
check(GameState:GetAttribute("TrophyCarrier") == "", "игрок с Кубком вышел — Кубок упал и его можно подобрать")
check(phase() == "Seeking", "раунд продолжается")
Mock.removePlayer(seeker)
check(Mock.advanceUntil(function()
	return phase() == "End"
end, 2), "водящий вышел — раунд закончился")
check(announced("Водящий ушёл"), "прячущиеся победили, потому что водящий ушёл")

-- МАГАЗИН ---------------------------------------------------------------
section("Магазин форм")
local shopButton = findGui(dani, function(d)
	return d.ClassName == "TextButton" and d.Text == "Магазин"
end)
shopButton.Activated:Fire()
Mock.advance(0.2)
-- Добавим Дане монет, чтобы точно хватило на покупку
Mock.require(server.Economy, "server").addCoins(dani, 100)
Mock.advance(0.2)
local coinsBefore = dani:GetAttribute("Coins")
print("  у Дани монет: " .. tostring(coinsBefore))
local buyReal = findGui(dani, function(d)
	return d.ClassName == "TextButton" and d.Text == "Купить: 150"
end)
check(buyReal ~= nil, "в магазине есть форма за 150")
if coinsBefore >= 150 then
	buyReal.Activated:Fire()
	Mock.advance(0.3)
	check(dani:GetAttribute("Coins") == coinsBefore - 150, "купил форму «Красные звёзды» за 150 монет")
	check(dani:GetAttribute("EquippedKit") == "Stars", "форма «Красные звёзды» надета")
	local colors = dani.Character:FindFirstChildOfClass("BodyColors")
	check(colors.TorsoColor3 == Config.getKit("Stars").Shirt, "пока рисунок не загружен, форма показывается цветом")
	check(dani.Character:FindFirstChildOfClass("Shirt") == nil, "старая футболка снята")
else
	check(false, "у Дани не хватает монет для проверки покупки")
end
local lions = Config.getKit("Lions")
lions.ShirtTemplate, lions.PantsTemplate = 111, 222
fire("EquipKit", dani, "Lions")
Mock.advance(0.2)
local shirt = dani.Character:FindFirstChildOfClass("Shirt")
local pants = dani.Character:FindFirstChildOfClass("Pants")
check(shirt and shirt.ShirtTemplate == "rbxassetid://111" and pants and pants.PantsTemplate == "rbxassetid://222", "форма «Зелёные львы» надевается с рисунком футболки и шорт")
check(dani.Character:FindFirstChildOfClass("BodyColors").TorsoColor3 ~= Config.getKit("Stars").Shirt, "под формой с рисунком вернулся обычный цвет персонажа")
fire("EquipKit", dani, "Stars")
Mock.advance(0.2)
check(dani.Character:FindFirstChildOfClass("Shirt") == nil, "обратно на «Красные звёзды»: рисунок снят, форма цветом")
local coinsNow = dani:GetAttribute("Coins")
fire("BuyKit", dani, "GoldKit")
Mock.advance(0.2)
check(dani:GetAttribute("Coins") == coinsNow and dani:GetAttribute("EquippedKit") == "Stars", "золотую форму за 1000 купить нельзя — не хватает монет")
fire("EquipKit", dani, "Brazil")
Mock.advance(0.2)
check(dani:GetAttribute("EquippedKit") == "Stars", "некупленную форму надеть нельзя")
fire("EquipKit", dani, "Lions")
Mock.advance(0.2)
check(dani:GetAttribute("EquippedKit") == "Lions", "можно снова надеть бесплатную форму «Зелёные львы»")
fire("BuyKit", dani, { hack = true })
fire("EquipKit", dani, 12345)
Mock.advance(0.2)
check(#Mock.errors == 0, "странные запросы в магазин не ломают сервер")

section("Сохранение монет")
local savedCoins = dani:GetAttribute("Coins")
local userId = dani.UserId
Mock.removePlayer(dani)
Mock.advance(0.5)
local dani2 = Mock.addPlayer("Dani", userId)
Mock.advance(0.5)
check(dani2:GetAttribute("Coins") == savedCoins, "Даня вышел и зашёл — монеты сохранились (" .. tostring(savedCoins) .. ")")
check(string.find(dani2:GetAttribute("OwnedKits"), "Stars", 1, true) ~= nil, "купленная форма тоже сохранилась")

-- БОТЫ ----------------------------------------------------------------
section("Боты: играем одни")
Config.ROUND_TIME = 600
for _, p in Players:GetPlayers() do
	if p ~= dani2 then
		Mock.removePlayer(p)
	end
end
dani = dani2
Mock.spawnCharacter(dani)
Mock.localPlayer = dani
Players.LocalPlayer = dani
Mock.runScript(playerScripts.Main, "client")
Mock.advance(1)
check(#Players:GetPlayers() == 1, "на сервере остался один Даня")
Mock.advance(Config.INTERMISSION_TIME + 2)
check(phase() == "Waiting", "без ботов один игрок ждёт")
local botsButton = findGui(dani, function(d)
	return d.ClassName == "TextButton" and d.Text == "Боты: ВЫКЛ"
end)
check(botsButton ~= nil, "в лобби есть кнопка «Боты: ВЫКЛ»")
botsButton.Activated:Fire()
Mock.advance(1.5)
check(GameState:GetAttribute("BotsEnabled") == true and botsButton.Text == "Боты: ВКЛ", "нажал — боты включены")
local levelButton = findGui(dani, function(d)
	return d.ClassName == "TextButton" and d.Text == "Боты: Глупые"
end)
check(levelButton ~= nil, "есть кнопка «Боты: Глупые»")
levelButton.Activated:Fire()
Mock.advance(0.5)
check(GameState:GetAttribute("BotLevel") == "normal" and levelButton.Text == "Боты: Умные", "переключил на умных — дальше проверяем умных ботов")
fire("Volunteer", dani, true)
check(Mock.advanceUntil(function()
	return phase() == "Hiding"
end, Config.INTERMISSION_TIME + 3), "раунд начался с одним человеком")

local function botCharacters()
	local list = {}
	for _, m in Mock.workspace:GetChildren() do
		if m:IsA("Model") and string.find(m.Name, "Бот", 1, true) then
			table.insert(list, m)
		end
	end
	return list
end
local bots = botCharacters()
check(#bots == Config.BOT_FILL_TO - 1, "добавлено ботов: " .. #bots .. " (всего участников " .. Config.BOT_FILL_TO .. ")")
check(announced("В игру добавлены боты"), "сообщение «В игру добавлены боты»")
check(role(dani) == "Seeker", "Даня водит (он хотел)")
local startPositions = {}
for i, m in bots do
	startPositions[i] = m.HumanoidRootPart.Position
end
Mock.advance(20)
local movedCount = 0
for i, m in bots do
	if (m.HumanoidRootPart.Position - startPositions[i]).Magnitude > 10 then
		movedCount += 1
	end
end
check(movedCount >= #bots - 1, "боты разбежались прятаться (" .. movedCount .. " из " .. #bots .. ")")
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 30), "поиски начались")

-- Даня ловит одного бота
local target = bots[1]
teleport(dani, target.HumanoidRootPart.Position + V(8, -3, 0))
local caught = Mock.advanceUntil(function()
	if phase() ~= "Seeking" or not target.Parent then
		return false
	end
	goTo(dani, target.HumanoidRootPart.Position - V(0, 3, 0))
	return GameState:GetAttribute("HidersJailed") >= 1
end, 30)
check(caught, "Даня догнал и поймал бота")
check(announced("поймал Бот"), "сообщение «Водящий поймал Бот ...»")

-- Пойманный бот подходит к решётке
check(Mock.advanceUntil(function()
	for _, m in botCharacters() do
		local p = m.HumanoidRootPart.Position
		if (p - (MAP.JailCenter + V(0, 3, 0))).Magnitude < 9 and p.X > MAP.JailCenter.X + 3 then
			return true
		end
	end
	return false
end, 8), "пойманный бот подошёл к решётке, чтобы его освободили")

-- Даня уходит далеко — боты-спасатели освобождают друга, а бот с Кубком бежит к воротам
teleport(dani, V(150, 0, 150))
local since = Mock.time()
local rescued = Mock.advanceUntil(function()
	return announced("освободил", since - 10) or phase() ~= "Seeking"
end, 120)
check(rescued, "бот прибежал к тюрьме и освободил друга")
local scored = Mock.advanceUntil(function()
	return phase() ~= "Seeking"
end, 400)
check(scored and announced("забил Кубок", since), "боты нашли Кубок и забили его в ворота")
print(string.format("  раунд с ботами длился %.0f с", Mock.time() - since))
Mock.advance(Config.END_TIME + 1)
check(#botCharacters() == 0, "после раунда боты ушли")
check(role(dani) == "Lobby", "Даня вернулся в лобби")

section("Боты: бот водит")
fire("Volunteer", dani, false)
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 90), "раунд с ботами начался снова")
check(role(dani) == "Hider", "водит бот, Даня прячется")
local botSeeker
for _, m in botCharacters() do
	if m.Head:FindFirstChild("Flashlight") then
		botSeeker = m
	end
end
check(botSeeker ~= nil, "у бота-водящего фонарик")
teleport(dani, botSeeker.HumanoidRootPart.Position + V(35, -3, 0))
check(Mock.advanceUntil(function()
	return role(dani) == "Jailed"
end, 90), "бот-водящий заметил Даню, догнал и поймал")
check(Mock.advanceUntil(function()
	return phase() == "End"
end, Config.ROUND_TIME + 10), "раунд с ботом-водящим закончился")
Mock.advance(Config.END_TIME + 1)

section("Боты: максимально глупые")
fire("BotLevel", dani, "dumb")
fire("Volunteer", dani, false)
local talked, botProp = false, false
local speechConn = Mock.services.RunService.Heartbeat:Connect(function()
	for _, m in botCharacters() do
		if m.Head and m.Head:FindFirstChild("Speech") then
			talked = true
		end
		if m:FindFirstChild("Prop") then
			botProp = true
		end
	end
end)
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 90), "раунд с глупыми ботами начался")
local dumbSeeker
for _, m in botCharacters() do
	if m.Head:FindFirstChild("Flashlight") then
		dumbSeeker = m
	end
end
Mock.advance(1)
if role(dani) == "Seeker" then
	-- Водящего выбрал случай, и это Даня — тогда проверяем глупых прячущихся
	local someBot = botCharacters()[1]
	check(someBot and someBot.Humanoid.WalkSpeed == Config.HIDER_SPEED + Config.BOT_LEVELS.dumb.HiderSpeedBonus, "водит Даня; глупые боты-прячущиеся медленные (" .. tostring(someBot and someBot.Humanoid.WalkSpeed) .. ")")
else
	check(dumbSeeker and dumbSeeker.Humanoid.WalkSpeed == Config.SEEKER_SPEED + Config.BOT_LEVELS.dumb.SeekerSpeedBonus, "глупый бот-водящий медленный (" .. tostring(dumbSeeker and dumbSeeker.Humanoid.WalkSpeed) .. ")")
end
-- Даня стоит на виду; глупый водящий, даже если увидит, быстро сдаётся
teleport(dani, V(0, 0, -50))
Mock.advance(60)
check(talked, "глупые боты болтают (над головой появляются фразы)")
check(botProp, "боты тоже превращаются в предметы")
local hidersBefore = GameState:GetAttribute("HidersFree") or 0
print("  через минуту свободно прячущихся: " .. hidersBefore .. ", в тюрьме: " .. tostring(GameState:GetAttribute("HidersJailed")))
local openField = 0
for _, m in botCharacters() do
	local p = m.HumanoidRootPart.Position
	if math.abs(p.X) < 95 and math.abs(p.Z) < 60 then
		openField += 1
	end
end
print("  ботов посреди поля: " .. openField)
check(Mock.advanceUntil(function()
	return phase() == "End"
end, Config.ROUND_TIME + 10), "раунд с глупыми ботами закончился")
speechConn:Disconnect()
Mock.advance(Config.END_TIME + 1)
fire("BotLevel", dani, "normal")

section("Боты: человек ушёл")
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 90), "ещё один раунд")
Mock.removePlayer(dani)
check(Mock.advanceUntil(function()
	return phase() == "End"
end, 2), "последний человек ушёл — раунд закончился")
check(announced("Все игроки ушли"), "сообщение «Все игроки ушли»")
Mock.advance(Config.END_TIME + 1)
check(#botCharacters() == 0, "боты убраны")
Mock.advance(5)
check(phase() == "Waiting", "сервер ждёт новых игроков")

section("Звуки")
for _, name in { "Whistle", "Catch", "Rescue", "Trophy", "Goal", "Kick", "Dash", "Transform", "Statue" } do
	check((Mock.sfx[name] or 0) > 0, "звучит «" .. name .. "» (" .. tostring(Mock.sfx[name] or 0) .. " раз)")
end
check(Mock.emitted > 0, "на гол — салют из конфетти")
for _, name in { "GoalSong", "HidersWinSong", "SeekerWinSong", "LastMinuteSong", "TrophySong" } do
	check((Mock.sfx[name] or 0) > 0, "нарезка «" .. name .. "» запускается в нужный момент")
end

section("Нарезка песни")
local clientConfig = Mock.require(shared.Config, "client")
clientConfig.SOUNDS.GoalSong = { Id = "rbxassetid://1", Volume = 0.8, Start = 42, Length = 8 }
local listener = Mock.addPlayer("Lena")
Mock.spawnCharacter(listener)
Mock.localPlayer = listener
Players.LocalPlayer = listener
Mock.runScript(playerScripts.Main, "client")
Mock.advance(0.5)
Remotes.Sfx.OnClientEvent:Fire("GoalSong", nil)
Mock.advance(0.2)
local song = findGui(listener, function(d)
	return d.ClassName == "Sound" and d.SoundId == "rbxassetid://1"
end)
check(song and song.TimePosition == 42 and song.IsPlaying, "нарезка играет с 42-й секунды трека")
Mock.advance(6)
check(song.IsPlaying, "через 6 секунд ещё играет")
Mock.advance(2.5)
check(not song.IsPlaying, "через 8 секунд нарезка закончилась")
Mock.removePlayer(listener)

section("Приколы")
fire("BotLevel", nil, "dumb")
local mira = Mock.addPlayer("Mira")
Mock.spawnCharacter(mira)
Mock.localPlayer = mira
Players.LocalPlayer = mira
Mock.runScript(playerScripts.Main, "client")
Mock.advance(1)
check(mira:GetAttribute("IsAdmin") == true, "в Studio админ-панель есть (в игре — только у Дани)")
local adminButton = findGui(mira, function(d)
	return d.ClassName == "TextButton" and d.Text == "👑 Админ"
end)
check(adminButton and adminButton.Visible, "на экране кнопка «👑 Админ»")
local Fun = Mock.require(server.Fun, "server")
local ParticipantsModule = Mock.require(server.Participants, "server")
local AbilitiesModule = Mock.require(server.Abilities, "server")
check(Mock.advanceUntil(function()
	return phase() == "Seeking"
end, 90), "раунд с приколами начался")

local function anyBotHead()
	for _, b in ParticipantsModule.bots() do
		if b.Character and b.Character:FindFirstChild("Head") then
			return b.Character.Head
		end
	end
	return nil
end
local head = anyBotHead()
local normalSize = head.Size.X
fire("Admin", mira, "bighead")
Mock.advance(0.3)
check(head.Size.X > normalSize * 2, "админ: у всех огромные головы")
Mock.advance(Config.EVENT_TIME + 1)
check(math.abs(head.Size.X - normalSize) < 0.01, "через 25 секунд головы обычные")

fire("Admin", mira, "tiny")
Mock.advance(0.3)
local anyBot = ParticipantsModule.bots()[1]
check(anyBot.Character:GetAttribute("Scale") == nil and Mock.data[anyBot.Character].props.Scale == 0.5, "админ: все стали маленькими")

fire("Admin", mira, "moon")
Mock.advance(0.3)
check(mira:GetAttribute("MoonMode") == true and Mock.workspace.Gravity == 25, "админ: у Миры лунная гравитация — прыгает как в космосе")

local lightsBefore = {}
for _, d in stadium:GetDescendants() do
	if d.ClassName == "SpotLight" then
		lightsBefore[d] = d.Color
	end
end
fire("Admin", mira, "disco")
Mock.advance(1)
local changed = 0
for light, color in lightsBefore do
	if light.Color ~= color then
		changed += 1
	end
end
check(changed > 10, "админ: дискотека — прожекторы меняют цвет (" .. changed .. ")")
Mock.advance(21)
local restored = true
for light, color in lightsBefore do
	if light.Color ~= color then
		restored = false
	end
end
check(restored, "после дискотеки свет снова обычный")

fire("Admin", mira, "ballrain")
Mock.advance(0.3)
local balls = 0
for _, d in Mock.workspace:GetChildren() do
	if d.ClassName == "Part" and d.Shape and d.Shape.Name == "Ball" and d.Size.X == 2 then
		balls += 1
	end
end
check(balls >= 30, "админ: с неба падают мячи (" .. balls .. ")")

fire("Admin", mira, "giantball")
Mock.advance(0.3)
local giant = Mock.workspace:FindFirstChild("GiantBall")
check(giant ~= nil, "админ: по полю катится огромный мяч")
local giantStart = giant and giant.Position
Mock.advance(1)
check(giant and giant.Parent and (giant.Position - giantStart).Magnitude > 20, "огромный мяч катится")

fire("Admin", mira, "statues")
Mock.advance(0.5)
local awake = 0
for _, st in stadium.Statues:GetChildren() do
	if st:IsA("Model") and not st.HumanoidRootPart.Anchored then
		awake += 1
	end
end
check(awake == 8, "админ: ожили сразу все 8 статуй")

local emittedBefore = Mock.emitted
fire("Admin", mira, "fireworks")
Mock.advance(0.2)
check(Mock.emitted > emittedBefore, "админ: салют")

fire("Admin", bo, "disco")
Mock.advance(0.2)
check(#Mock.errors == 0, "команды админа без ошибок")

-- Лев утаскивает Кубок
local since = Mock.time()
fire("Admin", mira, "lion")
Mock.advance(0.3)
local lionModel = Mock.workspace:FindFirstChild("Lion")
check(lionModel ~= nil, "админ: на поле выбежал лев")
check(Mock.advanceUntil(function()
	return announced("Лев утащил Кубок", since) or phase() ~= "Seeking"
end, 40), "лев добежал до Кубка и утащил его")

-- Банан
local seekerP
for _, p in Participants() do
	if role(p) == "Seeker" then
		seekerP = p
	end
end
local hiderBot
Mock.advanceUntil(function()
	for _, bot in ParticipantsModule.bots() do
		if role(bot) == "Hider" and not bot:GetAttribute("Frozen") then
			hiderBot = bot
			return true
		end
	end
	return false
end, 10)
if phase() == "Seeking" and seekerP and hiderBot then
	local since2 = Mock.time()
	hiderBot:SetAttribute("BananaReadyAt", 0)
	local okBanana = AbilitiesModule.tryBanana(hiderBot)
	local bananaModel = Mock.workspace:FindFirstChild("Banana")
	check(okBanana and bananaModel ~= nil, "прячущийся бросил банановую кожуру")
	local bananaPos = if bananaModel then bananaModel:GetPivot().Position else pos(hiderBot)
	seekerP.Character:PivotTo(Mock.CFrame.new(bananaPos + V(0, 3, 0)))
	check(Mock.advanceUntil(function()
		return announced("поскользнулся", since2)
	end, 2), "водящий наступил на банан и поскользнулся")
	Mock.advance(0.2)
	check(seekerP:GetAttribute("Frozen") == true, "поскользнувшийся водящий замер")
else
	check(false, "раунд закончился раньше проверки банана")
end

check(Mock.comments and #Mock.comments > 10, "комментатор шутит (" .. tostring(Mock.comments and #Mock.comments) .. " реплик)")
if Mock.comments then
	for i = 1, math.min(4, #Mock.comments) do
		print("  🎙 " .. Mock.comments[i])
	end
end

-- Секретная комната
local hatch = stadium.SecretRoom.Hatch
hatch.ProximityPrompt.Triggered:Fire(mira)
Mock.advance(0.3)
check(pos(mira).Y < -70, "Мира залезла в люк и попала в секретную комнату")
local coins = mira:GetAttribute("Coins")
stadium.SecretRoom.Chest.ProximityPrompt.Triggered:Fire(mira)
Mock.advance(0.3)
check(mira:GetAttribute("Coins") == coins + Config.SECRET_REWARD, "секретный сундук: +" .. Config.SECRET_REWARD .. " монет")
stadium.SecretRoom.Chest.ProximityPrompt.Triggered:Fire(mira)
Mock.advance(0.3)
check(mira:GetAttribute("Coins") == coins + Config.SECRET_REWARD, "второй раз за день сундук пустой")
stadium.SecretRoom.Exit.ProximityPrompt.Triggered:Fire(mira)
Mock.advance(0.3)
check(pos(mira).Y > 0, "Мира вышла обратно на стадион")

section("Итог")
for _, e in Mock.errors do
	print("  ОШИБКА: " .. tostring(e))
end
for _, w in Mock.warnings do
	print("  предупреждение: " .. tostring(w))
end
check(#Mock.errors == 0, "за весь плейтест не было ни одной ошибки в скриптах")
print(string.format("\nПройдено: %d, провалено: %d", passed, failed))
return failed
