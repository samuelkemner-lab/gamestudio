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
- `assets/models/kenney_furniture`, `assets/models/kenney_city`: CC0-modellen (zie CREDITS.md)
- `assets/shaders/night_building.gdshader`: Kenney-gebouwen 's nachts (donkere gevels, willekeurig verlichte ramen)
- `tools/inspect_scene.gd`, `tools/contact_sheet.gd`: maten en materialen van modellen bekijken
- `scripts/player.gd`: first-person controller, [E] interactie via de `interact`-meta
- `scripts/rappers.gd`: rapperdata (smaak, geduld, brief, teksten); `scripts/judge.gd`: score 0–100 → sterren + beloning
- `scripts/session.gd`: sessie-state machine (ARRIVING → WAITING → RECORDING → REVIEW → LEAVING)
- `scripts/npc.gd`: Kenney Mini Character + accessoires, lopen, animaties, tekstballon, brabbelstem (`voice_synth.gd`)
- `scripts/chaos.gd`: geluidsmeter → buren → politie; `scripts/game_state.gd`: geld/rep/cred + save (user://)
- `scripts/phone_ui.gd`, `scripts/results_ui.gd`, `scripts/ui_kit.gd`: telefoon, resultaten, gedeelde UI-stijl
- `assets/models/quaternius_characters`: CC0-personages met normale verhoudingen (Quaternius Ultimate Modular). Armature heeft schaal 100: props in een 0.01-holder onder een BoneAttachment3D. Animaties heten `CharacterArmature|Idle_Neutral`, `|Walk`, `|Wave`, enz. Bron-GLB's staan in Git LFS: ophalen via media.githubusercontent.com
- `scripts/shop.gd`: shop-items (upgrades, kits, instrumenten); `room_builder.apply_upgrades()` maakt ze zichtbaar in de kamer
- Dagcyclus: 1 echte seconde = 1 game-minuut, om 06:00 val je in slaap; `game_state.sleep()` berekent streams, inkomsten en leaks
- `scripts/sequencer.gd`: audiokern (16 stappen, melodie, kits, instrumenten, een audio-bus per spoor, mixer-API, save/restore)
- `scripts/loopr_ui.gd`: LOOPR-interface (Channel Rack, Piano Roll, Mixer, SAVE, crash-scherm)
- `tests/run_tests.gd`: headless smoke tests
- `tests/screenshot.gd`: screenshots voor visuele checks

## Testen
```
godot --headless --path . -s tests/run_tests.gd        # moet RESULT: PASS geven
xvfb-run -a godot --path . --rendering-driver vulkan -s tests/screenshot.gd -- /tmp   # vereist mesa-vulkan-drivers (lavapipe)
```
