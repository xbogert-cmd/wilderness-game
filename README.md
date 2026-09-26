# Wilderness (working title)

An atmospheric 2D side-scrolling wilderness survival game set in the western United States. Built with Godot 4.7.1 and GDScript.

## Run
Open the folder in Godot 4.7 and press Play, or from a terminal:
```bash
godot
```

## Controls
| Key | Action |
|---|---|
| A / D | Move |
| Shift | Run (uses stamina) |
| Ctrl | Crouch |
| Space | Hop |
| Tab | Backpack (pauses the game): drag to pack, R rotates while dragging |
| M | Map and field journal (pauses the game) |
| 1 / 2 | Draw the tool strapped outside the pack (hatchet, knife), or put it back |
| Left click | Use what's in hand: chop, eat, drink, treat, fish, knife an unaware deer, thrust the spear, wave the torch. Bow and spear: press and pull the mouse back like a slingshot (the farther, the harder); a dotted line shows the whole flight and a ring where it lands; let go to shoot or throw (a click with the spear thrusts). With a felled trunk, aim at a length mark |
| E | Interact (anywhere across a fire, bench or cabin counts, not just its middle): pick up, fill a container at the creek, deliver materials, the fire, a carcass. Where there's more than one thing to do, E opens a numbered list: press the number (E again or walking off closes it) |
| F | Lift or set down a log (short and medium logs ride on the shoulder; long logs drag), or let go of a dragged carcass |
| Q | Put away what's in hand |
| B | Build book (pauses): every build with a picture, what it takes and where to get what you're short of. *Place the blueprint*, then click the ground to place it (right-click cancels) |
| F3 | Debug overlay |
| Z | Sleep under a shelter, or anywhere with your sleeping bag (out in the open the rain gets you and it isn't camp); time runs about 60× faster, and any key wakes you |
| Esc | Pause menu: save to slots 1–3 (only when safe), load any slot or the autosave |
| F5 | Quicksave to slot 1 |
| S | Go down: standing on a cellar door, a log over a sinkhole, planks over a shaft, or a ledge underground, S takes you down (E does too). Otherwise you just walk over them |

**Camp, sleep, and death:** building or sleeping in a lean-to makes it your camp, which is your respawn point and triggers an autosave (the game also autosaves every 5 minutes when you're safe). If you die, you wake at camp without your pack, which stays where you fell. Food spoils, tools come back duller, and some consumables scatter, but nothing irreplaceable is ever lost. Walk back and press E to recover it.

**Wildlife and fishing:** mule deer graze at dawn and dusk, bed down midday, and read your noise and silhouette. Running spooks them from far off; crouching (Ctrl) and moving slowly gets you close. They bolt, stot away, and settle somewhere new, never chasing across the map. Hooves and boots print in the dark bank mud; press E on deer tracks to read their age and direction. Rain washes tracks out faster. Small birds burst up when you come close. To fish, craft a pole in the backpack (2 sticks + line & hooks), click toward the creek to cast, click when the bobber plunges, then click whenever the needle is in the green. Cook the catch at a lit fire (E) rather than eating it raw.

**Seasons and snow:** the journey starts in early autumn and the year turns: autumn, winter, spring, summer (6 days each, see `data/tuning.tres`). Temperature and day length follow the year smoothly: the aspens go gold, then bare; nights get cold; below freezing the weather brings snow instead of rain. Snow lies and deepens, slows you (knee-deep costs about 40% of your pace), and takes everyone's tracks, anywhere. A long hard cold freezes the creek: the ice bears your weight, E chops a hole to reach the water (it skins over in about 8 hours), and an empty pot held on snow packs full of it to melt and boil on the fire. Your breath shows in the cold, working keeps you warmer, and winter thins the deer. The pause menu shows the day and season; the backpack shows the air temperature.

**Weather you can read:** before rain the wind backs round, the sky thickens and the birds go quiet (a message says so); before a thunderstorm thunder mutters far off. The lookout keeper's brass *barometer* (on the cab wall at the fire lookout) shows the pressure bottom right while it's in your pack: *falling* means rain within hours, well before the sky shows it, *falling fast* a storm. Weather to know:
- *Thunderstorms* (warm-season rain): lightning flashes and the thunder comes after, later the farther off the strike. Now and then it strikes close and the tallest tree nearby catches in the crown, raining embers for an hour or two until the rain beats it out. Warm yourself at the foot of it, or hold a stick in the embers for a torch. Nothing burns for good.
- *Fog*: calm mornings after rain, and in spring and autumn, fog fills the valleys and bottoms and burns off by late morning. You can hardly see a stone's throw, and animals can hardly see you. Up on the ridge you stand above it.
- *Blizzards* white out the view the same way, and cut through your clothes.
- *Chinook*: now and then in midwinter a warm wind roars down off the ridge, 15 °C and more warmer, and eats the snow in hours. Thin ice and high water follow.
- *Floods*: hard rain, thunderstorms and snowmelt raise the creeks. In flood they run brown, bank to bank, and are too deep and fast to wade: the current shoves you back to the bank; cross on a bridge, or wait a day for it to drop. A flood can tear fish traps, gill nets and weirs loose and take them downstream.
- *Thin ice*: new ice, and thawing ice, is thin: it creaks and sags under you, then cracks, then gives way. Through the ice you're soaked to the skin in freezing water, and until you get to a fire it hurts you badly (it won't kill you on its own). Hard ice is safe.
- *The breakup*: in a thaw the ice goes out down the creeks in grinding, cracking floes, and the water comes up behind it.

**Stepping stones** (build book, no materials, 2 hours of rolling rocks out of the creek bed): a line of flat rocks across a creek to cross with dry feet. The river's too deep for them, and in flood the water runs over them.

**Woodpile:** build one (B, 4 sticks) and stack short logs in it with E. It holds 15, drawn end-on as a pyramid that matches the count. E with empty hands takes one back out, and a fire within a few metres feeds straight from the pile.

**Camp builds:** everything is placed with B and built by bringing materials and pressing E.
- *Pot tripod* (3 sticks) goes over a campfire; the pot hangs from it, and only then boils water. E at the fire pours your bottle (in hand or in the pack) into the hanging pot, or fills the bottle from it once it has boiled. Pouring dirty water into clean makes it all dirty again.
- *Hunting blind* (6 sticks): crouched behind it, deer can barely see or hear you and will walk right past. Draw the bow over it.
- *Hide frame* (2 medium logs, 2 sticks): a raw deer hide, wolf pelt or bear hide rots in two days unless you stretch it on the frame. It cures in 18 hours (a bear hide 30) into tanned hide or cured fur.
- *Drying rack* (2 medium logs, 4 sticks): hang raw venison or fish from your hands or straight from the pack (8 strips). It dries into jerky in about 12 hours, faster beside a fire, stalled by rain. Hanging meat doesn't spoil.
- *Log cabin* (6 long logs, 6 medium, 4 sticks, 8 hours to build): shelter whose walls hold warmth like a fire. Building or sleeping in it makes it camp, and it's the best sleep in the valley.

**The whole country, west to east:** the sage flats and Alder Creek at the western edge, an old homestead in a meadow, a marsh with a pond, the Sweetwater River (chest-deep and cold: build a *log bridge*, 4 long and 2 medium logs, over it or any creek) with an old trapper's camp on its east bank, then the valley. Past the lookout the land drops into an old burn where a bush plane came down, then climbs to a high basin with a tarn. Each biome has its own plants and trees. The homestead, the trapper's camp and the wreck each have things to search (E shows the choices) and pages for the journal; the wreck is shelter. Some nights, from the ridge or anywhere east of it, pale lights move along the far skyline. Signal flares (from the wreck) light up the sky and scatter anything wild.

**Further still:** west of the sage the country dries into semi-desert (junipers, cholla, prickly pear, yucca, red rock) around *Juniper Spring*, whose water is clean to drink unboiled, and breaks into a red-walled canyon with the old *Lucky Boy mine* on its floor. East of the tarn a boulder field runs to the basin rim, where the tarn's outlet pours over *the falls* into a deep pool; below lies old-growth forest along Cedar Creek (huge cedars and firs, ferns, mossy logs, mushrooms), and at the far east end a great aspen grove. Dry country runs warmer, the rocks and the deep timber cooler.

**Underground:** the homestead's *root cellar* (down the steps under a board door), a *cave* in the foothills (drop through under a fallen log over a sinkhole, down a scree slope to a gallery, then a rope down a shaft to a lower chamber with a clear pool, flint, a bear's den, fossils and something painted on the rock), and the *Lucky Boy mine* (a ladder down the shaft under the headframe, a drift with rails and an ore cart, a collapse to clear with the axe, a coal seam, and a miners' cache). Openings are walked over like ground: S (or E) takes you down. Ledges drop through with S; ladders and ropes climb with E. It's pitch dark down there without a torch or lantern, sheltered, and about 8 °C all year; nothing up top can see or hear you. Break flint and coal out of their seams with the axe.

**Regrowth:** felled trees come back: a sapling grows up where the stump rots away, full grown in about three seasons. Berries, vines and wild plants grow back after a season of growing weather (winter doesn't count).

**Things to come across:** bleached bones and steer skulls on the flats, shed antlers, old fire rings (sometimes a tin or matches), wagon wheels sinking into the sage (boards for firewood), glass bottles half-buried near water (a second water bottle), brass survey benchmarks on high rocks, squirrels' hoards in hollow logs, rusted traps, lone graves. Each fits the country it's in.

**Light and fire:** matches and flint light fires when the lighter runs dry (flint needs your knife and a moment to strike sparks), and a torch in hand lights a laid fire. The miner's *lantern* gives steady light that rain can't put out, for about twelve hours per can of lamp oil (fill it from the pack). Coal burns long.

**The wider world:** east of the creek valley the land climbs through rockier foothills (fewer aspens, more boulders) past a *rock shelter*, then up the ridge to the *fire lookout* (about 450 m of country in all). The rock shelter is dry and a little warmer than outside, somewhere to sleep, and someone left a cache there. At the lookout, E at the ladder climbs the tower, hand over hand: the view pulls back, the whole map fills in, the cab is shelter to sleep in, and the keeper's cupboard holds supplies and the logbook. Don't step off the catwalk.

**Map and journal (M):** the map is the land's profile as you've seen it (unexplored stretches stay blank), with the trailhead, creek, rock shelter, lookout, your camp and structures, a dropped pack, game trails you've crossed, and you. The field journal writes itself the first time things happen or are found: making camp, first snow, the seasons turning, your first deer, the rock shelter, the lookout, and pages left by the last keeper.

**Deer around you:** a small herd is kept around you (fewer in winter): new deer appear out of sight on either side, on that stretch's game trail, and deer that wander 60 m off and out of view leave. A deer you spook leaves the area for good (it keeps going and is gone once out of sight), and none wander in for a while after. Deer keep clear of camps and fires. Wounded deer never leave, so a blood trail always ends at the deer.

**Clothing:** the pack has four clothing slots (Head, Coat, Mitts, Legs). Clothing only warms you when you wear it: drag it onto its slot, or select it and press Wear (what it replaces goes back in the pack). Your own clothes are always on underneath. Buckskin (a coat from 2 tanned hides and cord, leggings from 1) adds about +12 °C: fine for autumn, not enough for a winter night. Real winter gear is fur: a wolf-fur hat, mittens (1 cured wolf fur each) and leggings (2 and cord), and a bear-fur coat (cured bear fur and cord), about +30 °C in all. Overdressed in the warm, you sweat and get thirsty faster. You keep your clothes on when you die.

**Wolves and the bear:** they never come near your camp (a lean-to, cabin or campfire, lit or not) or a torch in your hand. They come for food left out: a carcass, a gut pile, meat on the ground, a rabbit in a snare, and (the bear) bait piles. Ravens circle anything dead by day, a sign for you and for them, and anything left out overnight away from camp is mostly eaten by morning. A wolf pack comes after dark, follows the smell of raw meat you carry, and howls at night. In winter wolves are about all day, come oftener in bigger packs, range twice as wide and howl more; most winter packs are travelling, crossing the country past you, and hunger makes them bolder with a smaller wound. Wolves stalk, spring and bite someone who's hurt or carrying meat after dark (the bear rears and swipes; either knocks you back): face them with a spear or torch and they won't close in, and hurting one scatters the pack. Wolves hunt deer too: a pack creeps in, then rushes, and the deer bolts. Most chases end with the wolves giving up, but deep snow bogs a deer down (far more than it slows a wolf) and a wounded one can't keep ahead. What they pull down they feed on; drive them off it with a torch and there's meat left. In winter you'll also come on old kills: a torn carcass, blood trampled into the snow, wolf tracks all round. *Coyotes* haunt the open country (sage, meadow, desert, canyon, the valley and river bottoms): small, tawny, skittish scavengers that come to anything dead (and a snared rabbit), yip at night and run from you. Skin one for a coyote pelt; cured, it makes a fur hat or mittens as well as wolf fur does. The black bear keeps to the foothills around the rock shelter, and is likelier about (and follows its nose farther) in spring, just out of the den, and in autumn, fattening up. In winter it sleeps in the den in the cave's upper gallery: keep still and dark and it sleeps on, but walking about near it with a torch (let alone running or chopping) rouses it. Woken, it bluffs first and then defends the den for real, but never leaves the gallery, and settles back to sleep once you're gone. Killed in its den, the den stays empty the rest of that winter. Walk up on it (or its food) and it bluff-charges and stops short; come back at it and the next charge is real. An arrow to the chest kills a wolf; the bear takes two. Skin them (knife) for a wolf pelt or bear hide.

**Torch, spear, snares:** at a lit fire, E offers *Light a torch* (uses a stick): it lights the dark for about three hours (less in rain), keeps you out of reach of anything wild, and click waves it to drive them off. It can't go in the pack; putting it away snuffs it. The *spear* (bench, 3 sticks) thrusts at arm's length and a half: it hurts a wolf or the bear, takes a rabbit or an unaware deer, and held toward a predator keeps it at bay. *Snares* (cord and a stick make two) are set from the build menu; rabbits run into them mostly at dawn and dusk. A rabbit left hanging out past camp often gets taken. Rabbits also hop about at dawn and dusk; an arrow takes one.

**Health:** unboiled water, raw or spoiled food can make you sick a few hours later (hunger and thirst drain faster, you tire). An open cut left unbandaged festers into infection and fever; bite wounds especially. Bare hands (and bare legs in deep snow) frostbite while you're freezing; a fire brings them back. All of it comes on slowly with warnings, is treatable, and left alone for a couple of days can kill.

**Wild plants:** yarrow (wounds, infection), wild mint (a sick stomach), willow bark (fever), rose hips (a little food; they last into winter), arnica (sprains), and water hemlock, which looks like yarrow and is deadly. In the dry country prickly pear (fruit) and yucca (fiber that twists into cord like vines); in the old-growth chanterelles (good eating) and fly agaric (poison). Until you've picked a kind it's "an unknown plant" with a description; after that it's named before you gather, so you can leave what you don't want. Most die back in winter.

**Cooking and camp supply:** with the pot hanging over a lit fire, E offers stews (2 meat or fish and 1 berries, rose hips or beans: three hot bowls that warm you and wet your throat) and herb teas (stronger than chewing the herb). Crafting, cooking and blueprints at camp use what's in the pack first, then any storage chest (or the sled's load) nearby: you walk over, rummage, and walk back before the work starts.

**Winter travel:** snowshoes (bench: sticks, a tanned hide, cord; worn on the Feet slot) keep you on top of deep snow. A *sled* (build menu) carries up to four logs, a whole carcass, and a pack-sized load: over snow it runs nearly at a walk, on bare ground it drags. On frozen water chop a hole (E) and fish through it: fish gather under the ice. A blizzard (heavy snow in a hard wind) whites out the valley and its wind cuts through your clothes.

**Fishing waters:** each water has its own fish. The creeks hold cutthroat trout and mountain whitefish; the Sweetwater River whitefish, trout and channel catfish (which feed at night); the marsh pond yellow perch; the Basin Tarn arctic grayling and trout; the Falls Pool big trout. In early autumn the chinook salmon run up the Sweetwater as far as the falls: you'll see them leap, the river bites far faster, and a salmon is a long, hard fight and a lot of meat. Every fish cooks, dries on the rack and smokes in the smokehouse.
- *Fish trap* (6 sticks, cord; placed in any fishing water): a willow basket that catches fish while you're away (up to 3), still alive when you come to check it. A *fish weir* (10 sticks, 2 short logs; across a creek) funnels fish into a trap beside it: about two and a half times the catch. A *gill net* (3 cord, 2 sticks; across the river, a pond, the tarn or the pool) catches twice what a trap does (up to 5), but they're dead in it and start to spoil: check it often. Nothing's caught while the water's frozen.
- *Fish spear* (workbench: 2 sticks, cord): a three-pronged leister. Hold it (or the hunting spear) at the water's edge and fish show as shadows in the shallows; click right where one is to spear it.
- *Ice auger*: leaning on the post at the trapper's camp. It bores a hole in the ice in a moment (the hatchet takes a while) and the hole stays open about 20 hours instead of 8.

**Keeping food:** food keeps longer in the cold: in a chest, cache or bear bag it lasts about twice as long near freezing and freezes solid below it. The root cellar's shelves (once you've searched them) stay cool all year: food there lasts about three times as long, and nothing gets in. Food left in a chest away from camp gets raided: in the bear's country (outside winter) the bear tears in and takes all of it; anywhere else mice and packrats get into some. Keep it up off the ground:
- *Raised cache* (2 long logs, 3 medium, 2 short, 6 sticks): a roofed box on tall tin-banded posts. E at the ladder climbs up; stand on the deck and E opens it; climb down, or hop off with S. Never raided.
- *Bear bag* (a tanned hide and cord, placed on a tall standing tree): a rope thrown over a high branch, the bag hauled up and tied off round the trunk. The rope and bag are simulated, so the bag dangles, sways and swings out in a gale. At the trunk, lower it (it comes down to you), open it, haul it back up. Up high nothing gets it; left on the ground it's fair game, and if you fell its tree the bag comes down too.
- *Smokehouse* (3 medium logs, 4 short, 4 sticks): hang up to 12 raw venison, rabbit, trout or whitefish and keep its smudge fire fed with sticks (a stick smokes 3 hours). About ten hours of smoke makes smoked meat or fish that keeps over a month, in any weather; smoke drifts from the roof vent while it's going.

