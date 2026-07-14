local fmt = require "format"
local vntk = require "vntk"
local contract = require "crewmates.module_contract"

function engineer_chief( engineer )
	if engineer.hook and engineer.hook.hook then
		hook.rm(engineer.hook.hook)
	end
	
	local pp = player.pilot()
	local armour, shield, _stress = pp:health()
	if armour == nil then return end
	
	local alert_shield = 50 + 0.2 * engineer.xp
	local alert_armor = 20 + 0.3 * engineer.xp
	local alert_power = 10 + 0.5 * engineer.xp
	
	local engis = {}
	for _i, engi in ipairs(SHIP_ENGINEERS) do
		if string.find(engi.skill, _("Hull")) then
			engis.hull = engi
			engineer.satisfaction = engineer.satisfaction + 0.01
		elseif string.find(engi.skill, _("Shield")) then
			engis.shield = engi
			engineer.satisfaction = engineer.satisfaction + 0.01
		elseif string.find(engi.skill, _("Core")) then
			engis.power = engi
			engineer.satisfaction = engineer.satisfaction + 0.01
		end
	end
	
	if engis.shield and shield < alert_shield then
		engineer_shield(engis.shield)
		engineer.xp = engineer.xp + 0.01
	end
	if engis.hull and armour < alert_armor then
		engineer_armour(engis.hull)
		engineer.xp = engineer.xp + 0.01
	end
	if engis.power and pp:energy() < alert_power then
		engineer_power(engis.power)
		engineer.xp = engineer.xp + 0.01
	end
	
	-- set the next hook to poll
	engineer.hook.hook = hook.timer(math.max(6, 6 * player.pilot():ship():size() - engineer.xp * engineer.satisfaction), "engineer_chief", engineer)
end

-- Engineer that converts power into shields  (simple logic)
-- if we are at low shield, the engineer tries to reroute some power to shields
-- an unsatisfied engineer will waste power and drain shields (but earn satisfaction and stabilize)
function engineer_shield(engineer)
	if engineer.hook and engineer.hook.hook then
		hook.rm(engineer.hook.hook)
	end
	engineer.hook.hook = nil
	local pp = player.pilot()
	local armour, shield, _stress = pp:health()
	if armour == nil then return end
	
	if shield < math.min(50, 20 + engineer.xp * 0.1) then
		-- try to initiate a power surge to shields
		local surge = engineer.xp * engineer.satisfaction * pp:ship():size() * 0.3
		local power_needed = math.max(engineer.xp * 0.1, surge * (120 - engineer.xp) - engineer.bonus)
		local current_power = pp:energy()
		-- learn to not be too greedy with the power
		if current_power > power_needed * math.max(1, engineer.xp) then
			pp:setEnergy(current_power - power_needed, true)
			pp:addHealth(0, surge)
			engineer.satisfaction = engineer.satisfaction + 0.01
			engineer.xp = math.max(100, engineer.xp + 0.01)
			-- doing our job makes our workstation and the rest of the ship dirtier
			mem.ship_interior.dirt = mem.ship_interior.dirt + engineer.xp * 0.06
			-- reaction to having done something
			if rnd.rnd() < engineer.chatter then
				-- act like a weird engineer
				local listener = getCrewmateOnboard()
			speak_to( {me=engineer, responder=listener, message=add_special(engineer) .. " " .. add_special(engineer) })
			elseif rnd.rnd() < engineer.chatter then
				-- act normally
				speak(engineer)
			end -- otherwise: just stay silent
		end
	end
	
	-- set the next hook to poll
	engineer.hook.hook = hook.timer(math.max(6, 8 * player.pilot():ship():size() - engineer.xp * engineer.satisfaction * 0.1), "engineer_shield", engineer)
end

