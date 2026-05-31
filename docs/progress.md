# Edenemisraport

## Mis on valmis

- Docker Compose käivitab PostgreSQL-i, töövoo konteineri, scheduleri ja näidikulaua.
- OpenAQ API-st saab kätte valitud sensorite saasteainete tunni (keskmistatud?) kontsentratsiooni.
- Asukohad, sensorid, saasteained ja nende piirmäärad on eraldi staatilistes dimensioonitabelites.
- Andmed liiguvad `staging` kihist `mart` kihti.
- Andmekvaliteeditestid õnnestuvad ja on "passed" seisus.

  [
- `mart` kihis arvutatakse tunnipõhine sobivuse skoor ja 3-tunnised ajaaknad.
- Näidikulaud näitab ...
- Scheduler käivitab töövoo vaikimisi iga tunni alguses ning näidikulaud värskendab brauserivaadet automaatselt.]

## Järgmised sammud

- Lisada transformatsioonid vastavalt äriküsimusele.
- Kontrollida, kas andmed vastavad äriküsimusele.
- Täpsustada README järelduste ja piirangute osa.

## Mis takistab

- Kui OpenAQ API pole ajutiselt kättesaadav, tuleb laadimine hiljem uuesti käivitada.
- Kui port `8501` on hõivatud, tuleb `.env` failis muuta `DASHBOARD_PORT_HOST` väärtust.

## Kontrollpunkt

Viimane edukas käsurea kontroll:

```bash
docker compose exec pipeline python scripts/run_pipeline.py check
```

Oodatav tulemus: viimase laadimise real on `status = success` ja kvaliteeditestide olek on `passed`.