**Sound of the country:** every biome sounds like itself, from real recordings: woodland birds and woodpeckers in the valley, ducks and cottonwoods on the river, frogs in the marsh at night, meadowlarks and coyotes on the sage, heat, cicadas and a hawk's scream in the desert, a canyon wren and bats off the canyon walls, jays and squirrels in the foothills, wind roaring on the ridge and alpine (marmots and pikas in summer, ice cracking on the tarn in winter), rockfall in the boulders, a hushed old-growth of drips, creaking giants and varied thrushes, flickers, quaking aspens and (in autumn) bugling elk in the grove. Walking between them the sounds blend. Seasons change it all: birds loudest in spring and sparse in winter, insects and frogs only when it's warm, geese going over in spring and autumn. The falls drown everything near them, and canyons and caves echo (your own sounds too). Chopping, the tree falling, the wolves and the bear are real recordings.

**Settings (Esc, Settings):** volume for everything, music, sounds, ambience, and rain and wind; hints on or off; rebind any key (click, press). Music is rare and quiet: some nightfalls and dawns, a storm building, and the lights.

**First days:** a small checklist top-left (sticks, a fire, a lean-to, boiled water, food, a workbench) ticks off as you go and goes away when it's done.

**Build book (B) and recipe book (E at a workbench, or from the pack):** both open as a book, paused. Chapters down the left page; the right page shows a picture of the thing, what it's for, each thing it takes as have / need (pack items, chests close by, and logs lying nearby for builds) and, for anything you're short of, where to get it. The button at the bottom places the blueprint or makes the item (bench recipes need a workbench close by).