-- Engineer that converts armor into power (simple logic)
-- if we are at low power, the engineer tries to burn armor as fuel to generate power
-- an unsatisfied engineer will waste power and drain armor (but earn satisfaction and stabilize)
function engineer_power(engineer)
    print("power engineer!")
	if engineer.hook and engineer.hook.hook then
		hook.rm(engineer.hook.hook)
	end
	engineer.hook.hook = nil
	local pp = player.pilot()
	local armour, _shield, _stress = pp:health(true)
	if armour == nil then return end
	local current_power = pp:energy(true)
  	print(fmt.f("armour {armour} points energy {cp} ({energy} %)", { energy=pp:energy(), cp = current_power, armour=armour }))
	if pp:energy() < math.min(50, 20 + engineer.xp * 0.1) then
		-- try to initiate a power surge
		local surge = engineer.xp * engineer.satisfaction * pp:ship():size() * 0.01
		local armor_needed = math.max(engineer.xp * 0.1, surge * (120 - engineer.xp) - engineer.bonus) / (10 - pp:ship():size())
  		print(fmt.f("armourneeded {armour_needed}/{armour} points surge {surge}", { energy=pp:energy(), cp = current_power, armour=armour, armour_needed=armor_needed, surge=surge }))
		-- learn to not be too greedy with the armor
		if armour > armor_needed * math.max(1, engineer.xp * 0.1) then
            print(fmt.f("adding {pwr} power at expense of {arm} armor", { pwr=surge * 4, arm=armor_needed } ))
			pp:setEnergy(current_power + surge * 4, true)
			pp:addHealth(-armor_needed)
			engineer.satisfaction = engineer.satisfaction + 0.01
			engineer.xp = math.max(100, engineer.xp + 0.01)
			-- doing our job makes our workstation and the rest of the ship dirtier
			mem.ship_interior.dirt = mem.ship_interior.dirt + engineer.xp * 0.06
			-- reaction to having done something
			if rnd.rnd() < engineer.chatter then
				-- act like a weird engineer
				local listener = getCrewmateOnboard()
			speak_to( {me=engineer, responder=listener, message=add_special(engineer) .. " " .. add_special(engineer) })
			elseif rnd.rnd() < engineer.chatter then
				-- act normally
				speak(engineer)
			end -- otherwise: just stay silent
        else
            print(fmt.f("engineer didn't do anything because {armor} < {armor_needed}", { armor=armour, armor_needed = armor_needed * engineer.xp * 0.1 } ))
		end
	end
	
	-- set the next hook to poll
	engineer.hook.hook = hook.timer(math.max(6, 8 * player.pilot():ship():size() - engineer.xp * engineer.satisfaction * 0.1), "engineer_power", engineer)
end

-- engineer that converts shields and power into armour (active/cooldown logic)
-- the engineer is on duty in the engineering room
-- if the armour goes below 95%, the engineer wakes up and gets to work,
-- after some time (depends on skill and satisfaction) the engineer starts healing the ship
-- the healing gets stronger and stronger but heat accumulates
-- healing can only continue while shiled and energy are near full, and stress near zero
-- this makes the engineer useless for tanking, but great at repairing in between fights
function engineer_armour(engineer)
	if engineer.hook and engineer.hook.hook then
		hook.rm(engineer.hook.hook)
	end
	engineer.hook.hook = nil
	local pp = player.pilot()
	local armour, shield, stress = pp:health()
	if armour == nil then return end
	
