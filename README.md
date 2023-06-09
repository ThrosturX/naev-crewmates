# Naev Crewmates Plugin

This plugin provides the necessary files to add crewmates to Naev.

Simply walk into a bar, hire someone as crew and enjoy the chaos.

## Introduction

Do you want to add a little bit more life aboard your spaceship in naev?

Unlike the crew on the ships currently that isn't even named, these crew members want to be known to the captain and they tend to walk in and say things in the middle of a conversation, dragging some life in and out of the ship's bridge or cockpit. Every crew member is randomly generated to have different interests and starting conversation lines, but every crew can also learn a range of new lines based on the interactions they have and the events that happen around the ship. For instance, if you run low on fuel and you're stranded, a crew member might remember that and reminisce on it later if he was there to experience it. Likewise, when there is a conversation between two people, there is usually a third party present that has a chance to chime in at an appropriate moment, or to express themselves individually after the conversation. It's almost human, but not really, maybe touching uncanny valley if I'm perfectly honest, but I've been having a lot of real laughs, so I think it's worth sharing what I've got so far for some feedback.

## Give me the TL;DR
You hire crew, they don't do much, but they talk to each other and about what has happened in the past on your ship when they were present. Some of the crew types do something special like rerouting power/shields, consuming armor for power, repairing armor, smuggling goods, salary calculations, leaving explosives on enemy ships and complain about The Stinker. If you find an "Attractive `<gender>`", hire them immediately and when they report in, open your info menu to talk to your new first officer.

### What it is
You hire a randomly generated character that has some unique characteristics like `conversation` and topics of interest/disinterest in what I call the character sheet. There is also `xp`, `satisfaction`, and probably some other stuff that's not really important.
The important thing is they try to talk to each other and have conversations, they experience space hysteria if they are alone in space for too long and they can present social or antisocial behaviors based on their interests and the events that occur. They will create memories that they will recall later and say things like "That Goddard didn't stand a chance!" at a completely unexpected time in the future, or they might say "Boy, these Bounty Hunters sure are lucrative" if you board several bounty hunters with a lot of credits inside consecutively. But most of them don't have any skills and don't do anything for you except act as conversation buffers between skilled crew of polar interests, such as the companion and engineer are supposed to be.

### The types of crew

There are a few, here's a brief summary.

- Officers/Managers:
  - First Officer
  - Companion - can't do payroll
  - Personnel Manager
  - All managers have the crew assessment skill, all officers have the command assessment skill
- Smuggler
- Engineers:
  - Explosives Expert
  - Hull Integrity
  - Shield Stabilization
  - Core Stabilization (Power)
- supporting crew
  - Pilot (can fly a "shuttle" if the ship has one)
  - Janitorial (keeps ship clean)
  - Maintenance (supports engineers)
  - Security (TODO: defense when boarded by pirates)
  - Cargo Bay (increases effective fighter bay strength for shuttles)
  - Regular (Rookie -> Cadet -> Ensign -> Lieutenant) (TODO: promote from lieutenant to officer?)