**Workbench, tools, storage:** a *workbench* (2 medium logs, 2 sticks) is needed for the bigger crafting: bow, arrows, spear, clothing, deer call (E at the bench opens the recipe book). Quick things (vine cord, splint, fishing pole) work anywhere. Tools dull as you use them and their handles wear: a worn tool works slower but never breaks. Select the hatchet or knife in the pack to *sharpen* it on a whetstone (two lie on the creek banks; ~30 sharpenings each), or to *repair the handle* with 2 sticks at the workbench. A *storage chest* (1 medium log, 3 sticks) opens beside the pack: drag between them, or use Move to chest / Move to pack.

**Wind, trails, bait, calls:** the wind has a direction (arrow, bottom right): it blows up the valley toward the ridge by day and back down at night, turning around 9:00 and 19:00, and a passing front can reverse it. It carries your scent: a deer downwind smells you from 8-17 m depending on the wind, blind or no blind, so come at deer from downwind. Each part of the valley has a game trail, a worn path between bedding cover and a feeding ground; deer bed there by day and walk it at dawn and dusk. A *bait pile* (4 berries, via B) draws active deer within 26 m to feed until it's eaten or goes off in two days. A *deer call* (bench, 1 stick) bleats: curious deer walk toward you, but a third call in a short while makes them wary.

