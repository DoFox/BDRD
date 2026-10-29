# BDRC Handinvoer – Hana Bank

## Doel
Eén losse HTML-pagina waarmee een medewerker van Hana Bank een **nieuwe klant** invoert. De pagina controleert de invoer en maakt een **.sql-bestand** dat in SQL Server Management Studio (SSMS) wordt uitgevoerd. Dat script schrijft de klant in een eigen tabelset. Bij elke BDRC-import worden die tabellen samen met de CSV's in staging geladen.

Houd het klein. Geen server, geen backend, geen framework, geen login.

## Achtergrond (waarom zo)
- Hana levert data aan Mylette BDRC via vier CSV's die in de staging-tabellen `t_stg_Customer`, `t_stg_Product`, `t_stg_Address` en `t_stg_Relation` worden geladen. Daarna draaien `p_process_staging_data` en `p_load_query_data`.
- Staging wordt bij elke run leeggemaakt (`p_clear_staging`) en moet **volledig** zijn. Bij meerdere loads op dezelfde datum bewaart BDRC alleen de laatste. Een nieuwe klant mag dus **nooit los** worden geladen, en mag niet rechtstreeks in `t_stg_*` worden geschreven: dan is hij bij de volgende import weer weg.
- Daarom: nieuwe klanten gaan in een eigen permanente tabelset in een aparte database. Een vast importscript kopieert die bij elke import naar staging, na het laden van de CSV's.
- De database **MyletteBDRC** wordt beheerd door Mylette (schema via Flyway). Daar komen geen eigen tabellen, functies of andere objecten in.

## Omgeving
- SQL Server 2025 op de backoffice-server 192.168.1.31 (Windows Server 2025).
- BDRC-database: `MyletteBDRC`. Testdatabase: `Test_BDRC`.
- Eigen database voor de handinvoer: `BDRC_Handinvoer` (zelfde instance, zelfde collation als MyletteBDRC, die eindigt op `_CI_AS`).
- De pagina draait offline in de browser op een werkplek of de server. Er gaat geen data over het netwerk.

## Op te leveren bestanden
1. `invoer.html` – de pagina (één bestand, alle HTML, CSS en JavaScript inline).
2. `sql/01_create_handinvoer.sql` – maakt eenmalig database `BDRC_Handinvoer` en de vier tabellen aan.
3. `sql/02_handinvoer_naar_staging.sql` – draait bij elke import, ná het laden van de CSV's in staging en vóór `p_process_staging_data`.
4. `README.md` – korte Nederlandse uitleg voor de gebruiker: eenmalige installatie, een klant invoeren, de importvolgorde.
5. `testdata/` – verzonnen voorbeeldinvoer en verwachte .sql-uitvoer.

## 1. Tabellen in BDRC_Handinvoer (`01_create_handinvoer.sql`)
Vier tabellen met **exact dezelfde kolommen, types en lengtes als de staging-tabellen** (zie `staging-kolommen.md`), zonder `Is_valid`:
`dbo.Customer`, `dbo.Product`, `dbo.Address`, `dbo.Relation`.
- `dbo.Product` heeft ook `Suspense_account bit NOT NULL DEFAULT 0`.
- Elke tabel krijgt extra: `Id int IDENTITY PRIMARY KEY`, `Ingevoerd_door nvarchar(100) NOT NULL`, `Ingevoerd_op datetime2 NOT NULL DEFAULT SYSDATETIME()`, `Scriptbestand nvarchar(200) NULL`.
- Unieke indexen om dubbelingen in de eigen tabellen te voorkomen:
  - Product: `Product_number, Product_type, Account_currency`
  - Address: `Customer_number, Address_type`
  - Relation: `Customer_number, Related_item_number`
  - Customer: geen unieke index (een klant heeft meerdere regels), dubbelingen controleert het gegenereerde script.
- Idempotent schrijven (`IF DB_ID(...) IS NULL`, `IF OBJECT_ID(...) IS NULL`), zodat het script veilig opnieuw kan draaien.

## 2. De pagina (`invoer.html`)

### Techniek
- Eén zelfstandig bestand, vanilla JavaScript, geen externe bibliotheken, CDN's of lettertypes. Moet werken zonder internet.
- Werkt in Edge en Chrome door het bestand te openen (`file://`).
- Nederlandse teksten. Eenvoudige, rustige opmaak; formulier in duidelijke secties.
- Niets opslaan in localStorage of cookies (het gaat om persoonsgegevens).

### Formulier
1. **Ingevoerd door**: naam van de medewerker (verplicht). Komt in `Ingevoerd_door`.
2. **Klant**: type `NaturalPerson` of `LegalEntity`; klantnummer (uit het kernbankensysteem, formaat `GEUNL01` + 9 cijfers).
   - Natuurlijk persoon: BSN, geboortedatum, eerste voorletter (1 teken), overige voorletters, voornaam, tussenvoegsel, achternaam.
   - Rechtspersoon: KvK-nummer, organisatienaam.
