# Studio Grind – instructies voor Claude

Studio-producer-sim à la Schedule I, gebouwd in **Godot 4.4 (GDScript, Forward+)**.
Eigenaar: Sam. Sam beslist over design en look; Claude bouwt, test en commit.
Volledig design: Claude Doc "Game Design Document – Studio Producer Sim".

## Kernconcept
- Speler = wannabe SoundCloud-producer (niet uit de hood) in een slaapkamer in een flat, fictieve stad à la Rotterdam.
- Loop: rapper boeken → opnemen in booth → beat maken/mixen in **LOOPR** (nep-DAW) → rating van rapper = sessiegeld → release = streams → upgraden.
- Toon: realistisch beats maken en mixen, met grappige rappers en chaos-events.
- Taal in de game: Engels, met NL-flavour.
- Look: grounded stylized realism (simpele vormen, realistisch licht, PBR-materialen op grote vlakken, natte nacht in Rotterdam), neon als accent.

## Vaste keuzes
- First-person nu; third-person (wisselbaar) komt later.
- 3 rappers in v1: drill-gangster, autotune-sadboy, boom bap-oldhead. Elk met eigen geduld (takes maken ze bozer).
- Stats: geld, reputatie, Street Cred.
- LOOPR v1: step sequencer, mixer, piano roll en playlist. Bouwvolgorde: sequencer + mixer → piano roll → playlist.
- Moeilijkheid kiesbaar: Easy/Pro.
- Chaos: buren → politie, beef in de studio, leaks, pc-crash.

## Art direction
Lees **docs/ART_DIRECTION.md** (de masterprompt) vóór elke visuele taak en toets elke screenshot aan de checklist daarin.
Lees ook **docs/REALISM_MASTERPROMPT.md** (realisme 2.0). Bij een conflict wint dat document. Bouw volgens de fases R1–R6 daarin.

## LOOPR (de DAW)
Lees **docs/LOOPR_DAW_MASTERPROMPT.md** vóór elke taak aan LOOPR. Richting: BandLab-achtige werking (sporen, regions op een tijdlijn, editors in een dock), met eigen LOOPR-identiteit. Geen BandLab-namen, -logo of pixelkopie. Bouw volgens de fases F1–F6 daarin.

## Regels
- Geen FL Studio-naam, -logo of -interface kopiëren. De DAW heet LOOPR en heeft een eigen look.
- Alleen eigen of commercieel gelicenseerde audio. Placeholder-drums worden in code gegenereerd (`scripts/drum_synth.gd`).
- Geen betaalde diensten (zoals AI-stemmen) zonder akkoord van Sam en een kostenoverzicht.
- Gratis assets: Kenney.nl en Quaternius (CC0). Kenney-sites zijn hier geblokkeerd; CC0-kits zijn op te halen uit openbare GitHub-repo's (sparse checkout), altijd met licentiecheck. Credits bijwerken in CREDITS.md.
- Kenney-meubels: schaal ~2.0 (`S`), materialen herkleuren via de `remap`-dictionary (namen: wood, woodDark, metal, metalMedium, metalDark, carpet, carpetDarker, carpetWhite, plant, lamp, glass).
- Kleine stappen: na elke stap tests draaien en committen.

