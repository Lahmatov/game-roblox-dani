-- Все настройки игры в одном месте. Меняй числа здесь, чтобы настроить игру.

local Config = {}

-- Игроки
Config.MIN_PLAYERS = 2 -- сколько нужно игроков, чтобы начать раунд
Config.MAX_HIDERS = 22 -- больше прячущихся не бывает (остальные смотрят из ложи)

-- Боты: добавляются, если настоящих игроков мало. Включаются кнопкой в лобби.
Config.BOTS_ENABLED = true -- включены ли боты, когда сервер запускается
Config.BOT_FILL_TO = 10 -- сколько всего участников в раунде вместе с ботами

-- Насколько боты умные. Переключается кнопкой в лобби.
--   dumb   — максимально глупые: путаются, стоят на виду, болтают, отвлекаются
--   normal — обычные: прячутся, убегают, ищут Кубок
Config.BOT_LEVEL = "dumb"
Config.BOT_LEVELS = {
	dumb = {
		Name = "Глупые",
		HiderSpeedBonus = -4, -- боты-прячущиеся медленнее людей
		SeekerSpeedBonus = -4, -- бот-водящий медленнее людей
		ThinkInterval = 0.8, -- как часто бот думает (секунды) — глупые думают медленно
		Sight = 30, -- как далеко бот-водящий замечает прячущихся
		GiveUpChase = 5, -- через сколько секунд погони бот-водящий сдаётся
		FleeDistance = 18, -- на каком расстоянии бот замечает водящего
		FleeChance = 0.4, -- шанс, что бот вообще догадается убежать
		WrongWayChance = 0.4, -- шанс убежать не туда (прямо к водящему)
		DashChance = 0.15,
		KickChance = 0.03, -- и пинает мяч куда попало
		OpenHideChance = 0.5, -- шанс «спрятаться» прямо посреди поля
		DistractChance = 0.06, -- шанс отвлечься и пойти куда-то не туда
		TalkChance = 0.04, -- шанс сказать глупость
		SearchDelayMin = 90, -- когда начинают искать Кубок
		SearchDelayMax = 240,
		TrophySight = 8, -- замечают Кубок, только если почти наступили на него
		NoticeDelay = 30,
	},
	normal = {
		Name = "Умные",
		HiderSpeedBonus = -2,
		SeekerSpeedBonus = 0,
		ThinkInterval = 0.25,
		Sight = 70,
		GiveUpChase = 30,
		FleeDistance = 28,
		FleeChance = 1,
		WrongWayChance = 0,
		DashChance = 1,
		KickChance = 0.08,
		OpenHideChance = 0,
		DistractChance = 0,
		TalkChance = 0.01,
		SearchDelayMin = 45,
		SearchDelayMax = 150,
		TrophySight = 15,
		NoticeDelay = 20,
	},
}

function Config.bot()
	return Config.BOT_LEVELS[Config.BOT_LEVEL] or Config.BOT_LEVELS.dumb
end

Config.TROPHY_MIN_DISTANCE = 35 -- Кубок прячется не ближе этого к любому игроку

-- Время (в секундах)
Config.INTERMISSION_TIME = 20 -- перерыв перед раундом
Config.HIDE_TIME = 45 -- сколько времени даётся, чтобы спрятаться
Config.ROUND_TIME = 15 * 60 -- сколько длятся поиски
Config.END_TIME = 8 -- сколько показываем, кто победил

-- Скорость
Config.HIDER_SPEED = 16
Config.SEEKER_SPEED = 18
Config.JUMP_HEIGHT = 7.2

-- Поимка и тюрьма
Config.CATCH_DISTANCE = 5 -- насколько близко водящий должен подойти, чтобы поймать
Config.RESCUE_DISTANCE = 6 -- насколько близко надо подойти к другу в тюрьме, чтобы освободить
Config.RESCUE_IMMUNITY = 4 -- сколько секунд освобождённого нельзя поймать

-- Ускорение (рывок)
Config.DASH_COOLDOWN = 30
Config.DASH_DURATION = 2.5
Config.DASH_BONUS = 16