3. **Adres(sen)**, één of meer: type `Home`, `Postal` of `RegisteredOffice`; straat, huisnummer, toevoeging, postcode, plaats, land, óf postbus in plaats van straat; overige adresgegevens (buitenland); startdatum.
4. **Rekening(en)**, één of meer:
   - Keuze **nieuwe rekening** of **bestaande rekening** (bijv. de klant wordt gemachtigde op een rekening die al bestaat).
   - Nieuwe rekening: rekeningnummer, type (`Betaalrekening` of `Spaarrekening`), status (standaard `Active`), contractpartij (standaard `KEB Hana Bank Amsterdam`), tenaamstelling, openingsdatum, valuta (standaard `EUR`, keuzelijst ISO 4217 met EUR, USD, GBP bovenaan).
   - Bestaande rekening: alleen rekeningnummer en type; er wordt dan geen productregel aangemaakt.
   - Per rekening de **rol**: `AccountHolder` of `AuthorizedRepresentative`; bij gemachtigde de relatie `Authorized NP`, `Administrator` of `Guardian`; rol-startdatum (standaard de openingsdatum).
   - Een klant zonder rekening is alleen toegestaan als UBO (zie 5).
5. **UBO's** (alleen bij een rechtspersoon die rekeninghouder is), één of meer:
   - Bestaande klant: alleen klantnummer.
   - Nieuwe persoon: dezelfde persoonsvelden als bij een natuurlijk persoon, plus adres. Wordt een Customer-regel met lege `Product_number`, `Product_type` en `Role_type`.
   - Per UBO een Relation-regel: `Relationship_type = UBO`, `Related_item_type = LegalEntity`, `Related_item_number` = klantnummer van de rechtspersoon, startdatum.

### Validatie (in de pagina, vóór het maken van het .sql-bestand)
Toon alle fouten tegelijk, bij het betreffende veld, in het Nederlands. De knop "SQL maken" werkt pas als er geen fouten zijn.
- Lengtes en verplichte velden volgens `staging-kolommen.md`.
- Klantnummer: `GEUNL01` + 9 cijfers.
- BSN: 8 of 9 cijfers en geldige elfproef (9·A + 8·B + … + 2·H − 1·I deelbaar door 11; zelfde als `dbo.isValidBSN` in `bdrc_data-quality-SQL_Server.sql`). Alleen Nederlandse BSN's; verplicht voor een natuurlijk persoon met een Nederlands woonadres die rekeninghouder is.
- Geboortedatum niet in de toekomst. Eerste voorletter precies 1 letter, voorletters zonder punten of spaties. Achternaam verplicht voor natuurlijke personen.
- Rechtspersoon: KvK-nummer en organisatienaam verplicht.
- Rekeningnummer: geldige IBAN (mod-97). Nederlandse IBAN: 18 tekens, patroon `NL99XXXX9999999999`.
- Postcode NL: automatisch hoofdletters en spaties verwijderen, daarna `1234AB`. Straat óf postbus, niet allebei; postbus zonder het woord "Postbus". Bij een Nederlands adres met straat zijn huisnummer, postcode en plaats verplicht.
- Land: geldige ISO 3166-1 alpha-2-code (keuzelijst, NL bovenaan).
- `RegisteredOffice` alleen voor rechtspersonen, `Home` niet voor rechtspersonen.
- Natuurlijk persoon die rekeninghouder is: een `Home`-adres is verplicht (nodig voor verifyaccount).
- Rechtspersoon die rekeninghouder is: minimaal één UBO.
- Relatie alleen bij `AuthorizedRepresentative`.
- Een nieuwe rekening heeft minimaal één `AccountHolder` in dit formulier. (Bij een bestaande rekening controleert het SQL-script of die er al is.)
- Status `Discontinued` vereist een sluitingsdatum; `Active` en `Frozen` hebben geen sluitingsdatum. Openings- en sluitingsdatum nooit gelijk.
- Einddatum nooit vóór startdatum, en nooit een einddatum zonder startdatum.
- Geen veld mag de tekst `NULL` bevatten; begin- en eindspaties weghalen.
- Geen dubbele invoer binnen het formulier (zelfde rekening of zelfde adrestype twee keer).

### Uitvoer
- Toon een **overzicht** van de regels die worden toegevoegd, per tabel.
- Knop **"SQL-bestand downloaden"**: bestandsnaam `handinvoer_<klantnummer>_<JJJJMMDD-HHMMSS>.sql`, UTF-8 **met BOM** (zodat SSMS tekens als é en ü goed leest), regeleinde CRLF.
- Ook een tekstvak met de SQL en een kopieerknop.
- Knop **"Nieuw formulier"** die alles leegmaakt.

