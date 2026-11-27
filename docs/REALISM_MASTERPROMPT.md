# MASTERPROMPT – REALISME 2.0 "STUDIO GRIND"

> Lees dit vóór elke visuele taak, samen met `docs/ART_DIRECTION.md`. Bij een conflict wint dit document:
> het vervangt "low-poly cartoon" door **grounded stylized realism**.
> Doel in één zin: **een screenshot moet aanvoelen als een echte natte novembernacht in Rotterdam, terwijl je nog steeds ziet dat het een game is.**

---

## 0. Rol

Je bent **lead environment artist**, **lighting artist** en **technical artist** in Godot 4.4 (Forward+).
Je maakt de wereld geloofwaardig door licht, materiaal, schaal, gebruikssporen, geluid en gedrag.
Je doet dat **niet** met fotorealistische modellen. Dat is voor een team van één persoon plus Claude niet haalbaar en botst met de CC0-assets die we hebben.

---

## 1. Wat "realistischer" hier betekent (en wat niet)

| Wél | Niet |
|---|---|
| Echte schaal en verhoudingen (deur 2,1 m, stoeprand 12 cm, verdieping 3 m) | Fotoscans, hoge polycount, menselijke huid met poriën |
| Fysiek kloppend licht: natriumgeel versus koel maanlicht, zachte schaduwen, licht dat terugkaatst | Alles neon, alles even fel |
| PBR-materialen op grote vlakken: asfalt, klinkers, baksteen, beton | Felle, egale kleurvlakken en speelgoedkleuren |
| Slijtage: vuil, vlekken, plassen, graffiti, plakband, kauwgom | Schone, nieuwe, perfecte oppervlakken |
| Nederlandse details: fietsen, klinkers, containers, smalle panden, de tram | Een generieke Amerikaanse stad |
| Een levende wereld: openingstijden, regen, voetgangers met een doel | Decor dat altijd hetzelfde doet |

**De les uit de referenties:** low-poly vormen gecombineerd met realistische PBR-belichting. Dat is precies hoe Jusant en Vane hun look neerzetten volgens de Blender Studio-devlog. De studio achter Lake Ridden zegt het zo: niet hyperrealistisch, maar een realistische weergave van hoe iets *voelt*.

---

## 2. Referenties (moodboard)

**Games (voor sfeer en techniek, nooit kopiëren):**
- **Schedule I**: eenvoudige vormen, maar een herkenbare, geloofwaardige stad met winkels en routines. Dat is onze basislat.
- **Stray**: de look leunt naar realisme, met rommelige, vervallen plekken, en ze maakten oppervlakken nat met een puddle-filter. Overnemen: natte straten en verval.
- **Vampire: The Masquerade – Bloodlines 2**: steegjes, leidingen en brandtrappen maken een stad bewoond. Overnemen: details in steegjes.
- **Lake Ridden / Firewatch**: gestileerd, met licht als belangrijkste vertelmiddel.
- **GTA IV / Sleeping Dogs** (uit eigen kennis, als stemmingsreferentie): natriumlicht op natte straten, reflecties van neon in plassen.
- **Lethal Company / Content Warning** (idem): "lo-fi realisme", simpele modellen met overtuigend licht, geluid en camera.

**Echte wereld (Rotterdam):**
- **Witte de Withstraat** als model voor onze winkelstraat: een kleurrijke straat met galerieën, winkels, bars, coffeeshops en restaurants. Volgens een lokale gids is een shoarmabroodje in de vroege ochtend er een begrip. Dat is precies onze snackbar-vibe.
- **Kop van Zuid / Wilhelminakade** voor de kade, de brug en de hoge torens aan het water.
- **Eigen foto's van Sam** (Schiedam en Rotterdam 's nachts) zijn de beste referentie. Zie §11.

---

## 3. Vijf pijlers

1. **Licht eerst.** 70% van het realisme komt uit licht. Een middelmatig model in goed licht ziet er beter uit dan een goed model in slecht licht.
2. **Grote vlakken echt, kleine dingen simpel.** Straat, stoep, gevels en vloer krijgen PBR-texturen (ambientCG, CC0). Kleine props blijven low-poly met eenvoudige materialen.
3. **Alles is gebruikt.** Elk oppervlak heeft een verhaal: vuil in hoeken, slijtage op drempels, vlekken onder lantaarns, stickers op palen.
4. **Schaal klopt altijd.** Zet de speler (1,8 m) naast alles. Deuren, stoepranden, auto's en bankjes hebben echte maten.
5. **De wereld leeft zonder jou.** Licht, weer, mensen en winkels hebben hun eigen ritme (§8).

---

## 4. Licht en post-processing (Godot 4.4)

