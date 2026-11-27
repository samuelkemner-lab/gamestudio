# LOOPR 3 – Masterprompt: een BandLab-achtige studio in Studio Grind

> Lees dit document vóór elke taak aan LOOPR. Het is de bron van waarheid voor hoe LOOPR werkt, eruitziet en aanvoelt.
> Samen met `docs/ART_DIRECTION.md` (de kamer en de algemene stijl) en `CLAUDE.md` (regels en structuur).

---

## 0. Rol en opdracht

Je bent tegelijk **senior DAW-ontwerper**, **Godot 4.4-engineer** en **game designer**.
Je bouwt LOOPR 3: de in-game studio van Studio Grind. Het moet aanvoelen als een moderne, toegankelijke browser-DAW in de stijl van BandLab Studio: **één scherm, sporen onder elkaar, gekleurde blokken op een tijdlijn, en alles direct te horen.** Daarbij blijft het een game: elke functie moet iets doen voor de gameplay (rappers blij maken, streams, geld, chaos).

Het doel in één zin:
**Een speler die nooit een DAW heeft aangeraakt, maakt in 10 minuten een nummer met een rapper erop, en een speler die BandLab kent, voelt zich meteen thuis.**

---

## 1. Juridische grens: het gevoel en de werking, niet de merkidentiteit

Dit is niet onderhandelbaar (zelfde regel als bij FL Studio in `CLAUDE.md`).

**Mag wel** (algemene DAW-conventies, die elke DAW gebruikt):
- Sporen verticaal, tijd horizontaal, gekleurde regions op een tijdlijn
- Track header met M/S, naam, volumeslider en panknop
- Transport in het midden, met undo/redo links en tempo/toonsoort rechts
- Cycle-balk in de liniaal, een driehoekige playhead, editors die onderin openen
- Regions verplaatsen, trimmen, loopen, splitsen, dupliceren, fades, takes/comping
- Drum machine, sampler, piano roll, mixer, effectketens en automation

**Mag niet:**
- De naam *BandLab*, *Mix Editor*, *SongStarter*, *Splitter*, *AutoPitch* of andere productnamen gebruiken. Gebruik eigen namen (zie §14).
- Logo, iconenset, lettertype of exacte kleuren van BandLab overnemen.
- Een pixel-voor-pixel-kopie van een BandLab-scherm. Tolerantie: wie de twee naast elkaar legt, ziet "zelfde soort programma", niet "zelfde programma".
- Audio, loops of presets van BandLab gebruiken. Alleen eigen geluid dat in code is gegenereerd, Sams eigen kits of CC0.

**Toets bij elk scherm:** "Zou BandLab dit herkennen als *hun* product?" Zo ja, dan maak je het meer LOOPR (neon-palet, eigen iconen, eigen copy).

---

## 2. Designpijlers (het BandLab-gevoel ontleed)

1. **Eén werkruimte.** Geen tabs voor de hoofdtaken. De tijdlijn is altijd zichtbaar. Editors openen in een **dock onderin**, nooit als apart scherm.
2. **Blokken, geen lijstjes.** Alles wat klinkt is een gekleurde region met een **mini-preview** erin: noten als streepjes, drums als stipjes, vocals als waveform.
3. **Direct horen.** Elke klik maakt geluid: een stap zetten, een noot plaatsen, een pad aanraken, een preset kiezen. Geen "apply"-knoppen.
4. **Vergevingsgezind.** Alles kan met Undo en Redo ongedaan worden gemaakt. Je gooit nooit per ongeluk iets weg zonder een "Undo"-toast.
5. **Kleur = spoor.** Elk spoor heeft één kleur. Regions, header-accent, mixerstrip en automation-lijn gebruiken die kleur.
6. **Platte, rustige UI.** Donkergrijze vlakken, afgeronde hoeken (6–8 px), weinig lijnen en nauwelijks schaduw. Kleur is alleen voor content (regions) en status (record = rood).
7. **Weinig diepte.** Maximaal twee klikken naar elke functie. Rechtermuisknop geeft altijd een contextmenu, en elke actie heeft ook een sneltoets.
8. **Gametaal bovenop DAW-taal.** De DAW is realistisch, de game praat er doorheen: rappers geven commentaar *op posities* ("that drop at bar 5 goes crazy").