## 3. Het gegenereerde .sql-bestand
Opbouw:
```sql
-- Handinvoer BDRC – <klantnummer> – ingevoerd door <naam> op <datum tijd>
USE BDRC_Handinvoer;
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRANSACTION;

-- Controles: elke controle breekt af met THROW en een Nederlandse melding
-- INSERTs in dbo.Product, dbo.Customer, dbo.Address, dbo.Relation

COMMIT TRANSACTION;
PRINT 'Klaar: <n> klantregels, <n> rekeningen, <n> adressen, <n> UBO-relaties toegevoegd.';
```

Controles in het script (vóór de inserts):
- Klantnummer bestaat nog niet in `BDRC_Handinvoer.dbo.Customer` en niet in `MyletteBDRC.dbo.t_stg_Customer` (de laatste levering).
- Nieuwe rekening (nummer + type) bestaat nog niet in `dbo.Product` en niet in `MyletteBDRC.dbo.t_stg_Product`.
- Bestaande rekening bestaat wél, in `dbo.Product` of in `MyletteBDRC.dbo.t_stg_Product`. Als de klant geen rekeninghouder op die rekening is: er bestaat er al een in `dbo.Customer` of `MyletteBDRC.dbo.t_stg_Customer`.
- Bestaande UBO-klant bestaat in `dbo.Customer` of `MyletteBDRC.dbo.t_stg_Customer`.
- Melding bij THROW noemt wat er mis is, bijv. `Klantnummer GEUNL01900028821 bestaat al.`

Regels voor de SQL:
- Teksten altijd als `N'...'` met enkele aanhalingstekens verdubbeld. Lege velden als `NULL`. Datums als `CONVERT(date, 'JJJJ-MM-DD', 23)`.
- Geen dynamische SQL, geen `EXEC` van strings.
- Elke insert vult `Ingevoerd_door` en `Scriptbestand` (de bestandsnaam).
- De databasenaam van MyletteBDRC moet makkelijk aan te passen zijn (één veld bovenin de pagina, standaard `MyletteBDRC`, voor testen `Test_BDRC`).

## 4. Importstap (`02_handinvoer_naar_staging.sql`)
Wordt uitgevoerd ná het laden van de CSV's in staging en vóór `p_process_staging_data`. Ook hier de databasenaam bovenin als variabele of duidelijk aan te passen.
- Kopieert de vier tabellen naar `t_stg_*` (alleen de stagingkolommen, `Is_valid` niet vullen; `Account_currency` en `Suspense_account` meenemen).
- **Geen dubbelingen**: een regel wordt alleen toegevoegd als die nog niet in staging staat (komt een handmatig ingevoerde klant later ook in de CSV-export, dan wint de CSV):
  - Product: zelfde `Product_number`, `Product_type`, `Account_currency`
  - Customer: zelfde `Customer_number`, `Product_number`, `Product_type`, `Role_type` (NULL-veilig vergelijken)
  - Address: zelfde `Customer_number`, `Address_type`
  - Relation: zelfde `Customer_number`, `Related_item_number`
- Toon daarna per tabel: aantal toegevoegd en aantal overgeslagen omdat het al via de CSV binnenkwam. Toon de overgeslagen regels apart, zodat die later uit `BDRC_Handinvoer` kunnen worden opgeruimd.
- In één transactie met `SET XACT_ABORT ON`.

De volledige importvolgorde voor de README:
1. `EXEC p_clear_staging`
2. CSV's laden in `t_stg_*` (zoals nu)
3. `02_handinvoer_naar_staging.sql` uitvoeren
4. `EXEC p_process_staging_data @extractionDate = '<vandaag>', @dataTimestamp = '<nu>'`
5. `t_stg_Error_log` controleren
6. `EXEC p_load_query_data`
7. Kwaliteitsscript `bdrc_data-quality-SQL_Server.sql` draaien (bovenaan `USE` aanpassen naar de juiste database)

## Testen
- De echte CSV's bevatten echte klantdata. Alleen gebruiken om het formaat te bekijken; niet in git, niet in testdata.
- Maak verzonnen testdata: geldige elfproef-BSN's en IBAN's genereren, verzonnen namen en adressen. Test zowel goede invoer als elke validatieregel.
- Test de gegenereerde SQL in een eigen testopzet: een lege `Test_BDRC` met alleen de vier `t_stg_*`-tabellen volgens `staging-kolommen.md`, plus `BDRC_Handinvoer`. Controleer: script draait foutloos, controles slaan aan bij dubbele nummers, importstap voegt toe en slaat dubbelingen over.
- Test een naam met een apostrof (bijv. `D'Angelo`) en een buitenlands adres met speciale tekens.

## Bronnen in deze map
- `staging-kolommen.md` – kolommen, lengtes en regels van de staging-tabellen (uit de Mylette Data Interface Specification v3.0 en de kennisbank).
- `Data Interface Specification v3.0.pdf` – de volledige Mylette-spec.
- `bdrc_data-quality-SQL_Server.sql` – kwaliteitscontroles van Mylette (testcases 1.0 t/m 38.0).
- De vier CSV's – alleen als voorbeeld van formaat en waarden.