**Vines and cord:** vine tangles trail over the ground (they grow back in a season). Three vines (or yucca fiber) twist into vine cord in the backpack. Recipes ask for "cord" (paracord or vine cord: bow, hide coat) or "line" (line & hooks, or vine cord with a carved hook: fishing pole).

**Chopping:** every blow sounds, throws chips and bites a deeper notch on your side of the trunk; the tree creaks, rushes down and crashes. The chop and fall sounds are synthesized (`tools/synth_audio.py`).

**Hunting:** creep up behind a grazing deer that hasn't noticed you (or one looking away) and click with the knife to take it outright; if it's seen you, the knife cuts it as it bolts and it bleeds, so follow the blood. The knife always strikes, and also fights off a wolf or the bear at close quarters. From range, craft a bow (3 sticks + the paracord in your kit) and arrows (2 sticks make 4) in the backpack. Press and pull the mouse back like a slingshot: the farther you pull, the harder the shot, and a dotted line shows the whole flight with a ring where it comes down. The arrow strikes the first part of the animal its path touches, so a deer facing you (or an arrow dropping onto the front of its back) takes it in the chest, and one facing away is hit in the haunch: a chest or head hit drops the deer within a few seconds, anything else wounds it and it runs longer, leaving blood drops you can follow and examine (E). Missed arrows usually survive in the dirt. At the carcass, E offers two choices. *Butcher it here* (knife): the hide and as many of its 6 cuts of venison as fit go straight into your pack, and the rest wait on the carcass for you to come back for. It leaves a gut pile that draws wolves. Or *drag it* home whole (F lets go): slow, hard going, but nothing is left behind to draw them, and at camp it's safe. Venison spoils from the moment of the kill; cook it at a fire or dry it on the rack.