---

## 3. Schermindeling (1600 × 900, ook leesbaar op de monitor in de kamer)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│ MENU BAR (32)  ⟵ Exit   Project  Edit  View  Help          "Night Shift – Lil Tear" │
├──────────────────────────────────────────────────────────────────────────────┤
│ TOOLBAR (64)  [↶][↷] [⟳ cycle][✂ split]  [|◀][▶][▶|][●] 00:00.0 │ C min │ 140 bpm │ 4/4 │ [♩ click] [1 bar count-in] │
├───────────────────────┬──────────────────────────────────────────────────────┤
│ + Add Track    [⌖ snap]│ RULER (44): 1   2   3   4 … met cycle-balk + playhead ▼ │
├───┬───────────────────┼──────────────────────────────────────────────────────┤
│ M │ 🎤 Vocal      ⋯   │ ███ Take 3 – Lil Tear ███████████████ (waveform)       │
│ S │ ━━━━━━━○──  (pan) │                                                      │
├───┼───────────────────┼──────────────────────────────────────────────────────┤
│ M │ 🥁 Beat       ⋯   │ [Beat A ·:·:·:][Beat A ·:·:·:][Beat B ·:·::·:]          │
│ S │ ━━━━━━○───  (pan) │                                                      │
├───┼───────────────────┼──────────────────────────────────────────────────────┤
│ M │ 🎹 Keys       ⋯   │       [Keys ═ ─ ═][Keys ═ ─ ═]                        │
├───┼───────────────────┼──────────────────────────────────────────────────────┤
│ M │ ∿ 808         ⋯   │ [808 ▂▄▂ ▆]                                           │
├───┴───────────────────┴──────────────────────────────────────────────────────┤
│ DOCK (0 / 300 / 420, versleepbaar): [Beat Editor | Piano Roll | Takes | Mixer | FX] │
└──────────────────────────────────────────────────────────────────────────────┘
          optioneel rechts: BROWSER-paneel (320) Loops · Sounds · Presets
```

**Maten en regels**
- Track header-kolom: **380 px** breed. Spoorhoogte: **116 px** standaard, 64 px compact (View → Compact), 180 px groot.
- Header-indeling:
  - links een kolom van 52 px met **M** en **S** onder elkaar (elk de halve hoogte);
  - daarnaast een icoon, de naam (bewerkbaar met dubbelklik) en `⋯` (menu);
  - onderin een volumeslider (kleur = spoorkleur als niet 0 dB, grijs op 0 dB) en een panknop met L/R-labels;
  - tussen de headerkolom en de lanes een **meter van 4 px**.
- Liniaal: maatnummers, maatlijnen 1 px, tellen 1 px met 40% alfa. **Cycle-balk** als halfdoorzichtige rode/neon-roze band bovenin de liniaal. Playhead: witte driehoek bovenin plus een lijn van 1 px over alle sporen.
- Lege ruimte onder het laatste spoor: een gestippelde dropzone met "Drop a loop here or click + Add Track".
- Dock: tab-rij van 36 px. Hoogte versleepbaar via een greep van 6 px. **Dubbelklik op een region opent de bijbehorende editor in het dock.**
- Alles moet leesbaar blijven op 1600×900: geen tekst kleiner dan 12 px, knoppen minimaal 32 px hoog.

---

## 4. Datamodel (bron van waarheid, los van de UI)

Tijdseenheid: **tick**. `TICKS_PER_STEP = 12` (1 stap = een 16e). Daarmee passen rolls van ×2, ×3, ×4 en ×6 en triolen. Een maat (4/4) is 16 stappen, dus 192 ticks.

```gdscript
Project {
  version: 3
  name: String, bpm: float, key_root: int (0=C), key_mode: "minor"|"major", time_sig: [4,4]
  length_bars: int (max 32)
  cycle: {on: bool, start_tick: int, end_tick: int}
  metronome: {on: bool, volume: float, count_in_bars: 0|1|2}
  snap: "bar"|"beat"|"step"|"off"
  tracks: Array[Track]
  markers: Array[{tick, name}]   # Intro / Hook / Verse / Drop (gameplay: rappers reageren erop)
  master: {volume, fx: Array[Fx]}
}