There are long-winded explanations below but the key thing is that you can actually chat with a first officer on the bridge (not at the bar, he won't be on duty) and say things like `list pilots`, `sell cargo`, `restock fruit` or `commend johnstone` and then go and do the assigned command. Related to `list pilots`, you can `[info|sheet] <workername>` to get the employment sheet from the personnel records (any personnel manager can do this at the bar too). Otherwise, the officer will just tell you relevant ship information or something related to your query until you say something that starts a mission or wasn't understood.

The "Personnel" manager is just a regular crew member with the "assess crew" skill that the companion gets as well (and any other manager), but also gets the payroll skill which corrects captain's salary calculation mistakes. They just exist to be a red herring among the other crew members so that the player doesn't have to hire a bunch of special skills just to get that feature of some chitchat on the bridge. You don't actually need any crew at all, but I think the engineers are kind of fun and it's entertaining to watch them interact with each other and discuss events from their backstory or memories from the ship.

The best stuff comes from hiring a **first officer**, which allows you to do an in-space conversation with your first officer OR _any of your crew_! Without a first officer, you are limited to conversations with whatever crew from your ship happens to go to the bar unless you have a manager and pay them to summon everyone to the bar at the next destination.
The first officer comes with a Gawain and you can optionally purchase a different shuttle. The first officer can sell a random non-food cargo (open chat, type "sell cargo") to a planet in the system or have a pilot in the crew do the mission instead (so you don't risk your highly experienced first officer on an away mission selling 10 tons of luxury goods).

Actually regular crew can be promoted from Rookie -> Cadet -> Lieutenant but the only differences between these ranks at the moment is how effective the crewmember is counted in the "general workers" count and whether or not they do any janitorial duties. Cadets don't do cleaning but are full crew members, Rookies clean a bit but don't do much work, Lieutenants do half work but a good amount of cleaning, so if you have many lieutenants don't need as many janitors for instance.

### note on limits
There are limits to what crews you can hire or how many of each depending on your crew roster. The first officer opens a lot of options and anyone with the title `"<specialty> Officer"` will allow more crew of `<specialty>` (not fully implemented yet).

### Some of the special crew

The **explosives engineer** is simple. You board a ship, he feels unhappy. He says something like "Tick tock". The ship goes boom and he is thrilled. He talks about violence a lot and likes to laugh. I recommend hiring one with a low chatter value, you can tell that it's really low if his hiring text is something like "Hello. Weapons expert. Need one?" instead of the wall of text you'd usually get. The amount of text roughly corresponds to how likely this crewmate is to respond to things and remember unimportant events.

The **Hull Integrity engineer** will repair your armor slowly but at an increasing rate when your shields and energy are near full. Useful on ships that can put nanobots on them if you like going on long adventures. Not useful at tanking, obviously, since shields and power need to be full.

The other engineers consume armor for power or power for shield every once in a while if the player seems to really need it. More useful in active situations as they convert something they think is less important than the thing you hired them for, but don't expect a power engineer to do anything if you're low armour or a shield engineer to do anything without accessible power.

The **smuggler** will ask you if you want to sell your cargo when you open your cargo bay (info menu). If you say yes, he will grab whatever he can fit in his cargo and sell it at a random planet in the system that buys the commodity. Useful if you like outings in hostile territory. A smuggler can't join a ship with a first officer or any other crew member that wants to use the shuttle bay for that matter. A smuggler has a bigger shuttle ship than a first officer or a pilot can use, because the smuggler is special. A lot of cargo workers can get the smuggler all the way into a Rhino if you have enough fighter bays, but most people will probably see the smuggler in a koala  or perhaps a mule or quicksilver.

The **companion** escort is some kind of mysterious business person that has clients all over the wealthy parts of the world (it checks tags) and abhors places like The Stinker. It gets a huge gain to satisfaction on rich worlds with trade and medical facilities and all that jazz and a huge malus on worlds like the stinker or anything with the "poor" tag. Sometimes, the companion will create a unique memory to talk about the profit made on a certain planet, or it will associate a certain solar system with good luck or whatever. The companion escort also comes with a personnel manager skill that allows you to ask them how the crew is doing and to summon all the crew to the bar at the next destination (you can just take off and land, I suppose). Otherwise, crewmates don't always appear at the bar because they'd rather be doing something else than hang with the captain when they're not flying in space. For this reason, I recommend hiring a companion so that you can use it to fire any annoying crewmates that get too much space hysteria and start rambling incoherently more than the engineer usually does. The other current use is that the companion gets really happy on those rich words, so if you have unhappy crew you can use your happy companion to cheer them up by buying them drinks at the bar (it's better to summon the whole crew there first). The first officer and personnel managers can also buy drinks, but they charge a lot more money.

The **First Officer** can rename crew, commend crew, convert food into fruit for the crew, buy drinks, motivate the crew (consumes some of the officers XP but everyone gets that amount of xp) and even does payroll so the captain's mistakes don't affect the crew. Pretty much everything you do with this officer costs money but it's your best crew member, completely unique and serves as the primary interface between the rest of your crew. There are also some hidden perks, like the first officer will re-shuffle the crew roster so that low ranking cadets and recruits are moved to the back, so if you have 50 crew from your Goddard and swapped into a Zebra, you're still going to have all the janitors and crew you need even though they were recent hires. You can talk to the first officer from space (info menu), but the special commands like renaming and commending are not available at the bar (not the right jurisdiction, you can't just rename someone willy nilly at some bar).

But anyway, you get a guy that blows up your boarded ships (or close to it in rare cases) and a bunch of crew mates with small fees that you see in your ship log from time to time. And since I'm still updating this, you now also get a smuggler to sell your zebra plunder and an engineer that will repair your armor very slowly, but slow is better than zero!

### Other stuff

I just have to reiterate here that you'll want to get a first officer for testing as it opens up all of the in-space options you'll want to play with. AND HIRE A FEW JANITORIAL STAFF EARLY!

**EASY CREW MANAGEMENT QUICK TIPS**:
- Restock the fruit all the time. Buy drinks. Spend money on your crew. They will get unhappy with time unless you carefully assemble a crew roster.
- If your crew is unhappy, just type `banana` to the commander (first officer), start a new conversation and then select the option to distribute `<random fruit>` among the crew. This will increase everyone's satisfaction a random amount.
- DRINKS can reduce happiness, but are more fun and you don't need anything in your cargo to use them.
- MOTIVATION (from commander) costs some of the commander's XP and will give EVERY crew member an increase to satisfaction equal to `rnd.sigma() + siphoned_xp - rnd.rnd()`. So a low-xp commander will be bad at motivating but a high-xp commander will be very effective.
- If you have a pilot, tell your first officer to `summon <pilotname>` after an away mission and if the pilot has a goodie crate, distribute the fruit to the crew

There are a bunch of costs to having crew and there are placeholders where an accountant type could do some sort of analysis & bookkeeping, but right now you'll just see some log entries every once in a while or hear the money or bingo sound (paying for something or authorizing a party or whatever). The gist of it is that `commend`ing someone increases their salary by 1% and the starting salary depends on the starting `xp` and `satisfaction`. In other words: Hire a cheap commander! Or if you need to motivate your crew, hire an expensive one and have them do the motivation until they have no `xp` left, then get a cheaper one later.

The ship has a "simulated interior atmosphere" and requires a certain amount of crew to keep in order. Crew members will complain that the ship is dirty if you don't have janitorial staff (your first officer will tell you to hire janitorial staff as well if you talk to him on the bridge). Crew members can be affected by the cargo in your ship, whether you have someone calculating payroll or pay salaries yourself (if you don't hire a payroll skilled manager, you will make mistakes and some of the crew will complain). There's really a lot of stuff because it's the co-interaction that makes it all so interesting, but hopefully I might refactor some of this at some point.

If the ship gets dirty, memories and/or sentiments about it are created which may take a while to dissipate, so even once the ship is clean, you'll still hear crew members complain about the state of the ship. That's by design! Just because the ship was cleaned doesn't mean it's always clean, if you complain about it being filthy, you remember it being filthy and you'll mention it to someone on a whim. If the ship is dirty, you need to make sure your janitors are happy (otherwise they aren't effective) and that you have enough staff (janitors and/or workers that can clean).