--	print(fmt.f("{armour}, {shield}, {stress}", {armour=armour, shield=shield, stress=stress}))
	
	-- engineer hero sacrifice (but not if the player already died)
	if (armour <= 4 and pp:energy() > 36 and armour > 1) then
		local health_bonus = engineer.xp * engineer.satisfaction * 0.1
		if health_bonus > 0 then
			pp:addHealth(health_bonus, health_bonus / 8)
			engineer.bonus = health_bonus
		else	-- just give him 3 armor points and the death, too bad he was unhappy
			engineer.bonus = 3
			pp:addHealth(3)
		end
		local message = fmt.f(_("Your engineer, {name}, was lost in space combat while maintaining hull integrity. As a final valiant act of heroism, {bonus:.0f} armor was repaired in a massive power surge."), engineer)
		vntk.msg(_("Heroic Sacrifice"), message)
		terminate_crew(engineer, message, { force = true })
		SHIP_ENGINEERS = {} -- someone died, let's not do the bookkeeping about it now though
		return -- no new hook
	elseif (armour <= 10 and pp:energy() > 20) then
		-- "active situation" polling rate
		engineer.hook.hook = hook.timer(16 - engineer.satisfaction, "engineer_armour", engineer)
	end
	
	-- standard engineer duties
	if (armour < math.min(100, 90 + engineer.xp * 0.1)
		and shield >= 100 - engineer.xp * 0.1 - engineer.satisfaction
		and stress * stress < engineer.satisfaction * engineer.xp * 0.1
		and pp:energy() > 96 - engineer.satisfaction
		) or	-- engineer spits out his coffee and roll up his sleeves
		(armour <= 16 + engineer.xp * 0.1 + engineer.satisfaction and pp:energy() >= 4)
	then

		-- begin healing after a slight delay
		if engineer.active then
			-- healing stage begun
			engineer.hook.hook = hook.timer(
				rnd.rnd(math.floor(11 - engineer.xp * 0.1), math.ceil(22 - engineer.xp * 0.1 - engineer.satisfaction)),
				"engineer_armour", engineer)
			engineer.active = engineer.active + 1
			local healed = math.ceil(engineer.xp * engineer.active / (engineer.xp * engineer.xp + 1))
			pp:addHealth(healed, -healed * healed )
			local heated = engineer.active / (engineer.xp * engineer.xp * 0.1+ engineer.active + 1)
			pp:setTemp(pp:temp() + heated)
			local energy_used = heated * healed * engineer.xp * 0.12
			pp:setEnergy(pp:energy(true) - energy_used, true)
--			print(fmt.f("healed {healed} armour points and heated by {heat} K at cost of {mw} energy", { healed = healed, heat = heated, mw=energy_used }))
		else
			engineer.active = 1 + engineer.bonus * 0.1
			local delay = math.max(2, 20 - engineer.xp * 0.1 - engineer.satisfaction)
			engineer.hook.hook = hook.timer(delay, "engineer_armour", engineer)
			
			local message = pick_one(engineer.conversation.message)
			_comm(fmt.f("{typetitle} {name}", engineer), message .. fmt.f(" I need about {delay} more seconds... ", { delay = math.max(2, math.ceil(delay + rnd.threesigma() * 10)) }) .. add_special(engineer) )
			engineer.satisfaction = math.min(10, engineer.satisfaction + 0.01)
		end
		return
	elseif engineer.active then
		-- experience gained while cooling down
		local gained_xp = (engineer.active * 0.01)
		engineer.xp = math.min(100, engineer.xp + gained_xp)
--		print(fmt.f("engineer cooldown and gained {xp} xp", {xp = gained_xp}))
		-- entering cooldown distributes residue dirt everywhere around the ship
		mem.ship_interior.dirt = mem.ship_interior.dirt + engineer.xp * 0.06
		if rnd.rnd() < engineer.chatter then
			-- act like a weird engineer
			local listener = getCrewmateOnboard()
			speak_to( {me=engineer, responder=listener, message=add_special(engineer) .. " " .. add_special(engineer) })
		elseif rnd.rnd() < engineer.chatter then
			-- act normally
			speak(engineer)
		end -- otherwise: just stay silent

		-- cooldown
		engineer.active = math.max(0, engineer.active / 2 - 3)
		engineer.hook.hook = hook.timer(20 * player.pilot():ship():size() + 10 * engineer.xp + engineer.satisfaction, "engineer_armour", engineer)
	elseif not player.isLanded() then
		-- polling rate to start the engineering logic 
		engineer.hook.hook = hook.timer(math.max(6, 20 * player.pilot():ship():size() - engineer.xp * engineer.satisfaction), "engineer_armour", engineer)
	end
	-- engineer cooldown finished to reset
	if engineer.active and engineer.active < 3 then
		engineer.active = nil
	end