Track {
  id, type: "beat"|"instrument"|"bass"|"vocal"|"loop"
  name, color_index (0..7), icon
  volume (0..1.25), pan (-1..1), mute, solo, arm (alleen vocal/loop-opname)
  instrument: String   # kit-id, instrument-id of "808"
  fx: Array[Fx]        # max 4 slots (upgrade: 6)
  fx_blend: float      # dry/wet voor de hele keten
  automation: {volume: Array[Point], pan: Array[Point], fx_blend: Array[Point]}
  regions: Array[Region]  # nooit overlappend op één spoor
}

Region {
  id, start_tick, length_tick       # zichtbare lengte (incl. loops)
  source_length_tick                # lengte van één loop-cyclus
  offset_tick                       # trim aan de linkerkant
  content_id                        # → Clip (gedeeld = "linked" regions)
  name, color_override (-1 = spoorkleur), muted, gain_db
  fade_in_tick, fade_out_tick       # alleen audio
  active_take (vocal)               # index in takes
}

Clip (gedeeld door gelinkte regions; "Make Unique" kopieert hem)
  BeatClip  {steps: 16|32|64, lanes: [{sound, hits: [{step, vel, roll}]}], swing}
  NoteClip  {notes: [{tick, len, pitch, vel}], glide (bass)}
  TakeClip  {takes: [Take], comp: [{start_tick, end_tick, take_index}]}
  LoopClip  {loop_id}   # uit de Loops-browser

Take {stream: AudioStreamWAV, peaks: PackedFloat32Array (mipmaps), rapper_id, flow_seed,
      quality: float (0..1, de "performance" van de rapper), created_day}