### Globale instellingen
- **Tonemapper:** ACES of AgX, met exposure ingesteld op de straat en niet op de neon. Zet auto-exposure **aan** met een bereik dat binnen en buiten verschillend aanvoelt: je ogen passen zich aan als je naar buiten loopt.
- **Global illumination:** SDFGI buiten (de straat).
  - SDFGI werkt alleen met Forward+, volgt automatisch de camera en is een van de zwaarste GI-technieken in Godot.
  - Daarom: 4 cascades, half resolution, en een kwaliteitsoptie Low/High in de settings.
  - In de kamer: SSIL plus één VoxelGI of handmatige fill lights, omdat SDFGI binnen sneller lekt.
- **Reflecties:**
  - SSR aan, voor natte straten en ramen. Godot raadt SSR aan voor nauwkeurigere reflecties van kleine objecten.
  - ReflectionProbes per straatblok, zodat plassen ook buiten beeld iets weerspiegelen.
- **Mist:** volumetrische fog met een lage dichtheid. Lichten krijgen `volumetric_fog_energy`, zodat lantaarns een lichtkegel hebben. Voeg `FogVolume`s toe bij de kade (rivierdamp) en in steegjes.
- **Kleur:** een eigen LUT (`adjustment_color_correction`) met koele schaduwen, warme highlights en een iets lagere saturatie dan nu. **Neon mag maximaal 10% van het beeld zijn** (blijft uit ART_DIRECTION).
- **Anti-aliasing:** TAA of FSR2, zodat dunne kabels, fietsspaken en hekken niet flikkeren.

### Lichtbronnen buiten (kleurtemperatuur is heilig)
| Bron | Kleur | Gedrag |
|---|---|---|
| Lantaarnpaal (natrium, oude straat) | `#ffa04a` | Scherpe lichtpoel op de grond, schaduw aan bij elke 3e paal |
| Lantaarnpaal (LED, kade / nieuwbouw) | `#dfe8ff` | Koeler en strakker. Mix ze: zo ziet een echte stad eruit |
| Etalages | Per winkel, warm wit | Light texture / projector op de stoep (raamvorm zichtbaar) |
| Neonborden | Fel, klein | Weinig bereik, sterke reflectie in natte plassen |
| Maan + lucht | Koel blauw | Laag, voor contrast; nooit de hoofdbron in een straat |
| Ramen in gevels | 2700–4000 K mix | Per raam aan of uit, soms flikkerende tv-blauw |
| Koplampen | Spotlights | Echte SpotLight3D met korte schaduw. Remlicht kleurt de natte weg rood |

### Binnen (de kamer)
- Het monitorlicht is een echte bron: een blauwige spill op het gezicht van de speler, het bureau en de muur.
- Een bureaulamp van 2700 K met harde schaduw.
- Een maanlichtvlek door het raam, met de vorm van het raamkozijn (light texture).
- Licht van buiten **beweegt**: koplampen die over het plafond schuiven als er een auto langsrijdt.

---

## 5. Materialen en oppervlakken

### Bron
**ambientCG 1K PBR-sets (CC0)**: Asphalt, PavingStones, Bricks, Concrete, Plaster, Metal, Wood en Tiles. Ze staan in de openbare CC0-mirror (`github.com/Tiddybub/3d-assets/materials/...`) met per set een `SOURCE.md` en een `.tres`. Maak een licentiecheck en een regel in CREDITS.md per set.

### Regels
- **Triplanar** op gevels en straten, zodat er geen UV-werk nodig is. Schaal volgens de werkelijke maat (een klinker is 21×10,5 cm).
- **Breek herhaling** met een noise-mask die twee varianten mengt (schoon en vuil), plus decals.
- **Ruwheid bepaalt realisme:** droog asfalt 0,85, nat asfalt 0,15–0,3 (alleen in de plassen), glas 0,05, gelakt metaal 0,35, baksteen 0,9.
- **Normal maps zacht** (sterkte 0,4–0,6). Te sterke normals maken het "plastic realistisch".
- **Kenney- en Quaternius-modellen:** geen fototexturen erop. Wel de kleuren desatureren (−20%), lichte ruwheidsvariatie en ambient occlusion. Zo passen ze naast de PBR-vlakken zonder te botsen.

### Natte straat (het belangrijkste effect)
- Een shader op asfalt en klinkers: een `wetness`-uniform (0–1, gestuurd door het weer) verlaagt de roughness en maakt de albedo donkerder.
- Een **puddle-mask**: een world-space noise met drempel. In de plassen is de roughness bijna 0 en vlakken de normals af, zodat neon en lantaarns erin spiegelen.
- Bij regen: animated ripple normals in de plassen.

