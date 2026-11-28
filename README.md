# Studio Grind (prototype v0.13)

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
| Shift | Sprinten |
| Ctrl (vasthouden) / C (aan-uit) | Bukken (langzamer, stiller, vignet aan de randen) |
| Z | Liggen (plat op de grond); SPATIE = stap voor stap weer opstaan |
| SPATIE | Springen / opstaan / van stoel of bed af |
| F | Zaklamp |
| W/S/A/D op de e-step | Gas, remmen, sturen (B = bel, E of SPATIE = afstappen) |
| Y / N | Telefoon opnemen / weigeren |
| E | Interactie: monitor = LOOPR, stoel = zitten, bed = liggen (nog een keer E = slapen), lichtknop, deur, winkels, mensen aanspreken, kat aaien, bankjes. Losse spullen (blikjes, fles, bal, doos) oppakken / neerleggen |
| Linkermuis / rechtermuis | Opgepakt voorwerp gooien / neerleggen |
| 1–4 | Keuze in een gesprek (of pattern A–D in LOOPR) |
| 1–6 | Item uit je hotbar gebruiken (joint, RAKET, pils, water, brood, kraslot), als er geen menu open is |
| U | Paraplu open/dicht |
| E (bij het vissen) | Binnenhalen als de dobber zakt |
| D F J K / pijltjes | Spelen op de BEAT DROP-kast |
| TAB | Telefoon (GRIND OS): Messages, Phone, WAVR, Gear, Huisraad, Ruilmarkt, Zoef, Settings |
| Ctrl+S | Project opslaan in LOOPR (beschermt tegen een pc-crash) |
| Ctrl+Z | Ongedaan maken in LOOPR |
| F9 | Grafische kwaliteit High/Low (Low = sneller op zwakke pc's) |
| SPATIE | Beat afspelen/stoppen (in LOOPR) |
| ESC | LOOPR, menu of arcade sluiten / muis vrijgeven |

Vereist een videokaart met Vulkan-ondersteuning; dat heeft vrijwel elke pc van na 2016.

## Zo speel je een sessie
1. Druk **TAB** en boek een rapper (Big Earl en Lil Tear zijn open; Ghost unlock je met 8 Street Cred, Spike met 12 reputatie. Elke rapper kan één keer per nacht).
2. De rapper loopt binnen en gaat in de booth staan.
3. Ga achter de pc (**E**) en maak in LOOPR een beat die past bij de brief bovenin.
4. Klik **RECORD TAKE**. De rapper rapt twee maten en geeft een oordeel (1–5 sterren). Elke retake kost geduld.
5. Klik **FINISH** om de beste take uit te brengen. Je krijgt geld, reputatie en Street Cred.
6. Pas op met het volume: de geluidsmeter loopt op. Bij 100% belt de buurman de politie (€40 boete).

## In v0.13: leven op straat
- **Energie (groene balk onder de geluidsmeter):** loopt leeg door de nacht, sneller bij sprinten en in de regen zonder paraplu. Leeg = moe, trager.
- **Hotbar (toets 1–6), te koop in de nachtwinkel en de coffeeshop:**
  - **Joint:** je loopt trager, beeld warm en dof, geluid gedempt. Volgende rapper +1 take. Later trek (munchies).
  - **RAKET** (energiedrank): sneller sprinten, langer op. Daarna een crash, en bij te veel gaat je hart racen.
  - **Pils:** moed bij de open mic, maar je zwalkt. Dronken op de step bij de politieauto = €80 boete.
  - **Water:** nuchter worden, crash voorbij.
  - **Brood:** duiven voeren, of zelf eten tegen de trek.
  - **Kraslot** "Maas Miljoen" (€2): kansen staan op de achterkant, gemiddeld krijg je ~55% terug.
- **Ook nieuw:**
  - **Koffie** bij de kiosk op Centraal.
  - **Eten** bij de snackbar en de döner.
  - **Keelspray** voor je rapper: +5 op de volgende take.
  - **Paraplu** (U).
- **Vissen** aan de kade en in de haven (hengel €15 in de nachtwinkel):
  - E bij de reling gooit uit. Zakt de dobber, druk dan op tijd E.
  - Je vangt vis (Ome Kees koopt hem voor €4), rommel, fietsen, portemonnees, soms een kluisje of de kwijtgeraakte telefoon van een rapper.
- **Fresh Fades en Drip Depot (Marktplein):**
  - Een fade of line-up en kleding (één stuk per plek: hoofd, top, nek, voeten) geven **DRIP**.
  - Wat drip doet:
    - Bouncer Mo van De Kraan laat je pas binnen bij 4+ drip (of een tientje).
    - Extra punten bij de open mic.
    - Mensen herkennen je eerder.
    - Rappers betalen +1% per punt (max +10%).
  - Een fade groeit na 2 nachten uit.
- **KADE RUN (e-step tijdrit):**
  - Rij met je step door de startpoort op de kade (oost). De klok start als je de lijn passeert.
  - Route: 6 poorten langs het water, de zijstraat in en over de hoofdweg (met verkeer).
  - Versla Mo (36 s), Jesse (28 s) en Bilal (21 s, alleen met een getunede motor) voor €15/€30/€75 + CRED. Elke prijs krijg je één keer.
  - Je beste tijd staat op het bord.
- **BEAT DROP** (snackbar, €1 per potje): ritmespel met 4 banen (D F J K).
  - Perfect = 300 punten, goed = 100. Combo's vermenigvuldigen tot ×4.
  - Versla MO, DJ R en KEES op de kast voor prijzen.
  - Bij 20.000+ krijg je één keer per nacht "warme vingers": +1 take bij je volgende rapper.
- **Fix:** toetsen 1–6, U, E bij het vissen en de cijfers/ESC in gespreksmenu's werkten niet. Nu wel.

## In v0.12.1: zwartrijden en controleurs
- **Kies bij elke rit bij de kaartlezer:** inchecken (€2) of niet.
- **Controle tijdens de rit:** de kans is 30% in de metro en 22% in de tram. Een controleur (marineblauwe pet, kaartlezer in de hand) komt naar je bank en vraagt om je kaart.
  - Ingecheckt: *piep*, groen, je rijdt door.
  - Zwart gereden, je hebt drie keuzes:
    - **Boete betalen:** €50. Je kunt ermee in het rood komen.
    - **Smoesje** ("mijn kaart piepte niet..."): 30% kans dat het werkt, hoger met meer Street Cred. Werkt het niet, dan €50 en −1 REP.
    - **Wegrennen bij de halte:** de deuren gaan open en je sprint weg. 50% kans dat je ontsnapt (+1 Street Cred), anders word je bij de deur gepakt (€75 en −1 REP).
- **Wegklikken (ESC)** = je betaalt de boete.
- **De trein of tram wacht met de deuren open** tot het gesprek klaar is.

Rekensom: zwartrijden kost je gemiddeld meer dan inchecken. Je doet het voor de Street Cred, niet voor het geld.

## In v0.12: metro, tram en drie nieuwe wijken
- **Metro (4 stations):** Zuidkade → Centraal → Marktplein → Havenkwartier.
  - Ga via het glazen paviljoen met de rode M naar beneden (E).
  - Er komt een trein uit de tunnel die afremt en de deuren opent.
  - E bij de deuren → bestemming kiezen → €2 inchecken (*piep*). Je gaat zitten, de deuren sluiten en de trein trekt op; de tunnellampen flitsen voorbij.
  - Je rijdt het volgende station binnen, stapt uit op het perron en neemt de roltrap (EXIT) naar de straat.
  - Een vertrekbord laat zien wanneer de volgende trein komt.
- **Tram 4** rijdt tussen Zuidkade, Centraal en Marktplein.
  - De tram remt af bij de halte (abri) en de deuren gaan open aan de stoepkant.
  - E vanaf de stoeprand → bestemming → zitten → hij rijdt de straat uit en jij komt aan bij de halte van de andere wijk.
- **Centraal (Stationsplein):**
  - stationshal met puntdak en verlichte letters, fietsenrekken, taxistandplaats;
  - kiosk: koffie €3, +30 min wakker;
  - buskingplek: 30 min je beats spelen voor fooi (minder bij regen).
- **Marktplein:**
  - markthal-boog met gloeiende glazen gevel en gesloten marktkramen;
  - **Huisraad-warenhuis** (alle meubels 15% goedkoper in de winkel);
  - **Döner Palace** (wakker blijven).
- **Havenkwartier:**
  - kade met kranen, containers en water;
  - club **De Kraan** (23:00–05:00, rij + uitsmijter): open mic voor €10, één keer per nacht. Het publiek reageert op je beste release en je level (REP, CRED, fooi). Of gewoon dansen voor de chill-buff.
- **Elke wijk** heeft eigen voetgangers met naam en persona (je kunt ze aanspreken), regen, straatlicht en decals.

## In v0.11: doelen, levels, streak en huur
- **Goals-app:** altijd 3 actieve doelen (17 in totaal, van "eerste track" tot "100.000 streams") met geld, REP en XP als beloning. Een melding verschijnt zodra je er een haalt.
- **Producer-level:** XP voor sessies, ritten en doelen. Elk level geeft een bonus (€25 × level).
- **Release-streak:** elke nacht een track = streams +10% per nacht (tot ×1,5). Eén gemiste nacht wordt vergeven.
- **Huur:** €100 per week. Zonder geld sta je rood en kun je niets kopen.
- **Platen aan de muur:** goud bij 25k streams, platina bij 100k, diamant bij 500k (boven je bed).

## In v0.10: telefoon, e-step, inrichten en bijbaantje
Masterplan: docs/PROGRESSION_MASTERPLAN.md (P1–P4 gebouwd, P5–P6 gepland).
- **GRIND OS:** homescreen met app-iconen en badges.
  - Messages: chats per contact; rappers DM'en elke nacht, plus Mama, Buurman Henk, Zoef en Ruilmarkt.
  - Phone: gesprekslog.
  - Andere apps: WAVR (streams), Gear, Huisraad, Ruilmarkt, Zoef, Settings.
  - Meldingen schuiven bovenin beeld.
- **Rappers bellen je.** Opnemen (Y) thuis = direct sessie met +15% ("hot session"). Op straat zegt de rapper "ik ben er over 40 min": wees op tijd thuis, anders vertrekt hij (−1 REP). Uitnodigen via Messages vanaf straat werkt hetzelfde.
- **E-step** (Ruilmarkt, €120):
  - opstappen met E; W/S/A/D, bel op B;
  - snelheid en batterij in de HUD;
  - te hard ergens tegenaan = eraf vallen; een voetganger raken = −1 REP;
  - parkeer hem bij je voordeur als je naar binnen gaat, dan laadt hij 's nachts op;
  - upgrades: Motor tune (31 km/u), Grote accu (2× bereik).
- **Huisraad:** 14 meubels in 6 plekken (zitplek, kleed, tafel, voorwand, wandkunst, lamp). Kamerstats:
  - VIBE = meer sessiegeld (tot +30%), en vanaf 12 een extra take;
  - AKOESTIEK = de geluidsmeter loopt trager op;
  - COMFORT = je blijft langer op.

  De verhuisdozen verdwijnen zodra er iets aan de voorwand staat. Een minikoelkast ontgrendelt "drankje aanbieden".
- **Ruilmarkt:** elke nacht één tweedehands meubel met 30% korting.
- **Zoef (bijbaantje):** eten ophalen bij Snackbar De Hoek en afleveren bij een deur (lichtbaken). Je verdient €6–14 plus fooi voor snelheid (+30% bij regen); te laat = half loon. Met de step haal je meer ritten en fooi per nacht.

## In v0.9.1: Rotterdamse skyline
- Over de Maas: een witte tuibrug met geknikte "zwanenhals"-pyloon, 40 tuien, basculedeel en verlicht dek, een uitkijktoren met kraaiennest en ring in het park, een markthal-boog met gloeiende glazen kopse kanten, gekantelde gele kubuswoningen naast een potloodtoren, een cluster hoge torens (gestapelde verschoven blokken, slanke toren met lichtkroon, toren met overstek), een leunend kantoor met ledgevel en een rood gestreepte toren.
- Verre oever met kade, lantaarns en lichtreflecties op het water; nevel op afstand (dikker bij regen en mist).
- Silhouetten zijn herkenbaar, maar er staan geen echte namen of logo's op.

## In v0.9: details en NPC-interacties
- **Houdingen:** sprinten (FOV wordt breder), bukken (Ctrl/C) en liggen (Z) met een donker vignet, hoofd-ruimtecheck (je kunt niet opstaan onder een tafel), voetstappen per ondergrond (hout, steen, nat), landingsdip en -geluid, zaklamp.
- **Zitten en liggen:** op de bureaustoel achter de pc, op bankjes op straat en aan de kade, op bed liggen (naar het plafond kijken; E = slapen).
- **Physics-props:** blikjes, fles, doos, bal en pionnen oppakken en gooien, met tikgeluid. Raak je iemand, dan wordt die boos en onthoudt dat.
- **Kamer:** lichtknop bij de deur zet de ledstrips uit en aan.
- **Voetgangers hebben een naam en een persona** (student, nachtdienst, zakenvrouw, local, roker, uitsmijter). Gespreksmenu: praten, flyer uitdelen (+REP, max. 5 per nacht, soms DM't er een rapper), je laatste track laten horen (bij 4+ sterren gaan ze dansen), dappen. Ze onthouden of ze je kennen, of je ze al een flyer gaf en of je irritant was.
- **Reacties:** botsen ("Hé, watch where you're going!"), staren (na 2,5 s), achter iemand sluipen, op straat liggen ("Should I call 112?"), geraakt worden door een blikje. Rokers voor de deur praten met elkaar; bij regen rennen voetgangers.
- **Rappers in de studio:** praat ermee voor de brief, hype ze op (+5 punten op de volgende take), geef ze iets te drinken (+1 take, één keer per sessie) of small talk per stijl.
- **Dieren:** een zwerfkat bij de snackbar (vlucht als je rent, komt naar je toe als je bukt; aaien = één keer per nacht +1 take), duiven op de kade die opvliegen als je te dichtbij komt.
- **Straat:** stoom uit de putten, losse blikjes en flessen.

## In v0.8: realisme 2.0
- Nieuwe belichting buiten: filmische kleuren, lichtterugkaatsing, natte straten die neon en lantaarns spiegelen, mist, gemengde natrium- en LED-lantaarns, licht uit etalages op de stoep, koplampen
- Echte materialen (CC0): asfalt, stoeptegels, kasseien, baksteen, beton, stucwerk
- Rotterdamse panden in plaats van speelgoedblokken: diepe kozijnen, kamers achter de ramen, regenpijpen, schoorstenen, dichte winkels met rolluik en graffiti
- Vuil en slijtage: kauwgom, olievlekken, scheuren, putdeksels, roosters
- Openingstijden: muziekwinkel tot 00:00, coffeeshop tot 01:00, snackbar tot 03:00
- Weer per nacht: regen, mist of droog
- Tram met rails en bovenleiding, verkeerslicht, verkeer rijdt rechts, rokers bij de snackbar; met genoeg REP herkennen mensen je
- Stadsgeluid: regen, verkeer, water bij de kade, trambel
- In je kamer zie je koplampen van auto's over het plafond glijden

## In v0.7: de buitenwereld (Zuidkade)
- Loop via je voordeur naar buiten: een nachtelijke straat in een havenstad, met verkeer, voetgangers, fietsen, bushalte, een kade met de rivier, een tuibrug en een skyline
- **Wax & Wires**: muziekwinkel, alle gear/kits/synths 15% goedkoper dan online
- **Lucky Stack**: casino met slots en roulette (de bank wint op de lange termijn)
- **Groene Wolk**: coffeeshop; pre-roll = volgende rapper +1 take geduld
- **Snackbar De Hoek** en **Nachtwinkel**: kapsalon/frikandel/energy = langer wakker; stroopwafels voor de buren = noise reset
- **Maas Sound Studios**: pro-studio (later te huren vanaf 40 REP)
- Je kunt niet weg tijdens een sessie en niet vanaf straat boeken

## In v0.6: LOOPR 2.0
- **Channel Rack**: slepen om te tekenen, rechtsklik wist. Tools: DRAW, VELOCITY (zachte ghost notes) en ROLL (2–4 hits per stap, voor hi-hat-rolls)
- **Swing** (0–60%) voor boom bap-bounce
- **Piano Roll** met twee lanes: MELODY en **808** (eigen toonhoogte per noot, plus GLIDE voor drill- en rage-slides)
- **Patterns A–D** met CLONE om variaties te maken, en een **Playlist** van 8 maten. PAT speelt het huidige pattern af, SONG het hele arrangement
- **Volledig nummer** (4+ maten, 2+ patterns) = ×1.5 streams na het slapen
- **Mixer**: live meters, PAN, REVERB, LO-CUT, SOLO en een clip-waarschuwing. Clippen kost punten
- Rappers letten nu ook op feel (swing, ghost notes, rolls, bewegende 808, glide) en op de mix (reverb of juist droog, niet clippen)
- UNDO (Ctrl+Z)

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
