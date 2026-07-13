local fmt = require "format"
local vntk = require "vntk"
local joyride = require "joyride"
local contract = require "crewmates.module_contract"

local CLIENT_ID = "TXCrewmates"

local function returned_shuttle_manager()
	return FAKE_CAPTAIN.shuttle_manager
end

function joyride_mothership_spawned(payload)
	if not payload or payload.client ~= CLIENT_ID or not mem.crewmates_joyride then
		return
	end
	local commander = joyride_commander
	if not commander then
		return
	end
	commander.pilot = payload.pilot
	hook.pilot(commander.pilot, "hail", "startCommandDiscussion")
end

function joyride_ended(payload)
	if not payload or payload.client ~= CLIENT_ID or not mem.crewmates_joyride then
		return
	end

	local manager = returned_shuttle_manager()
	if manager and manager.manager and payload.outfits then
		manager.manager.outfits = payload.outfits
	end
	if manager and manager.shuttle then
		manager.shuttle.out = nil
	end
	if mem.ship_interior.shuttle then
		mem.ship_interior.shuttle.out = nil
	end

	local commander = joyride_commander
	if commander then
		commander.pilot = nil
	end
	joyride_commander = nil
	mem.crewmates_joyride = nil
	FAKE_CAPTAIN.shuttle_manager = nil
	if commander then
		commander_button(commander)
	end
end

function player_swaps_to_shuttle(args)
	if not naev.claimTest(system.cur()) then
		vntk.msg(
			_("Undocking error"),
			_("Electromagnetic interference makes it unsafe to launch the officer's shuttle in this system.")
		)
		return false
	end
	if naev.cache().joyride then
		return false
	end

	local commander = args.commander or getCommander()
	local shuttle_manager = args.shuttle_manager
		or findManagerOfType(_("Shuttle"))
		or findCrewOfType(_("Pilot"))
	if not commander or not shuttle_manager or not mem.ship_interior.shuttle.ship then
		return false
	end

	FAKE_CAPTAIN.shuttle_manager = shuttle_manager
	local template = pilot.add(
		mem.ship_interior.shuttle.ship,
		"Trader",
		player.pilot():pos(),
		fmt.f(_("{name}'s Shuttle"), { name = player.ship() }),
		{ ai = "dummy" }
	)
	template:setVel(player.pilot():vel())
	template:setDir(player.pilot():dir())
	if shuttle_manager.manager and shuttle_manager.manager.outfits then
		template:outfitRm("all")
		template:outfitRm("cores")
		for _, outfit in ipairs(shuttle_manager.manager.outfits) do
			template:outfitAdd(outfit, 1, true, false)
		end
	end

	mothership = player.ship()
	joyride_commander = commander
	mem.crewmates_joyride = true
	mem.ship_interior.shuttle.out = true
	local acquired = fmt.f(
		_("The shuttle bay of your {mothership}."),
		{ mothership = player.ship() }
	)
	joyride.swap_to_subship(player.pilot(), template, acquired, {
		client = CLIENT_ID,
		name = fmt.f(_("{skill} {typetitle} {name}"), commander),
		faction = commander.faction,
		ai = "escort_guardian",
		noland = _("The shuttle must return to its mothership before landing."),
	})

	clearCommanderInterface()
	local shuttle = player.pilot()
	shuttle:setHealth(100, commander.xp, 100 - commander.xp)
	shuttle:setEnergy(commander.xp + commander.satisfaction)
	return true
end

function hail_hook(inputname, inputpress)
	if inputpress and inputname == "hail"
		and not player.pilot():target() and not player.pilot():nav() then
		hook.timer(rnd.rnd(2, 6), "startCommandDiscussion")
	end
end

function commander_button(officer)
	addCommanderInterface()
	SHIP_OFFICERS[_("First Officer")] = officer
	if rnd.rnd(0, officer.xp) < math.abs(officer.satisfaction) then
		hook.timer(
			2 + rnd.rnd(3, math.max(10, officer.xp * math.abs(officer.satisfaction))),
			"say_specific",
			{ me = officer, message = pick_one(getConversation(officer).message) }
		)
	end
end

function commander_button_aux(officer)
	if officer.hook then
		hook.rm(officer.hook.hook)
	end
	if not officer.away then
		addCommanderInterface()
		SHIP_OFFICERS[officer.skill] = officer
		if rnd.rnd(0, officer.xp) < math.abs(officer.satisfaction) then
			hook.timer(
				2 + rnd.rnd(3, math.max(10, officer.xp * math.abs(officer.satisfaction))),
				"say_specific",
				{ me = officer, message = pick_one(getConversation(officer).message) }
			)
		end
	end
	local next_round = math.max(rnd.rnd(44, 177), 300 - officer.xp * officer.satisfaction)
	officer.hook.hook = hook.timer(next_round, "commander_button_aux", officer)
end

return contract.capture {
	name = "shuttle",
	requires = { "context", "content.character", "management", "management_discussions" },
	exports = {
		"joyride_mothership_spawned", "joyride_ended",
		"player_swaps_to_shuttle", "hail_hook", "commander_button",
		"commander_button_aux",
	},
}