**First camp:** gather fallen sticks (E), press B to place a campfire blueprint and deliver 3 sticks, build it, then light it with E. For a lean-to, fell a tree with the hatchet, strip its branches, cut 2 long and 4 medium logs at the marks, and haul them to a lean-to blueprint. To make water safe, fill the cook pot at the creek, set it on a lit fire until it boils, take it back, and pour it into your bottle from the backpack.

## Checks
```bash
godot --headless --import                 # parse and import check
godot --headless -s tests/run.gd          # unit tests (exit code = failure count)
godot --headless --quit-after 600         # smoke run
godot --headless -- --tour                # walk every chunk and back, verify streaming
godot --headless --fixed-fps 60 -- --scenario   # full camp loop end to end (~3 min)
godot --fixed-fps 60 --resolution 1280x720 -- --scenario   # same, windowed: only this catches UI eating clicks
# Any run with flags after `--` saves to user://test_saves, never to the player's user://saves.
godot --headless --fixed-fps 60 -- --scenario=life                # sleep, autosave, save slot 3, die, respawn, recover
godot --headless --fixed-fps 60 -- --load=3 --scenario=verify     # then cold-load slot 3 and check it matches
godot --headless --fixed-fps 60 -- --scenario=wild                # deer senses, tracks, fishing, cooking, birds, hunting
godot --headless --fixed-fps 60 -- --scenario=winter              # woodpile, seasons, snow, tracks in snow, frozen creek, camp builds
godot --headless --fixed-fps 60 -- --scenario=world               # foothills, rock shelter, lookout, map, journal, the herd
godot --headless --fixed-fps 60 -- --scenario=predators           # choices, torch, wolves, bear, spear, butchering, snares, clothing
godot --headless --fixed-fps 60 -- --scenario=frontier            # the wider world: waters, sites, bridge, flares, the lights
godot --headless --fixed-fps 60 -- --scenario=health              # sickness, infection, frostbite, plants, stews, chests, winter travel, settings
godot --headless --fixed-fps 60 -- --scenario=under               # cellar, cave, mine, drop-through, the dark, flint, finds, springs, falls, regrowth
godot --headless --fixed-fps 60 -- --scenario=fish                # fish per water, the salmon run, traps, weir, net, fish spear, ice auger
godot --headless --fixed-fps 60 -- --scenario=hunts               # wolves run down deer (or give up), kill sites, coyotes
godot --headless --fixed-fps 60 -- --scenario=stores              # cellar shelves, raids, raised cache, bear bag physics, smokehouse
godot --headless --fixed-fps 60 -- --scenario=weather             # thunderstorms, lightning fires, chinooks, fog, floods, stepping stones, thin ice, breakup, barometer
godot --headless --fixed-fps 60 -- --scenario=sounds              # every biome sounds like itself; blending, seasons, echo, calls
godot --fixed-fps 60 -- --scenario=icons                          # (windowed) re-render the build book's pictures into assets/builds/ after changing a build's art
godot -- --x=9000 --hour=22 --wolves=torch --shot=out.png          # previews: --wolves[=torch] --bear[=0|1|2] --wear[=buckskin] --choices --attack[=bear] --climb --buildmenu --under=cellar|cave|mine[:x[:y]] [--lamp=1] [--den=1] --throw --recipes[=id] --buildmenu[=id] --stores[=wind] --chase --fishgear --thunder --fog[=0..1] --flood[=0..1] --chinook --baro
godot -- --hour=19.5 --weather=rain --x=13500 --shot=out.png   # screenshot a scenario
```
Other debug flags (after `--`): `--walk=1|-1`, `--run`, `--zoom=Z`, `--debug`, `--camp` (finished camp nearby), `--sleep`, `--pack`, `--menu`, `--deer`, `--flee`, `--fish`, `--load=SLOT`.