-- Мяч
Config.KICK_COOLDOWN = 8
Config.KICK_FREEZE = 2 -- на сколько секунд замирает водящий
Config.KICK_BALL_SPEED = 90
Config.KICK_BALL_LIFETIME = 3

-- Кубок
Config.TROPHY_PICKUP_DISTANCE = 4.5
Config.TROPHY_HINT_INTERVAL = 60
Config.TROPHY_HINT_DURATION = 6

-- Статуи
Config.STATUE_WAKE_MIN = 25
Config.STATUE_WAKE_MAX = 50
Config.STATUE_AWAKE_TIME = 12
Config.STATUE_SPEED = 14
Config.STATUE_TOUCH_DISTANCE = 4.5
Config.STATUE_FREEZE = 2
Config.STATUE_BOOST_TIME = 5
Config.STATUE_BOOST_BONUS = 10

-- Монеты
Config.COINS = {
	PLAY = 5, -- за участие в раунде
	WIN = 50, -- за победу
	GOAL = 100, -- кто забил Кубок в ворота
	CATCH = 10, -- водящему за каждого пойманного
	RESCUE = 15, -- за освобождение друга
}

-- Футбольные формы в магазине.
-- Формы с рисунком (Template) — по дизайну Дани. Картинки лежат в assets/kits/.
-- Загрузи <kit>_shirt.png и <kit>_pants.png в Roblox (Creator Hub -> Decals) и впиши номера
-- картинок в ShirtTemplate и PantsTemplate. Пока там 0, форма показывается просто цветом.
Config.KITS = {
	{ Id = "Lions", Name = "Зелёные львы", Price = 0, Shirt = Color3.fromRGB(11, 138, 69), Shorts = Color3.fromRGB(255, 255, 255), ShirtTemplate = 0, PantsTemplate = 0 },
	{ Id = "Stars", Name = "Красные звёзды", Price = 150, Shirt = Color3.fromRGB(211, 34, 34), Shorts = Color3.fromRGB(181, 27, 27), ShirtTemplate = 0, PantsTemplate = 0 },
	{ Id = "Night", Name = "Ночная молния", Price = 300, Shirt = Color3.fromRGB(28, 28, 34), Shorts = Color3.fromRGB(28, 28, 34), ShirtTemplate = 0, PantsTemplate = 0 },
	{ Id = "GoldKit", Name = "Золотая с короной", Price = 1000, Shirt = Color3.fromRGB(245, 191, 42), Shorts = Color3.fromRGB(234, 178, 32), ShirtTemplate = 0, PantsTemplate = 0 },
	{ Id = "Sporting", Name = "Спортинг", Price = 0, Shirt = Color3.fromRGB(0, 128, 72), Shorts = Color3.fromRGB(255, 255, 255) },
	{ Id = "Real", Name = "Реал", Price = 150, Shirt = Color3.fromRGB(245, 245, 245), Shorts = Color3.fromRGB(245, 245, 245) },
	{ Id = "Barca", Name = "Барса", Price = 150, Shirt = Color3.fromRGB(165, 0, 68), Shorts = Color3.fromRGB(0, 77, 152) },
	{ Id = "Portugal", Name = "Португалия", Price = 200, Shirt = Color3.fromRGB(200, 16, 46), Shorts = Color3.fromRGB(0, 102, 51) },
	{ Id = "Brazil", Name = "Бразилия", Price = 200, Shirt = Color3.fromRGB(255, 220, 0), Shorts = Color3.fromRGB(0, 56, 168) },
	{ Id = "Argentina", Name = "Аргентина", Price = 200, Shirt = Color3.fromRGB(117, 170, 219), Shorts = Color3.fromRGB(20, 20, 20) },
}
Config.DEFAULT_KIT = "Lions"

-- Статуя сына на стадионе: впиши его номер в Roblox (UserId), и статуя будет в виде его аватара.
-- Номер видно в адресе страницы профиля: roblox.com/users/<НОМЕР>/profile
Config.HERO_USER_ID = 0
Config.HERO_TITLE = "ДАНЯ — легенда стадиона"

function Config.getKit(id: string)
	for _, kit in Config.KITS do
		if kit.Id == id then
			return kit
		end
	end
	return nil
end

return Config