### What about XP? How does crew get XP?

Crew almost always gains `xp` from the following:
- being paid (receive salary)
- witnessing a sacrifice (a crew member was fired out of the airlock)
- **charging the player for something** (such as serving a crate of fruit)
- doing payroll for the captain (this is a big one!)
- creating a memory
- having a low-priority sentiment
- performing an appropriately assigned mission (engineer boosts shield/power or enters cooldown after repair, pilot leaves full of cargo to sell, etc)
- being a cargo bay worker and the player enters the cargo bay with a smuggler on board

Crew usually gains, but sometimes loses `xp` from the following: (sorted by gain likelihood)
- being commended
- (officer only) discarding a special crate
- being renamed

Crew always loses `xp` from the following:
- being paid the incorrect amount
- being promoted resets `xp` to 1
- being an officer and being told to motivate the crew

### What is the max XP and what does it do?
Special crew can have XP up to 10 and usually it is a multiplier to satisfaction or a constant bonus to something. Usually high XP means that even if a character is at 0.1 satisfaction, they can still do a good job, but if they become unsatisfied the performance difference becomes stark, so unsatisfied high-XP crewmates should quickly start raising alarms.
Regular crew can get XP up to 100 and the experience either dictates how close they are to a promotion or their work strength, in the case of e.g. janitors or cargo bay workers, janitors with high XP and satisfaction can be doubly effective whereas janitors with low xp or negative satisfaction might be so ineffective that you would need 4 just to do the job of one unbonused janitor.
