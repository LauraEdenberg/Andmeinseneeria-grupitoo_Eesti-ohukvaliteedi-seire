# Edenemisraport

## Mis on valmis

- Docker Compose käivitab PostgreSQL-i, töövoo konteineri, scheduleri ja näidikulaua.
- OpenAQ API-st saab kätte valitud sensorite saasteainete tunni kontsentratsiooni.
- Asukohad, sensorid, saasteained ja nende piirmäärad on eraldi staatilistes dimensioonitabelites.
- Andmed liiguvad `staging` kihist `mart` kihti.
- Andmekvaliteeditestid õnnestuvad ja on "passed" seisus.
- Scheduler käivitab töövoo vaikimisi iga tunni alguses.

## Järgmised sammud

- Luua visuaalid vastavalt äriküsimusele ja mõõdikutele.
- Lisada täiendavad transformatsioonid vastavalt äriküsimusele.
- Kontrollida, kas APIst päritud andmed vastavad äriküsimusele.
- Täpsustada README faili.

## Mis takistab

- Ei jõudnud luua visuaali, sest sellele eelnevate sammude viimistlemine voos võttis aega, seega ei saa ka kindel olla, et kõik muu töötab nii nagu superseti jaoks vaja.
- Kui OpenAQ API pole ajutiselt kättesaadav, tuleb laadimine hiljem uuesti käivitada.
- Kui port `8501` on hõivatud, tuleb `.env` failis muuta `DASHBOARD_PORT_HOST` väärtust.

## Kontrollpunkt

Viimane edukas käsurea kontroll:

```bash
docker compose exec pipeline python scripts/run_pipeline.py check
```

Oodatav tulemus: viimase laadimise real on `status = success` ja kvaliteeditestide olek on `passed`.
