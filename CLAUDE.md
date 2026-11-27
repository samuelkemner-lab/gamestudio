# Studio Grind – instructies voor Claude

Studio-producer-sim à la Schedule I, gebouwd in **Godot 4.4 (GDScript, Forward+)**.
Eigenaar: Sam. Sam beslist over design en look; Claude bouwt, test en commit.
Volledig design: Claude Doc "Game Design Document – Studio Producer Sim".

## Kernconcept
- Speler = wannabe SoundCloud-producer (niet uit de hood) in een slaapkamer in een flat, fictieve stad à la Rotterdam.
- Loop: rapper boeken → opnemen in booth → beat maken/mixen in **LOOPR** (nep-DAW) → rating van rapper = sessiegeld → release = streams → upgraden.
- Toon: realistisch beats maken en mixen, met grappige rappers en chaos-events.
- Taal in de game: Engels, met NL-flavour.
- Look: low-poly cartoon, neon nacht (paars/blauwe LED's).

## Vaste keuzes
- First-person nu; third-person (wisselbaar) komt later.
- 3 rappers in v1: drill-gangster, autotune-sadboy, boom bap-oldhead. Elk met eigen geduld (takes maken ze bozer).
- Stats: geld, reputatie, Street Cred.
- LOOPR v1: step sequencer, mixer, piano roll en playlist. Bouwvolgorde: sequencer + mixer → piano roll → playlist.
- Moeilijkheid kiesbaar: Easy/Pro.
- Chaos: buren → politie, beef in de studio, leaks, pc-crash.

## Art direction
Lees **docs/ART_DIRECTION.md** (de masterprompt) vóór elke visuele taak en toets elke screenshot aan de checklist daarin.

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
- `assets/shaders/night_building.gdshader`: Kenney-gebouwen 's nachts (donkere gevels, willekeurig verlichte ramen)
- `tools/inspect_scene.gd`, `tools/contact_sheet.gd`: maten en materialen van modellen bekijken
- `scripts/player.gd`: first-person controller, [E] interactie via de `interact`-meta
- `scripts/rappers.gd`: rapperdata (smaak, feel, mix, geduld, brief, teksten); `scripts/judge.gd`: score 0–100 (BPM 20, drums 25, melodie 15, signature 15, feel 10, mix 15, clipping −6) → sterren + beloning
- `scripts/session.gd`: sessie-state machine (ARRIVING → WAITING → RECORDING → REVIEW → LEAVING)
- `scripts/npc.gd`: Kenney Mini Character + accessoires, lopen, animaties, tekstballon, brabbelstem (`voice_synth.gd`)
- `scripts/chaos.gd`: geluidsmeter → buren → politie; `scripts/game_state.gd`: geld/rep/cred + save (user://)
- `scripts/phone_ui.gd`, `scripts/results_ui.gd`, `scripts/ui_kit.gd`: telefoon, resultaten, gedeelde UI-stijl
- `assets/models/quaternius_characters`: CC0-personages met normale verhoudingen (Quaternius Ultimate Modular). Armature heeft schaal 100: props in een 0.01-holder onder een BoneAttachment3D. Animaties heten `CharacterArmature|Idle_Neutral`, `|Walk`, `|Wave`, enz. Bron-GLB's staan in Git LFS: ophalen via media.githubusercontent.com
- `scripts/city_builder.gd` (extends RoomBuilder): de buitenwereld **Zuidkade**, ver weg geplaatst (`main.CITY_ORIGIN`). Hoofdstraat langs X, zijstraat naar de kade (Maas, brug, skyline). Winkels via `SHOPS` + `_storefront()`; de deur is een StaticBody met meta `interact = "shop"` en `shop_id`. Verkeer (`_drive`, remt voor de speler), voetgangers (NPC-loops), onzichtbare grenswanden. Let op: `look_at_from_position` werkt met globale coördinaten; gebruik lokale transforms
- `scripts/city_ui.gd`: winkelpanelen (Wax & Wires = shopitems tegen cashprijs −15%, Groene Wolk, Snackbar De Hoek, Nachtwinkel, Lucky Stack-casino, Maas Sound = toekomstige progressie); `scripts/casino.gd`: slots (~87,5% terug) en roulette, pure logica
- Reizen: kamerdeur (`door_out`) ↔ deur Kade 17 (`shop_id = home`) via `main.travel()`; kamer en stad worden om en om verborgen/gepauzeerd. Niet weg tijdens een sessie, niet boeken vanaf straat
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
