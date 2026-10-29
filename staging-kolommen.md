# Staging-kolommen Mylette BDRC v3.0

Bron: Mylette *Data Interface Specification v3.0*, hoofdstuk 2 (Data requirements). Dit zijn de kolommen van de staging-tabellen in de BDRC-database zelf, niet de BDRP-spec van Justitie.

`Is_valid` (int, default 0) staat in elke tabel, maar wordt door Mylette intern gebruikt: **niet vullen**.

## t_stg_Customer

| Kolom | Type | Null | Opmerking |
|---|---|---|---|
| Customer_number | nvarchar(50) | NOT NULL | Uniek per klant |
| Customer_type | varchar(16) | NOT NULL | `NaturalPerson`, `LegalEntity` |
| Product_number | nvarchar(34) | (NOT) NULL | Leeg alleen bij klant zonder product (bijv. UBO) |
| Product_type | varchar(30) | (NOT) NULL | Idem |
| Role_type | varchar(30) | (NOT) NULL | `AccountHolder`, `AuthorizedRepresentative`, of leeg (klant zonder product) |
| Relationship | nvarchar(200) | NULL | Alleen bij `AuthorizedRepresentative` |
| Role_start_date | date | NULL | Vóór Role_end_date |
| Role_end_date | date | NULL | Niet zonder Role_start_date |
| Citizen_service_number | nvarchar(9) | NULL | Natuurlijke personen |
| Date_of_birth | date | NULL | |
| First_initial | nchar(1) | NULL | Geen punten of spaties |
| Other_initials | nvarchar(50) | NULL | Geen punten of spaties |
| First_name | nvarchar(50) | NULL | |
| Last_name | nvarchar(200) | NULL | |
| Last_name_prefix | nvarchar(10) | NULL | |
| Chamber_of_commerce_number | nvarchar(200) | NULL | Rechtspersonen |
| Organisation_name | nvarchar(200) | NULL | |

Validaties: geen dubbele regels; Product_number + Product_type moeten bestaan in t_stg_Product. Elk product heeft minstens één AccountHolder (datakwaliteit).

## t_stg_Address

| Kolom | Type | Null | Opmerking |
|---|---|---|---|
| Customer_number | nvarchar(50) | NOT NULL | Moet bestaan in t_stg_Customer |
| Address_type | varchar(30) | NOT NULL | `Home`, `Postal`, `RegisteredOffice` (alleen rechtspersonen) |
| Start_date | date | NULL | Vóór End_date |
| End_date | date | NULL | Niet zonder Start_date |
| Street | nvarchar(100) | NULL | Straat óf PO_box |
| House_number | nvarchar(15) | NULL | |
| House_number_suffix | nvarchar(10) | NULL | |
| Postal_code | nvarchar(10) | NULL | NL: `1234AB`, zonder spatie |
| PO_box | nvarchar(20) | NULL | Meestal type `Postal` |
| City | nvarchar(100) | NULL | |
| Other_address_data | nvarchar(500) | NULL | Ongestructureerde (buitenlandse) adresdata |
| Country | char(2) | NULL | ISO 3166-1 alpha-2 |

## t_stg_Product

| Kolom | Type | Null | Opmerking |
|---|---|---|---|
| Product_number | nvarchar(34) | NOT NULL | Uniek in combinatie met Product_type |
| Product_type | varchar(30) | NOT NULL | Zie lijst hieronder |
| Status | varchar(20) | NOT NULL | `Active`, `Frozen`, `Discontinued` |
| Contract_party | nvarchar(200) | NULL | |
| Account_name | nvarchar(200) | NULL | |
| Opening_date | date | NULL | Verplicht volgens de omschrijving |
| Closing_Date | date | NULL | Verplicht bij `Discontinued`; na Opening_date |
| Account_currency | varchar(3) | NULL | ISO 4217. CSV-kolom heet `Currency` |
| Suspense_account | bit | NOT NULL, default 0 | Product van de bank zelf; niet in CSV, default laten |

Product_type, toegestane waarden: Betaalrekening, Spaarrekening, Effectenrekening, Levenslooprekening, Lijfrenterekening, Creditcard, Debitcard, Rekening-courant krediet, Hypothecair krediet, Consumptief krediet, Zakelijk krediet, Effectendepot, Digitale portemonnee, Kluis, Verzekering. Alleen `Betaalrekening` geeft `paymentAccount = true` in de OneBrn-service.

## t_stg_Relation

| Kolom | Type | Null | Opmerking |
|---|---|---|---|
| Customer_number | nvarchar(50) | NOT NULL | De UBO; moet een NaturalPerson in t_stg_Customer zijn |
| Relationship_type | varchar(30) | NOT NULL | Alleen `UBO` |
| Related_item_number | nvarchar(50) | NOT NULL | Klantnummer van de rechtspersoon; moet een AccountHolder in t_stg_Customer zijn |
| Related_item_type | varchar(30) | NULL | Alleen `LegalEntity` |
| Start_date | date | NULL | Optioneel, vóór End_date |
| End_date | date | NULL | Optioneel, niet zonder Start_date |

## Aanvullende regels uit de Mylette-kennisbank (FAQ)

- Bij meerdere loads op dezelfde Extraction_date blijft alleen de laatste bewaard. Staging moet dus altijd volledig zijn.
- Citizen_service_number: alleen Nederlandse BSN's worden gebruikt; buitenlandse ID's niet in dit veld zetten. Chamber_of_commerce_number mag ook een buitenlands registratienummer zijn.
- Opening_date en Closing_date niet gelijk (anders de fout `Violation of PRIMARY KEY constraint 'PK_Status'`).
- Rekening in meerdere valuta's: één productregel per valuta, verder identieke velden.
- Een Home-adres is vereist voor de rekeningcontrole (verifyaccount / 1BRN).
- Role_end_date en adres-End_date worden momenteel niet in de respons gebruikt; mogen leeg blijven.

## Exacte lengtes uit de database halen

Draai dit in SSMS op MyletteBDRC (of Test_BDRC) om de werkelijke definitie te controleren:

```sql
SELECT TABLE_NAME, COLUMN_NAME, DATA_TYPE, CHARACTER_MAXIMUM_LENGTH, IS_NULLABLE, COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME IN ('t_stg_Customer','t_stg_Address','t_stg_Product','t_stg_Relation')
ORDER BY TABLE_NAME, ORDINAL_POSITION;
```