## Structuur
- `scenes/main.tscn` → `scripts/main.gd`: titelscherm, HUD met interactie-prompt, monitor-SubViewport (LOOPR live op scherm), openen en sluiten van LOOPR
- `scripts/room_builder.gd`: de slaapkamerstudio. Kenney-modellen via `kit()` (gecentreerd, geschaald, herkleurd met het nachtpalet), eigen props, licht, stofdeeltjes en skyline
- `assets/models/kenney_furniture`, `kenney_city`, `kenney_roads`, `kenney_cars`, `kenney_retro_urban`: CC0-modellen (zie CREDITS.md). Bron voor extra Kenney-kits: github.com/Tiddybub/3d-assets (sparse checkout, `Models/GLB format`)
- `assets/shaders/night_building.gdshader`: Kenney-gebouwen 's nachts (achtergrondrijen; `per_building` = raamraster per gebouw)
- Realisme (docs/REALISM_MASTERPROMPT.md):
  - R1: buiten heeft een eigen `city.city_env` (AgX, SDFGI, SSR, auto-exposure, LUT, fog) die `main._set_city_active()` wisselt met `room.room_env`; F9 = kwaliteit Low/High; TAA aan
  - R2: `assets/materials/<set>` (ambientCG 1K: Color/NormalGL/Roughness) via `city.pbr()` en `assets/shaders/wet_surface.gdshader` (world-space, `wetness`, plassen, `rain`-rimpels); `scripts/decal_kit.gd` = procedurele decals; `assets/shaders/kenney_tint.gdshader` = Kenney desatureren
  - R3: gevels in `city_builder._facades()` (`NORTH_ROW`/`SOUTH_ROW`, stijlen `FACADE_STYLES`), ramen + kozijnen in MultiMeshes, `assets/shaders/interior_window.gdshader` (nep-kamers via interior mapping, INSTANCE_CUSTOM = seed)
  - R4/R5: `HOURS` + rolluiken (`update_hours`), weer per nacht (`game_state.weather`, `city.apply_weather`), tram/rails/bovenleiding, verkeerslicht, rokers, herkenning bij ≥10 REP, `scripts/ambience_synth.gd` (regen, stad, water, trambel)
  - Screenshots met SDFGI zijn traag op lavapipe (±3 min per shot): render losse views met `tests/screenshot.gd -- <dir> city_street city_shops ...`
- Skyline over de Maas: `scripts/rotterdam_skyline.gd` (`RotterdamSkyline.build()` vanuit `city_builder._quay_and_river()`): zwanenbrug (`BRIDGE_X`, `PYLON_Z`), uitkijktoren in het park, markthal-boog, kubuswoningen + potlood, "Manhattan aan de Maas"-cluster, ledgevel-toren, rood gestreepte toren, verre oever met lampen en reflecties. Gevels via `assets/shaders/skyline_tower.gdshader` (object-space ramenraster, `bands`, `led_grid`). Herkenbare silhouetten, maar geen echte namen of logo's in de game. Depth-fog in `city_env` voor waas op afstand
- OV (v0.12):
  - `scripts/transit.gd` (Transit extends RoomBuilder, op `main.METRO_ORIGIN`): één perron dat per station wordt aangekleed (`dress()`). Trein-cyclus `state` away/arriving (cruise + rem)/dwell/departing. Ritten via `board_metro()`/`board_tram()`, `_ride_update()` (speler zit vast met `player.pose_lock`, positie volgt de stoel), wissel onder `main.fade_through()`; `skip_ride()` voor tests.
  - Zwartrijden: `main._checkin_menu()` → `_board(kind, dest, checked_in)`; `Transit.INSPECT_CHANCE`, `_roll_inspection()` (bij de wissel), `_maybe_inspect()` zet een controleur-NPC (`Rappers.INSPECTOR`, accessoire "inspector") in het voertuig en `ride.hold` (deuren blijven open); `main.inspection()`/`_resolve_inspection()` (pay/excuse/run), `run_from_inspector()` bij uitstappen; `force_inspection` voor tests.
  - Tram 4: `CityBuilder._tram(stop_x, ...)` + `_tram_stop()` (remmen, deuren, `board`-body alleen actief tijdens de stop). Holle wagons via `RoomBuilder.carriage()`/`set_doors()`.
  - Wijken: `scripts/district_builder.gd` (DistrictBuilder extends CityBuilder; centraal/markt/haven op `main.DISTRICT_ORIGINS`), hergebruikt `_facade`, `_storefront`, `_tram`, `_metro_entrance`, `_tram_shelter`. Interactables in `features`; deuren met meta `builder`.
  - main: `area` (room/zuidkade/centraal/markt/haven/metro), `_activate_area()` (zichtbaarheid, processing, env, weer, audio), `enter_metro()`/`exit_metro()`, `_ride_menu()`, `_board()`, `_district_shop()`, `busk()`, `_club()`.
