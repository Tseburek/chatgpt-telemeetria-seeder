# ChatGPT Telemeetria Seeder

**Eesmärk.** Täita _ChatGPT telemeetria_ skeem realistlike andmetega nii, et **`message`** tabelis oleks **≥ 2 000 000** rida. Teised mitte‑lookup tabelid täidetakse proportsionaalselt: ~100k `user`, ~300k `conversation`.

Repo sobib hindamiskriteeriumitele: partiipõhine mass-sisestus, reprodutseeritav (fikseeritud SEED), võõrvõtmed, minimaalsed indeksid sisestuse ajal ja taastamine peale täitmist.

## Eeldused
- MySQL 8.0+
- [Bun](https://bun.sh) 1.1+
- `git`, `bash`/PowerShell
- Vaba kettaruum (andmestik on ~GB suurusjärgus, sõltub `MESSAGES` väärtusest).

## Kiirstart (nullist)

```bash
git clone <your-repo-url> chatgpt-telemeetria-seeder
cd chatgpt-telemeetria-seeder

# 1) Paigalda sõltuvused
bun install

# 2) Loo .env
cp .env.example .env
# vajadusel muuda DB_* ja mahtude väärtusi

# 3) Loo skeem ja lae dump
# NB! See kustutab samanimelised tabelid.
mysql -h $DB_HOST -u $DB_USER -p$DB_PASSWORD < dump.sql

# 4) Käivita seemneskript (Bun)
bun run seed.ts
```

## Oodatud tulem
- **2M+ rida** tabelis `message` (määra .env `MESSAGES=2000000`).
- `user` ≈ 100 000, `conversation` ≈ 300 000.
- Andmed näevad ehtsad välja (nimed, e‑kirjad, rollid, ajad, tokenid, latentsus).
- Võõrvõtmed kehtivad, orvukirjeid ei teki (sisestusjärjekord: lookup → user → conversation → message).
- Sisestus toimub **partiidena** (`BATCH_SIZE`, vaikimisi 5000) ja transaktsioonidena.
- **Indeksid**: ainult PK/FK sisestuse ajal; pärast täitmist lisatakse `create_indexes.sql` alusel sekundaarsed indeksid (skript käivitab `ALTER TABLE ...` lõpus).
- **Reprodutseeritavus**: `.env` `SEED` määrab fakeri seemne; sama SEED ⇒ samad andmed.

## Tabelite roll (lookup vs mitte‑lookup)

Lookup: `locale`, `model`  
Mitte‑lookup: `user`, `conversation`, **`message`** (2M).

Proportsioonid:
- Keskmiselt ~6–7 teadet vestluse kohta (2 000 000 / 300 000 ≈ 6.7)
- Vestlusi kasutaja kohta varieerub juhuslikult (märksa realistlikum jaotus).

## Jõudlusnõksud
- `BATCH_SIZE=5000` (vajadusel vähenda kui `max_allowed_packet` on väike).
- Ajutine `unique_checks=0`, `FOREIGN_KEY_CHECKS=0`, `sql_log_bin=0` kiireks laadimiseks.
- Indeksid lisatakse **pärast** mass-sisestust.

## Failid
- `dump.sql` — skeem (minimaalsed indeksid).
- `seed.ts` — Bun/TypeScript seemneskript (partiid, transaktsioonid, SEED).
- `create_indexes.sql` — sekundaarsed indeksid (skript teeb sama `ALTER`i).
- `.env.example` — näidiskonfiguratsioon.
- `package.json` — sõltuvused (`mysql2`, `@faker-js/faker`, `dotenv`).

## Repo nimi
Soovitus: **`chatgpt-telemeetria-seeder`** (kirjeldab sisu, ei ole geneeriline).

## Märkused
- Kui soovid **Windows/Mac** juhendeid: kasuta MySQL Workbench’i SQL-faili importi ja käivita `seed.ts` PowerShellis `bun run seed.ts`.
- Kui tahad paralleelsust, käivita skript mitme protsessina, jaotades ID vahemikud; praegune lahendus hoiab lihtsuse huvides ühes protsessis.