```

**Migratie van v0.6:** patterns A–D worden BeatClips plus NoteClips (melodie → Keys-spoor, 808-lane → Bass-spoor). De playlist wordt regions op de Beat-, Keys- en 808-sporen. Mixerinstellingen gaan naar `Track.volume/pan/fx`. Saves krijgen `version: 3`; oudere saves worden bij het laden één keer omgezet. Schrijf hiervoor een test.

**Undo:** gebruik Godot's `UndoRedo` met acties per gebaar ("Move region", "Trim region", "Paint steps"). Eén sleepbeweging is één actie. Redo moet werken (Ctrl+Shift+Z en Ctrl+Y).

---

## 5. Tijdlijn-interacties (het hart van het BandLab-gevoel)

### Regions
| Actie | Muis | Toets |
|---|---|---|
| Selecteren | klik (shift = toevoegen, sleep in lege lane = rubber band) | Ctrl+A alles |
| Verplaatsen | slepen op de body (ook naar een ander spoor van hetzelfde type) | ←/→ = 1 snap-eenheid |
| Kopie tijdens slepen | Alt + slepen | |
| Trimmen | rand links/rechts slepen (cursor ↔) | |
| **Loopen** | **hoek rechtsboven slepen** (cursor ⟳): herhaalt de inhoud, met naadmarkeringen | L = loop tot cycle-einde |
| Splitsen | split-tool ✂ of klik op de playhead | S = splitsen op playhead |
| Dupliceren | contextmenu | Ctrl+D (plaatst direct erachter) |
| Kopiëren/plakken | | Ctrl+C / Ctrl+V (op playhead, geselecteerd spoor) |
| Verwijderen | contextmenu | Delete / Backspace |
| Mute region | contextmenu | M (region) / Shift+M (spoor) |
| Fade in/out | driehoekjes bovenin de hoeken slepen (alleen audio) | |
| Gain | contextmenu → slider | |
| Hernoemen / kleur | dubbelklik op de titel / contextmenu → 8 kleuren | |
| Make Unique | contextmenu (gelinkte region loskoppelen) | U |
| Openen in editor | dubbelklik | Enter |

**Lege lane:** dubbelklik maakt een nieuwe region van 1 maat (beat/instrument/bass) op de snap-positie en opent die direct in de editor. Bij een vocal-spoor gebeurt niets (daar neem je op).

**Snap:** standaard aan op *beat*, tenzij je verder ingezoomd bent dan een stap. Alt houdt snap tijdelijk uit. Een snap-menu naast "+ Add Track" heeft de opties Bar, Beat, 1/16 en Off.

**Visuele feedback:**
- Een sleepschaduw met 60% alfa.
- Doelposities lichten op als een groene lijn.
- Een ongeldige drop (overlap of verkeerd spoortype) schudt kort.
- Bij overlap wordt de onderliggende region **ingekort**, zoals in BandLab: de nieuwe region "knipt" het stuk eronder weg.

### Liniaal en transport
- Klik in de liniaal: de playhead springt erheen (tijdens afspelen loopt het afspelen vanaf daar door).
- Sleep in de bovenste helft van de liniaal: je zet een cycle-bereik. Klik op de cycle-balk: cycle aan/uit.
- Markers: rechtsklik in de liniaal → "Add marker" → Intro / Verse / Hook / Bridge / Drop / Outro.
- Zoom: Ctrl+muiswiel (rond de muispositie), of + en −. Horizontaal scrollen: muiswiel of Shift+wiel. "Zoom to fit": Z.
- Spatie = play/stop (stop zet de playhead terug naar het startpunt, zoals in BandLab), Enter = naar begin, R = opnemen, C = cycle, K = metronoom.
- De klok wisselt bij klikken tussen `mm:ss.t` en `bar.beat.step`.

### Sporen
- Met "+ Add Track" open je een kiesmenu met 5 grote tegels: **Beat** (drum machine), **Instrument** (keys, pluck, bell, pad), **808**, **Vocal** (rapper) en **Loop**. Elke tegel heeft een icoon en een korte uitleg.
- Volgorde aanpassen: header slepen. Het `⋯`-menu bevat Rename, Color, Duplicate track, Delete, Freeze (gameplay: minder CPU, dus minder crashkans) en Show automation.
- **Spoorlimiet als gameplay:** je begint met 4 sporen, met upgrades worden het er 8 en daarna 16 ("New laptop", "Studio PC").

---

## 6. Spoortypes en hun editors (in het dock)

### 6.1 Beat (drum machine)
- Het dock toont links een **pad-grid van 4×4** (16 pads, de kit) en rechts het **step-raster**. Dit is het huidige Channel Rack, maar per region.
- Elke rij heeft een pad, een mute-knop, een volumeknop en een "pitch"-knop van ±12 st per geluid.
- De tools blijven: Draw / Velocity / Roll. Verder: swing per clip, stappen 16/32/64, "Clear", "Randomize hats" (alleen Easy).
- Pads zijn ook speelbaar met het toetsenbord: Q-W-E-R / A-S-D-F / Z-X-C-V speelt live in (quantized naar de snap).
- Een kit kiezen doe je in de browser (Sounds → Kits). Gekochte kits uit de shop verschijnen daar.

### 6.2 Instrument (keys, pluck, bell, pad, en later meer)
- **Piano roll** met een klavier links (64 px) en een raster van 2 octaven, scrollbaar over 5 octaven.
- Noten hebben een **lengte** (versleepbare rechterrand) en zijn niet meer alleen maar stappen.
- De **velocity-lane** onderin (60 px) bevat staafjes die je kunt verslepen.
- **Toonsoort-hulp:** rijen buiten de projecttoonsoort zijn donkerder. De knop "Scale lock" maakt noten buiten de toonsoort onmogelijk (alleen Easy).
- Akkoordknop: klik op de grondtoon en kies maj/min/7 om een akkoord te plaatsen.
- Bediening: dubbelklik = noot, slepen = verplaatsen, Alt+slepen = kopiëren, Delete = weg, Ctrl+A en pijltjes omhoog/omlaag = transponeren (Shift = octaaf).

### 6.3 808 (bass)
- Een piano roll in een monofone modus: één noot tegelijk, nieuwe noten kappen de vorige af.
- Glide per noot (een slide-ikoon op de noot) of globaal. Er is een "Distortion"-knop op het spoor zelf.
- De visualisatie van de region toont een melodielijn in plaats van blokjes.

### 6.4 Vocal (de rapper: de kern van de game)
- De region toont een **echte waveform** van de take. De brabbelstem wordt offline naar een `AudioStreamWAV` gerenderd, en de peaks worden vooraf berekend (zie §11).
- Het dock-tabblad **Takes**: alle takes onder elkaar als lanes (comping). Klik op een stuk van een take-lane om dat stuk te kiezen voor de composite. Elke take toont het *performance-label* van de rapper ("tired", "on fire", "off-beat").
- Het `⋯`-menu bevat de effectpresets: "Clean", "Trap Vox", "Radio", "Underwater", "Demon".
- Lyrics-paneel (later): Sams eigen teksten als teleprompter tijdens de opname.

### 6.5 Loop
- Sleep een loop uit de browser naar een lege lane of een loop-spoor. De loop is tempo-gesynct (in-game loops zijn op het projecttempo gegenereerd, dus er is geen timestretch nodig).
- Loops zijn **gameplay-items**: loop packs koop je in de shop. Rappers vinden "te veel loops, te weinig eigen werk" saai: in de judge is een origineel-factor zichtbaar.

---

## 7. Opnemen met een rapper (de gameloop in de DAW)

1. De rapper staat in de booth. Op het Vocal-spoor licht de **arm-knop** (●) op.
2. Zet een cycle-bereik over de maten die hij moet rappen. Zonder cycle neemt hij 4 maten op vanaf de playhead.
3. Druk op **R**. Je hoort de **count-in** (1 maat, metronoom), daarna speelt het nummer en rapt de rapper live. Tijdens de opname groeit een rode region met een live waveform.
4. Na de take beoordeelt de rapper hem (de judge), en de take krijgt sterren in de Takes-lane.
5. Opnieuw opnemen over hetzelfde bereik maakt een **nieuwe take** (comping), net als bij BandLab: de oude takes blijven bewaard. Elke take kost geduld (bestaande regel).
6. In de Takes-tab kies je per stuk de beste take. De **composite** bepaalt de eindscore. Gameplay: een hook uit take 2 plus een verse uit take 3 kan 5 sterren halen, terwijl geen enkele losse take dat haalt.
7. **FINISH / Release** exporteert het nummer. De judge kijkt naar het hele arrangement (§10).

Regels:
- De opname loopt op de klok van de transport, niet op frames. De waveform-render moet sample-exact uitlijnen met de maatlijnen.
- De take-kwaliteit hangt af van de beat onder het opnamebereik (judge per maat) plus een willekeurige performance (seed), met minder variatie op Pro-mic.
- Komt het geluidsniveau tijdens de opname te hoog uit, dan bonkt de buurman *in de take*: er komt een zichtbare bonk in de waveform en de take is −1 ster. Chaos wordt zo hoorbaar.

---

## 8. Mixer, effecten en automation

### Mixer (dock-tab "Mixer")
- Eén strip per spoor plus Master:
  - meter (zoals de huidige LooprMeter);
  - fader;
  - panknop;
  - M, S en arm;
  - **4 FX-slots** (klik = effect kiezen, ⏻ = bypass, dubbelklik = effectpaneel in de FX-tab);
  - FX Blend-knop;
  - stripnaam in de spoorkleur.
- Master: een limiter (altijd aan, uit te zetten in Pro), een **Master-knop** ("Polish": mastering-presets Warm / Punchy / Loud, te ontgrendelen met de Mastering-upgrade) en een clip-led.

### Effecten (Godot `AudioEffect*` per bus)
| Effect | Godot | Knoppen in de UI |
|---|---|---|
| EQ | `AudioEffectEQ6` | Low / Mid / High (±12 dB) + Lo-cut-toggle |
| Compressor | `AudioEffectCompressor` | Amount (1 knop → threshold + ratio), Makeup |
| Reverb | `AudioEffectReverb` | Size, Wet |
| Delay | `AudioEffectDelay` | Time (1/8, 1/4, dotted), Feedback, Wet |
| Saturation | `AudioEffectDistortion` | Drive, Tone |
| PitchFix | `AudioEffectPitchShift` + game-logica | Strength 0–100 (rappers met een autotune-stijl willen 80+) |
| Chorus | `AudioEffectChorus` | Width, Wet |

- Elk effect heeft maximaal 3 knoppen. Achter "Advanced" (Pro) zitten de echte parameters.
- **Presets per spoortype**, met grote tegels: "Trap Vox", "Boom Bap Drums", "Drill 808", "Dark Pad". Een preset is een keten plus instellingen.
- "**AI FX**"-achtige knop → in-game "**Vibe Match**": vraagt de rapper wat hij wil en zet een preset. Kost 1 geduld-hart, want hij moet het uitleggen.

### Automation
- Via `⋯` → Show automation verschijnt onder het spoor een lane van 60 px voor Volume / Pan / FX Blend.
- Klik = punt, slepen = verplaatsen, dubbelklik op een punt = weg. Lijnen zijn lineair, punten snappen.
- Tijdens het afspelen bewegen de fader en de knop in de header mee (BandLab doet dit ook, en het voelt levend).

---

## 9. Browser-paneel (rechts, inklapbaar met B)

- Tabs: **Loops** (per genre: Boom Bap, Trap, Drill, Rage, Emo; tegels met BPM, toonsoort en een preview-knop), **Sounds** (kits en one-shots), **Presets** (FX-ketens).
- Een preview speelt op het projecttempo. Je sleept een item naar de tijdlijn of klikt "+" om het op de playhead in het geselecteerde spoor te zetten.
- Vergrendelde items tonen een slotje en de prijs, met een klik naar de shop op de telefoon.
- **Spark** (eigen naam, géén "SongStarter"): op Easy maakt hij een startbeat in de genre-smaak van de geboekte rapper (beat- en 808-region). Gebruik kost reputatie-groei: het nummer krijgt "made with Spark", wat ×0.8 rep oplevert. Op Pro is Spark uitgeschakeld.

---

## 10. Gameplay-integratie (waarom dit meer is dan een mooie DAW)

- **De judge leest de tijdlijn**, niet meer één pattern:
  - per maat onder de vocal: past de beat bij de rapper (bestaande criteria: BPM, drums, melodie, signature, feel, mix);
  - **structuur**: intro (1–2 maten zonder vocal), hook die terugkomt (zelfde clip ≥ 2×), variatie (≥ 2 verschillende beat-clips), een **drop** (maat waarin drums wegvallen en terugkomen);
  - **mix over tijd**: clipping per maat en vocal-verstaanbaarheid (vocal-fader versus beat-niveau in het levelmodel).
- Feedback wijst naar posities: "Bar 5–8: the hats are too busy under my verse." Klik op de feedback en de playhead springt naar die maat.
- **Streams:** lengte 16–32 maten plus structuur plus een mastering-preset geven een multiplier (die vervangt de huidige ×1.5-regel voor "full song").
- **Upgrades die de DAW raken:** meer sporen, meer FX-slots, loop packs, kits, de mastering-knop, "Autosave" (minder crashverlies) en een sneller laptop-model (minder crashkans bij veel sporen of effecten).
- **Chaos in de DAW:**
  - een pc-crash bij veel sporen plus niet opgeslagen werk;
  - een **leak**: een niet-gereleasde take staat ineens online;
  - **beef**: een rapper wil dat je de region van een ander verwijdert.
- **Easy vs Pro:** Easy geeft Scale lock, Spark, hints in de regions (een gele rand op probleemmaten) en takes zonder geduldsverlies bij de eerste. Pro geeft geen hints, vaste count-in en echte FX-parameters.

---

## 11. Techniek in Godot 4.4

- **Model los van de UI:** `scripts/daw/project.gd` (data plus JSON-serialisatie), `scripts/daw/transport.gd` (klok en scheduler), `scripts/daw/engine.gd` (audio: players per spoor, buses, effecten) en `scripts/daw/commands.gd` (UndoRedo-acties).
- **Timing:** plan noten **vooruit** in (lookahead van 100 ms) op basis van `AudioServer.get_time_since_last_mix()` en `get_output_latency()`, niet per frame zoals nu. Test dat 4 maten op 140 BPM binnen ±10 ms eindigen.
- **Tijdlijn-rendering:** één custom-drawn `TimelineView` (zoals `LooprGrid`), die alleen tekent wat in beeld is. Mini-previews van regions worden gecachet per clip-versie.
- **Waveforms:** bij het renderen van een take maak je peaks in mipmap-niveaus (1/256, 1/1024, 1/4096 samples) en teken je die als gespiegelde polygoon in een donkere tint van de spoorkleur.
- **Vocal-render:** `VoiceSynth` schrijft de flow (lettergrepen op de flow-stappen van de rapper) offline naar een buffer met de projectlengte. Afspelen gaat via één `AudioStreamPlayer` per take met `play(from_position)`.
- **Bussen:** één bus per spoor, aangemaakt en verwijderd met het spoor, met namen als `trk_<id>`. Effecten zijn per slot een `AudioEffect` op die bus.
- **Levelmodel:** het bestaande deterministische model blijft de basis voor de judge (testbaar, headless). De meters mogen in de echte game `AudioServer.get_bus_peak_volume_*` gebruiken.
- **Prestaties:** 16 sporen × 32 maten moeten op 60 fps blijven tekenen. Teken dus niet per frame opnieuw, maar alleen bij wijzigingen of bij bewegen van de playhead (de playhead is een aparte overlay-node).
- **Monitor in de kamer:** de SubViewport-mirror blijft. Hij toont dezelfde `TimelineView` met dezelfde data, maar zonder input.

---

## 12. Visuele stijl (LOOPR-identiteit, met het BandLab-gevoel als basis)

| Element | Waarde |
|---|---|
| App-achtergrond | `#14111d` |
| Panelen en headers | `#1c1828`, rand `#2a2440` 1 px |
| Lanes | om en om `#17141f` / `#1a1724`; maatlijnen `#2a2440` |
| Tekst | `#e9e4ff`; secundair `#8f86b3` |
| Accent (UI) | `#a855f7` (paars); record `#ff3d5a`; cycle `#ff3d7f` op 35% alfa |
| Spoorkleuren (8) | `#f43f5e` rood · `#e879f9` magenta · `#a3e635` lime · `#f5b52e` goud · `#22d3ee` cyaan · `#4f8ff7` blauw · `#a855f7` paars · `#fb923c` oranje |
| Region | vulling = spoorkleur; titelbalk 20 px met label in een donkere pill (12 px tekst); content in een 45% donkerdere tint van de spoorkleur |
| Geselecteerd | 2 px witte rand plus een lichte glow (8 px, 25% alfa) |
| Gemute region | gedesatureerd naar 30%, schuine strepen |
| Gelinkte region | een klein ⟲-icoon rechtsboven (zoals op de BandLab-screenshot, maar met een eigen icoon) |
| Hoeken | regions 6 px, knoppen 8 px, panelen 10 px |
| Iconen | eigen, in code getekende lijn-iconen van 2 px (play, record, cycle, split, metronoom, mic, drum, keys, wave) |