- Straatleven (v0.13):
  - `scripts/vitals.gd` (Vitals, puur statisch): `ITEMS`, `HOTBAR` (toetsen 1–6), `use()`, `eat()`, `coffee()`, `tick()` (elke game-minuut vanuit `main._vitals_tick`), `mods()` → snelheid, zwalken, tint, lowpass (toegepast in `main._apply_vitals`). State in `game_state.energy`/`effects`/`items`/`night`. `main.use_item()`, `scratch_card()`, `toggle_umbrella()` (U).
  - `scripts/fishing.gd` (Fishing): dobber, `cast()`/`strike()` (E in houding "fish"), `roll()` = buittabel; plekken via `CityBuilder._fishing_spots()` (meta `interact = "fish"`). Vis verkopen in de snackbar (`CityUI.sell_fish`).
  - `scripts/style.gd` (Style): `CLOTHES` (slot head/top/neck/feet), `CUTS`, `drip()`, `buy_or_wear()`, `haircut()`, `pay_mult()`; state `game_state.clothes`/`outfit`. Winkels `barber`/`drip` op de Marktplein (`main._district_shop`, `_drip_menu`); bouncer-check `CLUB_MIN` in `_district_shop("club")`.
  - `scripts/time_trial.gd` (TimeTrial, kind van city): `START`, `GATES`, `RIVALS`; rollende start, signalen started/gate_passed/finished/aborted; `result()` betaalt rivalen één keer, `game_state.records.trial_best`.
  - `scripts/arcade_ui.gd` (ArcadeUI): BEAT DROP, `chart(seed)`, `grade()`, `hit(lane)`, `TABLE`, `result()` → `records.arcade_high`. Geopend via de snackbar (`CityUI.arcade_requested` → `main.play_arcade()`).
  - Toetsen worden in `main._input` afgehandeld (1–6 item/menukeuze/pattern, U, E bij het vissen, ESC sluit menu's).
- `tools/inspect_scene.gd`, `tools/contact_sheet.gd`: maten en materialen van modellen bekijken
- `scripts/player.gd`: first-person controller, [E] interactie via de `interact`-meta. Houdingen `Posture` STAND/CROUCH/PRONE (Ctrl/C, Z), sprint, `surface`-voetstappen, zaklamp (F), `enter_pose("seat"|"bed")`/`leave_pose()`, oppakken/gooien van RigidBodies met meta `interact = "grab"`; signaal `interact_empty` (E op niets, bv. in bed = slapen)
- v0.9 details: `scripts/props.gd` (physics-props), `scripts/street_talk.gd` (alle straatteksten per persona + geheugen), `scripts/talk_ui.gd` (gespreksmenu, toetsen 1–4), `scripts/street_cat.gd`, `scripts/pigeon_flock.gd`. NPC's hebben `display_name`, `memory`, een StaticBody `body` met meta `interact = "npc"` en `npc = self`; reacties in `city_builder._reactions()`. Backlog met onderzochte ideeën: docs/DETAILS_BACKLOG.md
- `scripts/rappers.gd`: rapperdata (smaak, feel, mix, geduld, brief, teksten); `scripts/judge.gd`: score 0–100 (BPM 20, drums 25, melodie 15, signature 15, feel 10, mix 15, clipping −6) → sterren + beloning
- `scripts/session.gd`: sessie-state machine (ARRIVING → WAITING → RECORDING → REVIEW → LEAVING)
- `scripts/npc.gd`: Kenney Mini Character + accessoires, lopen, animaties, tekstballon, brabbelstem (`voice_synth.gd`)
- `scripts/chaos.gd`: geluidsmeter → buren → politie; `scripts/game_state.gd`: geld/rep/cred + save (user://)
- `scripts/phone_ui.gd` (GRIND OS: `APPS`, `open_app()`, `open_thread()`, app-iconen via de inner class `AppIcon`), `scripts/call_ui.gd` (inkomende oproep, Y/N, gemist na 15 s), `scripts/results_ui.gd`, `scripts/ui_kit.gd`: telefoon, resultaten, gedeelde UI-stijl
- Progressie (docs/PROGRESSION_MASTERPLAN.md, fases P1–P6):
  - `game_state`: `inbox`/`message()`/`nightly_messages()`, `call_log`, `pending` (rapper onderweg, deadline), `furniture`/`placed`, `estep`, `deliveries`.
  - main: `_maybe_call()`, `_set_pending()`/`_check_pending()`, Zoef (`_on_zoef`, `_zoef_update`, `complete_delivery`), step (`_spawn_step`, `_leave_city`).
  - `scripts/furniture.gd`: catalogus, slots en stats (VIBE/AKOESTIEK/COMFORT) met effecten in session, chaos en `dawn_minutes`; `room_builder.apply_furniture()`.
  - `scripts/estep.gd`: e-step; rijden in `player._ride()`, `mount()`/`dismount()`, signaal `crashed`.
  - P5: `scripts/goals.gd` (`LIST`, `progress()`, `active()`), `game_state.check_goals()` (elke game-minuut vanuit main), `xp`/`level()`/`add_xp()` (signaal `leveled`), `streak`/`streak_mult()`, `RENT` in `sleep()`, `plaques()` → `room_builder.apply_plaques()`.
- `assets/models/quaternius_characters`: CC0-personages met normale verhoudingen (Quaternius Ultimate Modular). Armature heeft schaal 100: props in een 0.01-holder onder een BoneAttachment3D. Animaties heten `CharacterArmature|Idle_Neutral`, `|Walk`, `|Wave`, enz. Bron-GLB's staan in Git LFS: ophalen via media.githubusercontent.com
- `scripts/city_builder.gd` (extends RoomBuilder): de buitenwereld **Zuidkade**, ver weg geplaatst (`main.CITY_ORIGIN`). Hoofdstraat langs X, zijstraat naar de kade (Maas, brug, skyline). Winkels via `SHOPS` + `_storefront()`; de deur is een StaticBody met meta `interact = "shop"` en `shop_id`. Verkeer (`_drive`, remt voor de speler), voetgangers (NPC-loops), onzichtbare grenswanden. Let op: `look_at_from_position` werkt met globale coördinaten; gebruik lokale transforms
- `scripts/city_ui.gd`: winkelpanelen (Wax & Wires = shopitems tegen cashprijs −15%, Groene Wolk, Snackbar De Hoek, Nachtwinkel, Lucky Stack-casino, Maas Sound = toekomstige progressie); `scripts/casino.gd`: slots (~87,5% terug) en roulette, pure logica
- Reizen: kamerdeur (`door_out`) ↔ deur Kade 17 (`shop_id = home`) via `main.travel()`; alleen het huidige gebied is zichtbaar/actief (`_activate_area`). Niet weg tijdens een sessie; uitnodigen vanaf straat = rapper komt over 40 min (`pending`)
- Buffs in `game_state.buffs`: `chill` (+1 take bij volgende rapper), `awake` (minuten langer op, `dawn_minutes()`), `gift` (buren: noise reset, 30% trager)
- `scripts/shop.gd`: shop-items (upgrades, kits, instrumenten); `room_builder.apply_upgrades()` maakt ze zichtbaar in de kamer
- Dagcyclus: 1 echte seconde = 1 game-minuut, om 06:00 val je in slaap; `game_state.sleep()` berekent streams, inkomsten en leaks
- `scripts/sequencer.gd`: audiokern. 4 patterns (A–D) met drums + velocity + rolls + melodie + 808-toonhoogte, playlist van 8 maten (PAT/SONG), swing, glide, undo, scheduler voor rolls/swing. Per bus: lo-cut, reverb, pan; mute/solo. Deterministisch levelmodel (`step_peak`, `peak_db`) voor meters, clip-waarschuwing en judge
- `scripts/loopr_ui.gd`: LOOPR-interface (Channel Rack met tools, Piano Roll met Melody/808-lane, Playlist, Mixer, SAVE, crash-scherm)
- `scripts/loopr_grid.gd`: zelfgetekend grid met sleep-tekenen (rack, piano roll, playlist); `scripts/loopr_meter.gd`: level meter
- `tests/run_tests.gd`: headless smoke tests
- `tests/screenshot.gd`: screenshots voor visuele checks

## Testen
```
godot --headless --path . -s tests/run_tests.gd        # moet RESULT: PASS geven
xvfb-run -a godot --path . --rendering-driver vulkan -s tests/screenshot.gd -- /tmp   # vereist mesa-vulkan-drivers (lavapipe)
```