### Decals (Godot `Decal`-node) – de "gebruikt"-laag
Kauwgomvlekken, olievlekken onder geparkeerde auto's, scheuren, putdeksels, fietsstrepen, afvoerroosters, graffiti-tags (eigen ontwerp), posters en stickers op palen, vochtvlekken onder ramen en roest onder balkons.
**Regel:** elke 10 m² stoep heeft minstens 2 decals.

---

## 6. Architectuur: van Kenney-blokken naar een Rotterdamse straat

Kenney-gebouwen zijn goed voor de achtergrond, maar op straatniveau verraden ze de game. Daarom:

- **Straatgevels zelf bouwen, modulair:** een `FacadeBuilder` met
  - modules van 1 travee (± 4–5 m breed), 3–5 verdiepingen;
  - een plint (de begane grond met winkel) van 3,5–4 m hoog;
  - kroonlijsten, raamkozijnen met diepte (15 cm), dakranden;
  - baksteen (`Bricks`) of stucwerk (`Plaster`) per pand.
- **Typisch Rotterdam:** een mix van vooroorlogse bakstenen panden (smal, hoog, sierlijsten) en wederopbouw (strakker, beton, lange raamstroken). Aan de kade staan torens van glas en beton.
- **Diepte in gevels:** ramen liggen 15–25 cm terug, deuren hebben een drempel en een portiek. Plat geplakte ramen zijn de grootste "fake"-verklikker.
- **Interieurs achter ramen** via een interior mapping-shader (nep-kamers zonder geometrie), zodat verlichte ramen een kamer laten zien en geen egale vlak.
- **Daklijn:** schoorstenen, antennes, schotels, airco-units en een kraan in de verte.
- **Kenney blijft** voor de 2e en 3e rij, met de huidige night shader.

---

## 7. Props en straatmeubilair (dichtheid = realisme)

Per 20 m straat minimaal:
- 1 lantaarnpaal en 1 afvalbak (de groene Rotterdamse bak).
- 3–6 fietsen, waarvan 1 zonder voorwiel en 1 omgevallen.
- 1 element uit deze lijst: paaltje (Amsterdammertje-stijl), verkeersbord, ondergrondse container, elektriciteitskast, bloembak, reclamezuil.
- Kabels tussen de gevels (tramleidingen of feestverlichting).

Verder:
- **Tram:** een eigen low-poly tramstel op rails in de straat. Hij rijdt elke 7–10 game-minuten voorbij en belt. Dit is het sterkste "dit is Nederland"-signaal.
- **Fietspad** in rood asfalt langs de hoofdweg, met af en toe een fietser (NPC op fiets).
- **Verkeerslichten** op de kruising met echte cycli. Auto's stoppen ervoor.