end

-- the player boards a hostile ship with a demoman on board
function player_boarding_c4(target, speaker)
	if target and target:exists() and target:hostile() and target:memory().natural == true then
		hook.timer(2, "speak_notify", speaker)
		hook.timer(6, "detonate_c4", target)
		hook.timer(8, "detonate_c4", target)
		hook.timer(9, "detonate_c4", target)
		hook.timer(10, "detonate_c4", target)
		hook.timer(rnd.rnd(10, 11), "detonate_c4", target)
		hook.timer(11, "detonate_c4", target)
		hook.timer(12 + rnd.rnd(), "detonate_c4", target)
		hook.timer(12 + rnd.rnd(), "detonate_c4", target)
		hook.timer(12 + rnd.rnd(), "detonate_c4", target)
		-- we just planted a bomb, increase satisfaction
		speaker.satisfaction = math.min(10, speaker.satisfaction + 1)
		-- if we planted a bomb on something big, create a memory based on how likely we are to mention it
		if target:ship():size() >= 5 and rnd.rnd() < speaker.chatter then
			create_memory(
				speaker,
				"violence",
				{
					target = target:name(),
					ship = target:ship(),
					credits = fmt.credits(target:credits()),
					cred_amt = target:credits(),
					armour = target:health(true),
					system = system.cur()
				}
			)
		end
		-- boarding the enemy ship and all that jazz made everything dirty
		mem.ship_interior.dirt = mem.ship_interior.dirt + speaker.xp * target:ship():size()  * 0.1
	else
		-- we boarded something for friendly reasons, if we like violence, we are pissed
		for _i, person in ipairs(mem.companions) do
			if has_interest(person, "violence") then
				person.satisfaction = math.max(-10, person.satisfaction - 1)
			end
		end
	end
end

-- a demoman's bomb explodes (single payload)
function detonate_c4(target)
	if target and target:exists() then
		local sound_choices = {
			"medexp1",
			"medexp0",
			"crash1",
			"grenade",
			"explosion0",
			"explosion1",
			"explosion2",
			"tesla"
		}
		local dir_vec = vec2.new(math.floor(rnd.threesigma() * 30), math.floor(rnd.twosigma() * 20))
		target:knockback(800, dir_vec, target:pos() - dir_vec)
		target:setDir(target:dir() + rnd.threesigma() * 0.07)
		local expl_pos = vec2.add(target:pos(), rnd.threesigma() * 2, rnd.twosigma() * 2)
		-- apply the damage (the player gets the credit)
		target:damage(rnd.rnd(277, 313), 0, 100, "impact", player.pilot())
		-- visual and audio effects?
		audio.soundPlay(pick_one(sound_choices), expl_pos)
		-- we used explosives, add to cost
		local current_cost = mem.costs["equipment"]
		if current_cost == nil then
			current_cost = 0
		end
		mem.costs["equipment"] = current_cost + prices["equipment"]
		-- an explosion just happened, if we like violence, we are thrilled
		for _i, person in ipairs(pick_some(mem.companions, 3)) do
			if has_interest(person, "violence") then
				person.satisfaction = math.min(10, person.satisfaction + 0.01)
			end
		end
	end
end

-- function to restore the player into the "mothership" after
-- a joyride in the shuttle

return contract.capture {
	name = "abilities.engineers",
	requires = { "context", "memory", "conversation_runtime", "management" },
	exports = {
		"engineer_chief", "engineer_shield", "engineer_power", "engineer_armour",
		"player_boarding_c4", "detonate_c4",
	},
}
