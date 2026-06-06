# Eesti õhukvaliteedi seire
Projekti näol on tegu väikese otsast lõpuni ehitatud andmetöövooga, mis tugineb OpenAQ õhukvaliteediandmetele. Esmalt salvestatakse OpenAQ API-st päritud kolme Eesti suurema linna andmed PostgreSQL-i. Edasiste tranformatsionide abil leitakse järgnev: 1) õhus leiduvate saasteainete ööpäevased miinimum- ja maksimumväärtused kõigis kolmes linnas ning 2) kontrollitakse, kas kõiki saasteaineid esineb õhus lubatud normi piires vastavalt Riigiteatajas toodud piirväärtustele (https://www.riigiteataja.ee/aktilisa/1060/3201/9012/KKM_m8_lisa1.pdf#). Projekt kontrollib ka andmekvaliteeti ning kuvab tulemusi Superseti näidikulaual. Scheduler ehk ajastaja konteiner värskendab andmeid vaikimisi iga tunni alguses.

## Äriküsimus

Kuidas erineb õhukvaliteet Eesti suuremates linnades (Tallinna, Tartu, Narva) ning kui sageli ületavad peamised saasteained kehtestatud õhukvaliteedi piirväärtuseid? 


**Mõõdikud:**

1. Päevane näitajate kõikumine (min/max + aeg)
2. Piirväärtuste ületamise arv mingis ajaühikus (seadus määrab ületamiseks erinevad keskmistamise perioodid)


## Arhitektuur


<img width="1626" height="659" alt="image" src="https://github.com/user-attachments/assets/29fee42b-cffe-42aa-bcd9-82aa9fb64aee" />


## Andmestik

| Allikas | Tüüp | Ajas muutuv? | Roll |
|---------|------|--------------|------|
| OpenAQ API | Avalik HTTP API | Jah, iga 1 tund, 2-3 tunnise viitega reaalajast | Põhiandmevoog |
| mart.dim_location | Staatiline dimensioonitabel | Ei, staatiline | Asukohtade püsivad tunnused ja API päringu koordinaadid |
| mart.dim_parameter | Staatiline dimensioonitabel | Ei, staatiline | Saasteainete püsivad tunnused |
| mart.dim_parameter_limits | Staatiline dimensioonitabel | Ei, staatiline | Saasteainete piirväärtused Eestis/EUs |
| mart.dim_sensor | Staatiline dimensioonitabel | Ei, staatiline | Sensorite püsivad tunnused |

## Stack

| Komponent | Tööriist |
|-----------|---------|
| Sissevõtt | Python |
| Transformatsioon | SQL |
| Andmehoidla | PostgreSQL |
| Näidikulaud | Superset |
| Orkestreerimine | cron |

## Käivitamine

```bash
# 1. Klooni repo ja liigu kausta
git clone https://github.com/LauraEdenberg/Andmeinseneeria-grupitoo_Eesti-ohukvaliteedi-seire.git
cd Andmeinseneeria-grupitoo_Eesti-ohukvaliteedi-seire

# 2. Kopeeri keskkonnamuutujad
cp .env.example .env
# Muuda .env failis paroolid ja muud seaded vastavalt vajadusele

# 3. Käivita teenused
docker compose up -d --build

# 4. [Vabatahtlik: käivita sissevõtt käsitsi]
docker compose exec pipeline python scripts/run_pipeline.py run-all

# 5. [Vabatahtlik: vaata võimalikke töövoo samme, mida käivitada]
docker compose exec pipeline python scripts/run_pipeline.py --help
```

Näidikulaud: http://localhost:8088

Näidikulaua vaatamiseks impordi supersetis dashboard .zip failist repositooriumi kaustas /superset/dashboard/.

Näidikulaud värskendab andmevaadet vaikimisi iga 15 sekundi järel. Seda saab muuta .env faili väärtusega DASHBOARD_AUTOREFRESH_SECONDS. Väärtus 0 lülitab automaatse värskenduse välja.

## Saladused ja konfiguratsioon

Kõik saladused (paroolid, API võtmed, andmebaasi URL-id) on `.env` failis. Repos on ainult `.env.example`, mis näitab vajalike muutujate struktuuri ilma tegelike väärtusteta. Päris `.env` faili ei tohi GitHubi panna - see on `.gitignore`-s.

Vajalikud muutujad:

| Muutuja | Tähendus | Näide |
|---------|----------|-------|
| `POSTGRES_PASSWORD` | PostgreSQL parool | (saladus) |
| `SUPERSET_DB_PASSWORD` | Superset'i metaandmebaasi parool | ... |
| `SUPERSET_SECRET_KEY` | 	Superset'i sessiooniküpsiste krüptovõti | ... |
| `SUPERSET_ADMIN_USER / SUPERSET_ADMIN_PASSWORD` | Superset'i admin-kasutaja | ... |
| `OPENAQ_API_KEY` | APIst andmete alla laadimiseks vajalik võti | ... |
| `BACKFILL_DAYS` | Mitme päeva jagu andmeid alla laetakse (vaikimisi 7) | ... |
| `[teised]` | ... | ... |

## Andmevoog lühidalt

1. **Sissevõtt** — Skript loeb dimensioonitabelitest aktiivsed sensorid (mart.dim_sensor, mis seob iga sensori asukoha ja saasteainega) ning pärib OpenAQ API-st iga sensori kohta valitud ajavahemiku (vaikimisi viimased 7 päeva) tunnipõhised mõõtmistulemused.
2. **Laadimine** — Andmed laaditakse `staging` kihti (tabel.staging_parameter_values_raw), kus iga laadimist jälgitakse staging.pipeline_runs tabelis. Korduval laadimisel olemasolevad read uuendatakse (ON CONFLICT (sensor_id, period_from)).
3. **Transformatsioon** — Toorandmed viiakse staging kihist mart.fact_measurement faktitabelisse (ühendades sensorid asukohtade ja parameetritega). Edasi arvutatakse mart.parameter_min_max tabelisse päevased min-, max- ja keskmised väärtused asukoha ja saasteaine kaupa. Piirmäärade ületamisi hinnatakse vaates mart.v_limit_exceedances, mis võrdleb mõõtmistulemusi mart.dim_parameter_limits piirmääradega eri keskmistamisperioodide kaupa (tunnipõhine, ööpäeva keskmine ja aasta keskmine) ning annab selle põhjal hinnangu, kas väärtused on normi piires või ületavad normi.
4. **Testimine** — 9 andmekvaliteedi testi kontrollivad töövoo ja andmete korrektsust
5. **Näidikulaud** — Näidikulaud näitab mart tabelite ja vaadete põhjal sisse võetud mõõtmiste arvu, nende keskmist väärtust, piirmäärade ületamise arvu ja kuvatud mõõtmiste ajavahemikku. Graafikutel on näha keskmine kõigi saasteainete taseme muutus ajas ning samuti keskmised mõõdetud tasemed saasteainete lõikes linnade kaupa. Eraldi on lisatud graafik Lämmastikdioksiidi (NO₂) kõikumistest päeva jooksul, sest see on kõige tundub liiklussaaste näitaja. Näidikulaua alumises osas on visualiseeritud päevane näitajate kõikumine ja piirväärtuste ületamised tabelitena inimloetaval kujul. 

## Andmekvaliteedi testid

Projekt kontrollib järgmist:

1. koodi käivitamisel tekivad read järgnevatesse tabelitesse: asukohtade dimensioon (mart.dim_location), parameetrite dimensioon (mart.dim_parameter), sensorite dimensioon (mart.dim_sensor), saasteainete piirväärtuste dimensioon (mart.dim_parameter_limits) ja toorandmete tabel staging.parameter_values_raw;
2. sama sensori, kuupäeva ja kellaaja kohta ei teki duplikaate;
3. saasteainete kontsentratsioonid ei ole negatiivsed;
4. mart.parameter_min_max tabelis ei ole minimaalne ega maksimaalne väärtus NULL;
5. mart.v_limit_exceedances vaates ei ole piirväärtuste ületamise arv NULL.

Testide tulemused salvestatakse tabelisse quality.test_results.

## Projekti struktuur

```
.
├── README.md
├── compose.yml
├── .env.example
├── .gitattributes
├── .gitignore
├── abiinfo
├── Dockerfile.app
├── Dockerfile.superset
├── docs/
│   ├── arhitektuur.md      ← nädal 1 väljund
│   └── progress.md         ← nädal 2 väljund
├── init/                    
│   └── 01_create_objects.sql
├── scripts/
│   ├── 01_seed_dimensions.sql
│   ├── transform.sql
|   ├── quality_tests.sql
|   ├── check_results.sql
|   ├── requirements.txt
|   ├── run_pipeline.py
|   └── start_cron.sh
├── superset/
|   ├── dashboard
|   |   └── eesti-ohukvaliteedi-seire_dashboard.zip
|   └── superset_config.py

```

## Kokkuvõte, puudused ja võimalikud edasiarendused

**Kokkuvõte:**
- Docker Compose käivitab viis teenust: andmebaas (db, pgduckdb-põhine Postgres, mille skeem ja tabelid luuakse init-skriptidega kaustast ./init), käsitsi käivitatav töövoog (pipeline), ajastatud töövoog (scheduler, mis jooksutab pipeline'i automaatselt cron-graafiku alusel kord tunnis) ning näidikulaud (superset) koos selle abiteenustega (superset-db Superseti metaandmete jaoks ja ühekordne superset-init algseadistuseks). 
- Andmete sissevõtt OpenAQ API-st töötab — sensorid loetakse mart.dim_sensor-ist ja iga sensori mõõtmised laaditakse staging.parameter_values_raw tabelisse, koos laadimiste jälgimisega staging.pipeline_runs-is.
- Transformatsioon viib toorandmed mart.fact_measurement faktitabelisse ja arvutab mart.parameter_min_max tabelisse päevased min/max/keskmised väärtused asukoha ja saasteaine kaupa.
- Piirmäärade ületamiste hindamine on lahendatud vaatega mart.v_limit_exceedances, mis võrdleb mõõtmistulemusi tabelis mart.dim_parameter_limits toodud piirväärtustega ja aastase lubatud ületamiste arvuga. Seejuures arvutatakse mõõtmistulemuste keskmised väärtused erinevatele keskmistamise perioodidele sõltuvalt parameetrist, võrreldakse neid kehtestatud piirväärtusega ning loendatakse seejärel, mitu piirväärtuse ületamist ühes aastas esineb. Aastast ületamise arvu võrreldakse seejärel lubatud ületamiste arvuga ning antakse lõplik hinnang. 

**Puudused:**
- Andmeteisendus ei järgi ühtset mustrit: 1) ööpäevaste kõikumiste leidmisel salvestatakse tulemused nii tabelisse kui koostatakse eraldi vaade, 2) parameetrite piirväärtuste ületamist arvutav teisendus on seevastu lahendatud ainult vaatena. Mõlemal juhul koostati vaated selleks, et oleks teisendusi võimalik inimloetaval ja esitletaval kujul lihtsasti Superseti tarbeks rakendada. Sellegipoolest muudab selline dokumenteerimata ja ebaühtlane lahendus koodi raskemini loetavaks - seda nii teistele grupiliikmetele praegu kui ka tegijale endale hiljem, sest detailid ununevad. Edaspidi oleks mõistlik alustada (dokumenteeritud) kokkuleppest, millise mustri järgi iga kihi andmeteisendused tehakse.
- API päring salvestab andmekvaliteedinäitajaid percent_complete ja has_flags, aga parameetrite piirväärtuste ületusi kontrolliv andmeteisendus jätab need näitajad kasutamata. Seega hinnangu andmisel kasutatakse kõiki andmeid sõltumata nende kvaliteedist (nt ööpäevaseid keskmisi arvutatakse hoolimata sellest, kui ühes linnas ühe sensoriga on mõõtmistulemuste katvus vaid 20% ehk suurem osa ööpäevaseid mõõtmisi puudub). Samal ajal parameter_min_max kasutab has_flags kvaliteedinäitajat. Seega lisaks on siin ebaühtlane muster kvaliteedinäitajate kasutusel. Edaspidi tuleks välja selgitada kehtivad andmekvaliteedinõuded (nt minimaalne nõutav katvus) ja täiendada teisendust nende järgi, et tulemused oleksid usaldusväärsed ja kvaliteedinäitajate kasutus ühtne.
- Sensorite ja asukohtade andmed on sisestatud staatilistesse dimensioonitabelitesse käsitsi, kuid ideaalis tuleks need pärida vastavaid API endpointe kasutades otse OpenAQ-st, et vältida sisestamisvigu.
- Puudub hea kontrollmehanism, mis tuvastaks ja annaks hoiatuse, kui OpenAQ APIs andmed pikema perioodi vältel ei uuene (nt tavapärasele 2-3 tunnisele viitele oleme näinud projekti käigus ka 9+ tunnist viidet).
- [Loetle ausalt, mis jäi tegemata - see ei mõjuta hinnet negatiivselt, vaid aitab hinnata]

**Mis edasi:**
- Ühe ajapuuduse tõttu välja jäänud parameetri (osoon) lisamine mart.v_limit_exceedances vaatesse. See oleks põnev ära lahendada, kuna vajab võrreldes teiste parameetritega erinevat loogikat (libiseva 8h keskmise väärtuse võrldus piirimääraga).
- Hoiatus(alert), kui mitu pipeline jooksu järjest ei tooda sisse uusi andmeid.

## Meeskond

| Nimi | Roll |
|------|------|
| Keit Prants | Andmeallika omanik |
| Laura Edenberg | Transformatsioonide omanik |
| Anni Burk | Kvaliteedi omanik |
| Merje Pungits | Näidikulaua omanik |