- **Animaties:** de playhead beweegt vloeiend (sub-frame). Regions "landen" met een overshoot van 80 ms. Toasts schuiven in. Faders en knoppen bewegen mee bij automation. Geen animatie duurt langer dan 200 ms.
- **De neon-signatuur van LOOPR:** de playhead-lijn en de cycle-balk gloeien (glow uit de game-omgeving). Dat onderscheidt het van BandLabs vlakke grijs.

---

## 13. Bouwfases (kleine stappen: na elke fase testen, screenshots maken, committen)

**F1. Tijdlijn-fundament**
- Project/Track/Region-model, migratie van v0.6, TimelineView met liniaal, playhead, cycle en snap.
- Track headers (M/S/vol/pan/meter). Regions verplaatsen, trimmen, loopen, splitsen, dupliceren en verwijderen. UndoRedo.
- *Klaar wanneer:* het v0.6-demonummer als regions op 3 sporen staat, alle acties in tests werken en Undo/Redo elke actie terugdraait.

**F2. Dock-editors**
- Beat Editor (pads plus step-raster per clip), Piano Roll met nootlengte en velocity-lane, 808-modus.
- Linked vs unique clips.
- *Klaar wanneer:* een wijziging in een gelinkte clip in alle kopieën te zien is en "Make Unique" dat verbreekt.

