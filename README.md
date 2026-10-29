# BDRC Handinvoer – Hana Bank

Met `invoer.html` voert een medewerker een **nieuwe klant** in. De pagina controleert de invoer en maakt een `.sql`-bestand dat in SSMS wordt uitgevoerd. Dat schrijft de klant naar de database `BDRC_Handinvoer`. Bij elke BDRC-import worden die gegevens samen met de CSV's in staging gezet. Zo blijft de klant bewaard, ook nadat staging is leeggemaakt.

Alles draait offline in de browser (Edge of Chrome); er wordt niets opgeslagen of verstuurd.

## Eenmalige installatie
1. Open `sql/01_create_handinvoer.sql` in SSMS op de backoffice-server (192.168.1.31) en voer uit. Het maakt `BDRC_Handinvoer` aan (zelfde collation als `MyletteBDRC`) met de tabellen `Customer`, `Product`, `Address` en `Relation`. Veilig om opnieuw te draaien. In `MyletteBDRC` wordt niets aangemaakt.
2. Zet `sql/02_handinvoer_naar_staging.sql` klaar bij de importscripts.

## Een klant invoeren
1. Open `invoer.html` door erop te dubbelklikken.
2. Vul uw naam in. Laat de database op `MyletteBDRC` staan (`Test_BDRC` om te testen).
3. Vul klant, adres(sen), rekening(en) en eventueel UBO's in. Een nieuwe rekening is altijd op naam van de klant als `AccountHolder`; een bestaande rekening kan ook met de rol gemachtigde.
4. Klik op **SQL maken**. Fouten staan bij het veld; los ze op en klik opnieuw.
5. Controleer het overzicht en klik op **SQL-bestand downloaden** (of kopieer de tekst).
6. Open het bestand in SSMS en voer het uit. Het script draait in één transactie: bij een fout (bijv. `Klantnummer GEUNL01900028821 bestaat al.`) wordt alles teruggedraaid. Bij succes verschijnt `Klaar: …`.

## Importvolgorde
1. `EXEC p_clear_staging`
2. CSV's laden in `t_stg_*` (zoals nu)
3. `sql/02_handinvoer_naar_staging.sql` uitvoeren (pas bovenaan de `USE` aan naar de juiste database). Het toont per tabel hoeveel regels zijn toegevoegd en hoeveel zijn overgeslagen omdat ze al via de CSV binnenkwamen; die laatste kunnen later uit `BDRC_Handinvoer` worden opgeruimd.
4. `EXEC p_process_staging_data @extractionDate = '<vandaag>', @dataTimestamp = '<nu>'`
5. `t_stg_Error_log` controleren
6. `EXEC p_load_query_data`
7. Kwaliteitsscript `bdrc_data-quality-SQL_Server.sql` draaien (bovenaan `USE` aanpassen)

## Testen
```bash
node testdata/test.js
```
Test validatieregels en SQL-uitvoer (alles verzonnen data) tegen `testdata/verwacht/`. Voor een proef in SQL Server: `testdata/00_testopzet.sql` maakt een lege `Test_BDRC` met de vier staging-tabellen; zie de opmerkingen bovenin dat bestand.

Echte CSV's met klantdata horen niet in deze repository.
