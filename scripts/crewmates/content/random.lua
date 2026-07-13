local fmt = require "format"
local lang = require "language.language"
local contract = require "crewmates.module_contract"

function getSpaceThing()
	-- just a bunch of things that you could find out in space
	return pick_one(lang.nouns.objects.space)
end

-- gets a random ship or possibly an alternative
function getRandomShip()
	local ships = ship.getAll()

	-- minor sanitation
	local candidate = string.gsub(string.gsub(pick_one(ships):name(), "Drone \\(", ""), "\\)", "")

	-- don't allow thurion or proteron ships or outposts
	if string.find(candidate, "Thuri") or string.find(candidate, "Proter") or string.find(candidate, "Outpost") then
		-- give it some interesting choices along with some standard ones
		candidate = getSpaceThing()
	end

	return candidate
end

-- gets a random outfit
function getRandomOutfit()
	local outfits = outfit.getAll()
	return pick_one(outfits):name()
end

-- TODO: if we have facilities on this ship, list those
-- generates a shipboard activity, loosely based on the ship that's being flown
function getShipboardActivity( activity_type )
	local activities = {}
	-- basic activities: "I'm going to go <do/for [some]> <activity>"
	activities.basic = {
		_("exercise"),
		_("maintenance"),
		_("sanitation"),
		_("inspection"),
		_("thing"),
		_("hydration"),
		_("research"),
		_("science"),
		_("inventory"),
		_("project"),
		_("assignment"),
		fmt.f(_("{fruit} restocking"), { fruit = lang.getRandomFruit() } ),
		fmt.f(_("{fruit} tallying"), { fruit = lang.getRandomFruit() } ),
	}
	-- anyone wanna play some <game>?
	activities.game = join_tables(lang.nouns.activities.games, {
		lang.getMadeUpName(),
		_("squash")
	})
	if player.pilot():ship():size()  > 4 then
	-- these are "places to go" on the cruiser or larger where you go to do some cool activity
		activities.cruiser = lang.nouns.facilities.cruiser
	end
	if not activity_type then
		activity_type = pick_key(activities)
	elseif not activities[activity_type] then
		activity_type = "basic"
	end
	local choices = activities[activity_type]
	return pick_one(choices)
end

-- generate some random things, then picks one out of the hat or
-- (rarely) the name of the category it is from (could be funny)
function getRandomThing()
	local things = {
		["ship"] = getRandomShip(),
		-- TODO: generate these...
		["item"] = pick_one(
			{
				"leather jacket",
				"vintage coat",
				"elegant design", -- okay, not really an item... but still
				"abstract holosculpture",
				"virtual death simulator",
				"synthetic snakeskin applicator",
				"high-quality lip stick",
				"white elephant",
				"red herring",
				"classic video game",
				"optical combustion device",
				"synthetic aquarium",
				"animal figurine",
				"paper plane",
				"telepathically controlled camera drone",
				"baseball bat",
				"baseball hat",
				"basketball",
				"wicker basket",
				"trojan",
				"sock puppet",
				"social network simulator",
				"vintage hand egg",
				"fictional literature",
				"device",
				"gadget",
				"hand-held",
				"portable",
				"Ultra 3000",
				"Neo 7000",
				"0K Elite Edition cup chiller",
				"wholesome book",
				"digital archive",
				"toy",
				"puppet",
				"sock"
			}
		),
		["anything"] = pick_one(lang.getAll(lang.nouns)),
		["outfit"] = getRandomOutfit(),
		["thingymabob"] = pick_one(lang.getMadeUpName()),
		["spacething"] = getSpaceThing(),
		["fruit"] = lang.getRandomFruit(),
		["whatever"] = pick_one(lang.getMadeUpName()),
	}
	for key, thing in pairs(things) do
		if rnd.rnd() < 0.22 then
			return thing
		end
		-- interesting alternatives to orthotox flow
		if rnd.rnd() > 0.967 then
			return key
		end
	end

	return "thing"
end

-- generates a generic bar action like "thinking about a drink" or "ready to get back to some food"
function getBarSituation(character_sheet)
	local bar_actions = {
		{
			["verb"] = pick_one(
				{
					_("swirling"),
					_("sipping"),
					_("drinking"),
					_("enjoying"),
					_("nursing"),
					_("nursing on")
				}
			),
			["descriptor"] = pick_one(
				{
					_("a"),
					_("a"),
					_("some"),
					_("some kind of")
				}
			),
			["adjective"] = pick_one(
				{
					_("nice"),
					_("strange"),
					_("hot"),
					_("cold"),
					_("chilled"),
					_("colourful"),
					_("warm")
				}
			),
			["object"] = pick_one(
				{
					_("drink"),
					_("wine"),
					_("tea"),
					_("concoction"),
					_("elixir"),
					_("mixture of fluids"),
					_("beverage")
				}
			)
		},
		{
			["verb"] = pick_one(
				{
					_("thinking"),
					_("pondering"),
					_("wondering"),
					_("having feelings")
				}
			),
			["descriptor"] = pick_one(
				{
					_("about some"),
					_("about a"),
					_("about that")
				}
			),
			["adjective"] = pick_one(
				{
					_("nice"),
					_("strange"),
					_("shady"),
					_("cold"),
					_("eerie"),
					_("colourful"),
					_("distracting")
				}
			),
			["object"] = pick_one(
				{
					_("drink"),
					_("person"),
					_("sculpture"),
					_("plant"),
					_("piece of machinery"),
					_("bartender"),
					_("smell")
				}
			)
		},
		{
			["verb"] = pick_one(
				{
					_("looking"),
					_("peering"),
					_("squinting"),
					_("eyeing")
				}
			),
			["descriptor"] = pick_one(
				{
					_("at"),
					_("towards"),
					_("in the direction of"),
					_("vaguely towards")
				}
			),
			["adjective"] = pick_one(
				{
					_("some"),
					_("a"),
					_("a mysterious"),
					_("an unsuspicious"),
					_("a suspicious looking"),
					_("an anonymous"),
					_("another")
				}
			),
			["object"] = pick_one(
				{
					_("drink"),
					_("patron"),
					_("person"),
					_("corner"),
					_("stranger"),
					_("crowd"),
					_("group")
				}
			)
		},
		{
			-- an irregular one that adds anxiety to the crew
			["verb"] = pick_one(
				{
					_("anxious"),
					_("desperate"),
					_("poised"),
					_("ready")
				}
			),
			["descriptor"] = _("to"),
			["adjective"] = pick_one(
				{
					_("get back to"),
					_("return to"),
					_("retreat to"),
					_("abscond with")
				}
			),
			["object"] = pick_one(
				{
					_("the ship"),
					_("a drink"),
					fmt.f(_("the {ship}"), {ship = player.pilot():name()}),
					_("some food")
				}
			)
		}
	}
	if character_sheet and character_sheet.conversation and character_sheet.conversation.bar_actions then
		bar_actions = join_tables(bar_actions, character_sheet.conversation.bar_actions)
	end
	
	local chosen_action = pick_one(bar_actions)
	local doing = fmt.f(_("{verb} {descriptor} {adjective} {object}"), chosen_action)
	return doing
end

return contract.capture {
	name = "content.random",
	requires = { "context" },
	exports = {
		"getSpaceThing", "getRandomShip", "getRandomOutfit",
		"getShipboardActivity", "getRandomThing", "getBarSituation",
	},
}