**F3. Vocal-opname**
- Arm, count-in, metronoom en een live groeiende region met waveform. Takes en comping. De judge per maat.
- *Klaar wanneer:* twee takes plus een composite een hogere score geven dan de beste losse take, in een deterministische test.

**F4. Mixer, effecten en automation**
- Strips, 4 FX-slots, presets, FX Blend, automation-lanes en de mastering-knop.
- *Klaar wanneer:* "Trap Vox" op het Vocal-spoor hoorbaar effect heeft, een automation-curve in de test de fader beweegt en clipping per maat wordt gemeld.

**F5. Browser, loops en gameplay**
- Een generator voor loop packs (per genre, in code), Spark (Easy), upgrades voor sporen en slots, en een structuur-judge plus de stream-multiplier.
- *Klaar wanneer:* een volledige sessie (boeken → bouwen → opnemen → comping → release → slapen) in een test slaagt.

**F6. Polish**
- Contextmenu's, alle sneltoetsen, toasts, tooltips, tutorial-overlay (5 stappen), View-opties (compact/groot) en screenshot-QA volgens §15.

---

## 14. Eigen namen (gebruik deze, nooit de BandLab-termen)

| Generiek idee | LOOPR-naam |
|---|---|
| Hoofdscherm van de DAW | **Studio View** |
| Starthulp-generator | **Spark** |
| Pitch correction | **PitchFix** |
| AI-effect-preset | **Vibe Match** |
| Mastering | **Polish** |
| Loop-bibliotheek | **Crate** |
| Drum machine | **Beat Pad** |
| Stem splitting (later) | **Pull Apart** |

