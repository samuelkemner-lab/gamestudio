# Studio Grind (prototype v0.2)

Een studio-producer-sim: je begint als wannabe SoundCloud-producer in je slaapkamer en bouwt beats in **LOOPR**.

## Spelen (Windows)
1. Download **Godot 4.4.1** (standaardversie, niet .NET): https://godotengine.org/download/archive/4.4.1-stable/
2. Download deze repo: groene knop **Code → Download ZIP**, en pak de ZIP uit.
3. Start Godot, klik **Import** en kies `project.godot` uit de uitgepakte map.
4. Druk op **F5** (of de ▶-knop rechtsboven).

## Besturing
| Toets | Actie |
| --- | --- |
| WASD + muis | Lopen en rondkijken |
| E | Interactie (kijk naar de monitor om LOOPR te openen) |
| SPATIE | Beat afspelen/stoppen (in LOOPR) |
| ESC | LOOPR sluiten / muis vrijgeven |

Vereist een videokaart met Vulkan-ondersteuning; dat heeft vrijwel elke pc van na 2016.

## In v0.2
- Uitgewerkte neon-slaapkamerstudio volgens `docs/ART_DIRECTION.md`: echte schaduwen, maanlicht door het raam, skyline, bureaulamp, booth-hoek en veel props
- De monitor toont LOOPR live
- LOOPR Channel Rack: 16-stappen sequencer met kick, snare, hi-hat, clap en 808; BPM 60–200; demo-beat
- LOOPR Mixer: fader en mute per spoor, plus master
- De drumgeluiden zijn tijdelijke placeholders, in code gegenereerd
