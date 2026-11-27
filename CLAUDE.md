# Studio Grind – instructies voor Claude

Studio-producer-sim à la Schedule I, gebouwd in **Godot 4.4 (GDScript, GL Compatibility)**.
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

## Regels
- Geen FL Studio-naam, -logo of -interface kopiëren. De DAW heet LOOPR en heeft een eigen look.
- Alleen eigen of commercieel gelicenseerde audio. Placeholder-drums worden in code gegenereerd (`scripts/drum_synth.gd`).
- Geen betaalde diensten (zoals AI-stemmen) zonder akkoord van Sam en een kostenoverzicht.
- Gratis assets: Kenney.nl en Quaternius (CC0).
- Kleine stappen: na elke stap tests draaien en committen.

## Structuur
- `scenes/main.tscn` → `scripts/main.gd`: wereld (greybox), HUD, openen en sluiten van LOOPR
- `scripts/player.gd`: first-person controller, [E] interactie via de `interact`-meta
- `scripts/sequencer.gd`: audiokern (16 stappen, een audio-bus per spoor, mixer-API)
- `scripts/loopr_ui.gd`: LOOPR-interface (Channel Rack + Mixer)
- `tests/run_tests.gd`: headless smoke tests
- `tests/screenshot.gd`: screenshots voor visuele checks

## Testen
```
godot --headless --path . -s tests/run_tests.gd        # moet RESULT: PASS geven
xvfb-run -a godot --path . --rendering-driver opengl3 -s tests/screenshot.gd -- /tmp
```