---

## 15. QA-checklist (bij elke screenshot)

- [ ] Ziet het eruit als "een modern, vriendelijk DAW" en **niet** als een kopie van één specifiek merk?
- [ ] Is de tijdlijn altijd zichtbaar, staan editors in het dock en is er geen schermwissel?
- [ ] Heeft elk spoor één consistente kleur in de header, de regions, de mixerstrip en de automation?
- [ ] Hebben de regions een titelbalk en een mini-preview die laat zien wát erin zit?
- [ ] Is de playhead duidelijk zichtbaar, en de cycle-balk ook als die aan staat?
- [ ] Is alle tekst ≥ 12 px en leesbaar op de monitor in de kamer (shot `desk`)?
- [ ] Is record rood, en is rood verder alleen gebruikt voor mute, clip en record?
- [ ] Heeft de actie die je net bouwde een sneltoets, een contextmenu-item en Undo?
- [ ] Geeft de game-laag feedback op posities (maatnummers) en niet alleen in het algemeen?
- [ ] Draait het op 60 fps met 8 sporen × 16 maten (meet met de Godot-profiler)?

---

## 16. Buiten scope (nu niet bouwen)

- Echte microfoon-opname van de speler. Kan later voor Sam en vrienden, maar niet in v1.
- Online samenwerken, publiceren naar een social feed en cloud-sync.
- Timestretch van willekeurige audio (alle loops worden op tempo gegenereerd).
- Stem splitting (Pull Apart) en AI-stemmen. Die laatste alleen met akkoord van Sam en een kostenoverzicht (`CLAUDE.md`).
- Meer dan 16 sporen of meer dan 32 maten.
