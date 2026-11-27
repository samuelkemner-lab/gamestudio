# Studio Grind (prototype v0.5)

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
| E | Interactie: monitor = LOOPR, microfoon = praat met de rapper, bed = slapen (nacht afsluiten) |
| TAB | Telefoon: DM's (boeken), Shop, Tracks (streams), hints Easy/Pro |
| Ctrl+S | Project opslaan in LOOPR (beschermt tegen een pc-crash) |
| SPATIE | Beat afspelen/stoppen (in LOOPR) |
| ESC | LOOPR sluiten / muis vrijgeven |

Vereist een videokaart met Vulkan-ondersteuning; dat heeft vrijwel elke pc van na 2016.

## Zo speel je een sessie
1. Druk **TAB** en boek een rapper (Big Earl en Lil Tear zijn open; Ghost unlock je met 8 Street Cred, Spike met 12 reputatie. Elke rapper kan één keer per nacht).
2. De rapper loopt binnen en gaat in de booth staan.
3. Ga achter de pc (**E**) en maak in LOOPR een beat die past bij de brief bovenin.
4. Klik **RECORD TAKE**. De rapper rapt twee maten en geeft een oordeel (1–5 sterren). Elke retake kost geduld.
5. Klik **FINISH** om de beste take uit te brengen. Je krijgt geld, reputatie en Street Cred.
6. Pas op met het volume: de geluidsmeter loopt op. Bij 100% belt de buurman de politie (€40 boete).

## In v0.5
- Nieuwe personages met normale verhoudingen (Quaternius, CC0): geen grote hoofden meer
- LOOPR Piano Roll: melodie op 16 stappen, C-mineur-hulplijnen, instrumenten (keys, pluck, bell, pad)
- Rappers beoordelen nu ook melodie, toonladder, kit en instrument; elke rapper heeft eigen smaak
- Shop op je telefoon: akoestisch schuim (minder geluid), betere mic, studiomonitors, drumkits, instrumenten, neon. Upgrades zijn zichtbaar in de kamer
- Dag/nacht: om 06:00 ga je slapen (of eerder via het bed). 's Nachts gaan je tracks streamen en verdien je geld. Soms lekt een track: meer streams, minder geld
- Chaos: de pc kan crashen en dan ben je niet-opgeslagen werk kwijt. Druk SAVE of Ctrl+S
- 4e rapper: Spike (rage, 150–170 BPM)

## In v0.4
- 3 rappers als echte personages (Kenney Mini Characters, CC0) met eigen accessoires, animaties en brabbelstem
- Telefoon met DM's, sessie-loop, beoordeling (tempo, drums, groove, mix), resultatenscherm
- Geld, reputatie en Street Cred, opgeslagen tussen sessies
- Chaos: geluidsmeter, buren die op de muur bonken, politie met een boete

## In v0.3
- Titelscherm met cinematische camera
- Echte low-poly meubels (Kenney Furniture Kit, CC0), herkleurd naar het neon-nachtpalet
- Nachtelijke skyline met verlichte ramen (Kenney City Kit, CC0, met eigen night-shader)
- Stofdeeltjes, plafondventilator, nachtkastje met lamp, platenkast, kapstok, merchdozen
- Head-bob tijdens lopen en een nieuwe interactie-prompt

## In v0.2
- Uitgewerkte neon-slaapkamerstudio volgens `docs/ART_DIRECTION.md`: echte schaduwen, maanlicht door het raam, skyline, bureaulamp, booth-hoek en veel props
- De monitor toont LOOPR live
- LOOPR Channel Rack: 16-stappen sequencer met kick, snare, hi-hat, clap en 808; BPM 60–200; demo-beat
- LOOPR Mixer: fader en mute per spoor, plus master
- De drumgeluiden zijn tijdelijke placeholders, in code gegenereerd