## Layout
- `game/core/`: pure rules with no nodes (clock, weather, condition, tuning). All unit-tested.
- `game/world/`: terrain, streamed chunks, parallax backdrop, atmosphere, ambience, rain.
- `game/player/`: movement (`player.gd`), procedural rig (`player_rig.gd`), camera, footsteps.
- `game/wildlife/`: generic `Animal` brain, species data (`data/species/*.tres`), deer rig, spawner, birds, tracks.
- `game/fishing/`: `FishFight` minigame rules (unit-tested), session, reel meter.
- `game/art/`: palette and procedural placeholder art.
- `data/tuning.tres`: every balance number. Edit this, not the code.
- `assets/`: audio, plus `ASSET_MANIFEST.md` (sources, licences, what's temporary).
- `docs/art/`: the player reference and image-generation prompts.

## Extending
- **New tuning value:** add an `@export` to `game/core/tuning.gd`, then read it via `GameClock.tuning`.
- **New animal:** add a `SpeciesDef` .tres (senses, speeds, flee distance, herd size, active hours), add it to `Wildlife.SPECIES`, and give it a rig. No behaviour code changes needed.
- **New fish:** add an entry to `FishFight.SPECIES` (sweep speed, zone, strikes, drift, runs) plus raw and cooked items.
- **New ambience sound:** add the recording to `assets/audio/src/`, a line in `tools/process_audio.py` (LOOPS or SHOTS) and run it; a loop needs `edit/loop_mode=2` in its `.import`. Then use it in a biome's entry in `Ambience.PROFILES` (a bed under day/dusk/night/wind, or a call).
- **World scale:** 100 px = 1 m; chunks are 60 m wide. Only the current chunk and its neighbours exist at a time.
