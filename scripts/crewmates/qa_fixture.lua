-- One-shot bootstrap for the checked-in manual QA pilot.  The save contains
-- only a version marker; using the real factories here keeps the fixture from
-- becoming a serialized copy of yesterday's character schema.

local contract = require "crewmates.module_contract"

local QA_FIXTURE_VAR = "_crewmates_qa_fixture"
local QA_FIXTURE_VERSION = 1

local function identify(crewmate, name, satisfaction, xp)
	crewmate.name = name
	crewmate.firstname = name
	crewmate.satisfaction = satisfaction
	crewmate.xp = xp
	return crewmate
end

local function ordinary(name, skill, satisfaction, xp)
	local crewmate = createGenericCrewmate()
	crewmate.skill = skill
	return identify(crewmate, name, satisfaction, xp)
end

function seedQaFixture(mem)
	local marker = var.peek(QA_FIXTURE_VAR)
	local requested_version = tonumber(marker)
	if not requested_version then
		return false
	end
	assert(requested_version == QA_FIXTURE_VERSION,
		"unsupported Crewmates QA fixture version: " .. tostring(requested_version))
	assert(#mem.companions == 0,
		"refusing to seed the Crewmates QA fixture over an existing roster")

	local roster = {
		identify(createFirstOfficer(), "QA First Officer", 3.5, 18),
		identify(createPirateOfficer(), "QA Pirate Commander", 1.5, 24),
		identify(createShuttlePilot(), "QA Shuttle Pilot", 2.5, 12),
		identify(createEscortCompanion(), "QA Escort Companion", 5, 9),
		identify(createSmuggler(), "QA Smuggler", -1.5, 14),

		identify(createArmorEngineer(), "QA Hull Engineer", 3, 16),
		identify(createShieldEngineer(), "QA Shield Engineer", 2, 11),
		identify(createPowerEngineer(), "QA Core Engineer", 1, 8),
		identify(createExplosivesEngineer(), "QA Demolitions Engineer", 4, 20),

		identify(createPsychologistManager(), "QA Psychologist", 3, 13),
		identify(createMoraleOfficer(), "QA Morale Officer", 4.5, 17),
		identify(createScienceFarmer(), "QA Hydroponics Scientist", 2, 10),
		identify(createGenericManager(), "QA Personnel Manager", 1, 15),

		ordinary("QA Cargo Specialist A", "Cargo Bay", 3, 7),
		ordinary("QA Cargo Specialist B", "Cargo Bay", 2, 9),
		ordinary("QA Cargo Troublemaker", "Cargo Bay", -2.5, 5),
		ordinary("QA Maintainer A", "Maintenance", 3, 12),
		ordinary("QA Maintainer B", "Mechanic", 1, 6),
		ordinary("QA Security A", "Security", 2, 14),
		ordinary("QA Pirate Crew", "Pirate", -1, 19),
		ordinary("QA Sanitation A", "Sanitation", 3, 8),
		ordinary("QA Janitor", "Janitorial", 5, 21),
		ordinary("QA Rookie", "Rookie", 0, 0.5),
		ordinary("QA Cadet", "Cadet", 2, 5.9),
		ordinary("QA Ensign", "Ensign", 3, 15.9),
		ordinary("QA Lieutenant", "Lieutenant", 4, 31.9),
		identify(createPassenger(), "QA Passenger", 1, 2),
	}

	for _, crewmate in ipairs(roster) do
		table.insert(mem.companions, crewmate)
	end

	mem.ship_interior.shuttle = { ship = ship.get("Alpaca") }
	mem.ship_interior.dirt = 7
	mem.ship_interior.dirt_accum = 0.5
	mem.qa_fixture_version = QA_FIXTURE_VERSION
	mem.qa_fixture_seeded = true
	evt.save(true)
	var.pop(QA_FIXTURE_VAR)
	return true
end

return contract.capture {
	name = "qa_fixture",
	requires = { "crew_factory", "crew_factory_officers" },
	exports = { "seedQaFixture" },
}