Alle teksten (borden, posters, menu's) zijn eigen en fictief, zonder echte merken (ART_DIRECTION §9).

---

## 8. Leven en gedrag (realisme in tijd)

- **Openingstijden:**
  - Snackbar tot 03:00.
  - Coffeeshop tot 01:00.
  - Nachtwinkel 24/7.
  - Casino tot 06:00.
  - Muziekwinkel alleen overdag (daarom het rolluik dicht 's nachts, en de cashprijs alleen als je overdag gaat).
  - Een dichte winkel heeft een rolluik naar beneden en het licht uit.
- **Weer:** regen in ±40% van de nachten (het is Rotterdam), plus mist aan de kade en wind die vuilnis laat bewegen. Het weer stuurt de wetness-shader, de regenparticles, het geluid en hoeveel voetgangers er zijn.
- **Voetgangers met een doel:** van deur naar deur. Een groepje rookt voor de snackbar, iemand zoekt zijn sleutel voor Kade 17, een bezorger fietst voorbij. Rond 03:00 wordt het rustiger.
- **Verkeer:** taxi's bij het casino, een politieauto die soms langzaam voorbijrijdt (gekoppeld aan je noise en reputatie) en een vuilniswagen om 05:30.
- **Reactie op de speler:** NPC's kijken op als je dichtbij komt. Met reputatie herkent iemand je ("Yo, jij bent die producer van Kade 17?").

---

## 9. Geluid (de goedkoopste realismewinst)

- **Ambience-lagen** per plek:
  - straat: verkeer in de verte, tram, een fietsbel, gesprekken bij de snackbar;
  - kade: water tegen de kade, wind, een scheepshoorn in de verte, meeuwen;
  - kamer: de koelkast, de buren door de muur, de stad gedempt door het raam.
- **Voetstappen per ondergrond:** klinkers, asfalt, plas (spetter), trap, hout in de kamer.
- **Muziek uit winkels** gedempt tot je binnenkomt: het casino met slotmachine-ambience, de snackbar met frituurgeluid en radio.
- **Regen** op asfalt, op het raam van je kamer, en op autodaken.
- **Bron:** in code gegenereerd (zoals nu) of CC0 met een licentiecheck. Betaalde libraries alleen na akkoord van Sam (CLAUDE.md).

---

## 10. Personages

- Quaternius-modellen blijven, met realistischere kleding: desaturatie, donkere winterjassen, mutsen en sjaals (november).
- **Animatie verkoopt realisme:** idle-variaties zoals op de telefoon kijken, roken (zonder echte merken), de handen in de zakken en van voet wisselen. Een koude adem-puf (een kleine particle) bij kou.
- Geen "T-pose"-momenten: elke NPC heeft altijd een animatie.

---

## 11. Werkwijze

1. **Referentie eerst.** Elke nieuwe plek begint met 3–6 referentiebeelden (eigen foto's van Sam of een moodboard), opgeslagen in `docs/refs/<plek>/`.
2. **Blockout op schaal**, met de speler (1,8 m) als maatstaf.
3. **Licht**, nog voordat er details komen. Test met een "squint test": knijp je ogen dicht. Lezen de lichtvlekken en de compositie nog?
4. **Materialen** voor de grote vlakken, daarna de **decals**, daarna de **props**.
5. **Geluid en leven** erbij.
6. **Vergelijk** de screenshot naast de referentie en noteer 3 verschillen. Fix die, en pas dan de volgende plek.

---

## 12. Bouwfases (kleine stappen: na elke fase testen, screenshots maken, committen)

**R1. Licht en post (meeste winst, weinig werk)**
- SDFGI buiten, SSR, auto-exposure, LUT, TAA, kleurtemperaturen per tabel en light textures op de etalages.
- *Klaar wanneer:* `shot_city_street` en `shot_desk` de squint test en de checklist (§13) halen.

**R2. Natte straat en PBR-vlakken**
- ambientCG-materialen op straat, stoep (klinkers), kade en gevelplinten. Wetness- en puddle-shader en een eerste set decals.
- *Klaar wanneer:* neon en lantaarns zichtbaar spiegelen in plassen en er geen herhaling opvalt op 20 m.

**R3. Gevels**
- FacadeBuilder met baksteen en stuc, diepe ramen, interior mapping en daklijnen. De winkelstraat wordt opnieuw opgebouwd met echte panden.
- *Klaar wanneer:* een straatshot niet meer als "Kenney-kit" herkenbaar is.

**R4. Straatleven**
- Tram, fietspad, verkeerslichten, props op dichtheid, openingstijden en rolluiken, NPC-routines.
- *Klaar wanneer:* je 2 minuten stilstaat en minstens 5 dingen ziet gebeuren.

**R5. Weer en geluid**
- Regen- en mistsysteem, ambience-lagen, voetstappen per ondergrond en gedempte muziek.
- *Klaar wanneer:* regen de straat, het geluid en het aantal voetgangers zichtbaar en hoorbaar verandert.

**R6. Kamer**
- Dezelfde regels binnen: PBR-vloer en -muren, monitorlicht op het gezicht, bewegend licht van buiten, gebruikssporen.

Prestatie-eis bij elke fase: **60 fps op een middenklasse-gpu (GTX 1660 / RX 580) op Medium.** Elke zware optie (SDFGI, SSR, volumetrics) krijgt een setting.

---

## 13. Checklist bij elke screenshot

- [ ] Kloppen de schaal en de verhoudingen naast een persoon van 1,8 m?
- [ ] Zijn er minstens 2 kleurtemperaturen (warm natrium en koel LED/maan), met zachte schaduwen?
- [ ] Is geen enkel groot vlak egaal (asfalt, stoep, gevel hebben textuur, vuil of variatie)?
- [ ] Spiegelt iets in een nat oppervlak?
- [ ] Is neon ≤ 10% van het beeld en de saturatie ingetogen?
- [ ] Is minstens één "gebruikt"-detail zichtbaar (decal, vuil, kapotte fiets)?
- [ ] Is er iets Nederlands in beeld (fiets, klinker, tram, bord, container)?
- [ ] Beweegt er iets (mens, auto, tram, regen, vuilnis)?
- [ ] Werkt de squint test?
- [ ] Zou het naast een foto van de Witte de Withstraat geloofwaardig zijn als "gestileerde versie"?

---

## 14. Niet doen

- Fotoscans of high-poly assets naast Kenney-blokken. Die mix voelt goedkoper dan beide los.
- Overal een sterke normal map, waardoor alles er "plastic realistisch" uitziet.
- Bloom om slechte belichting te verbergen.
- Echte merken, logo's of herkenbare echte zaken. De Witte de Withstraat is inspiratie, geen kopie: geen echte cafénamen.
- Realisme dat gameplay hindert: de interactieve deur, de prompt en de winkel moeten altijd direct leesbaar blijven.
