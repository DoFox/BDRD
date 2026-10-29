-- 02_handinvoer_naar_staging.sql
-- Draait bij elke import: NA het laden van de CSV's in t_stg_* en VOOR p_process_staging_data.
-- Kopieert de handmatig ingevoerde klanten uit BDRC_Handinvoer naar staging.
-- Regels die al via de CSV in staging staan worden overgeslagen (de CSV wint).
--
-- Databasenaam: pas de USE hieronder aan (MyletteBDRC, of Test_BDRC om te testen).
-- BDRC_Handinvoer moet op dezelfde instance staan.

USE MyletteBDRC;
GO

SET XACT_ABORT ON;
SET NOCOUNT ON;

IF DB_ID(N'BDRC_Handinvoer') IS NULL
    THROW 50001, N'Database BDRC_Handinvoer bestaat niet. Draai eerst 01_create_handinvoer.sql.', 1;

BEGIN TRANSACTION;

-- 1. Bepaal eerst wat overgeslagen wordt (vóór de inserts, anders staat alles er daarna al in).
SELECT h.*
INTO #skip_Product
FROM BDRC_Handinvoer.dbo.Product AS h
WHERE EXISTS (SELECT 1 FROM dbo.t_stg_Product AS s
              WHERE s.Product_number = h.Product_number
                AND s.Product_type = h.Product_type
                AND ISNULL(s.Account_currency, '') = ISNULL(h.Account_currency, ''));

SELECT h.*
INTO #skip_Customer
FROM BDRC_Handinvoer.dbo.Customer AS h
WHERE EXISTS (SELECT 1 FROM dbo.t_stg_Customer AS s
              WHERE s.Customer_number = h.Customer_number
                AND ISNULL(s.Product_number, N'') = ISNULL(h.Product_number, N'')
                AND ISNULL(s.Product_type, '') = ISNULL(h.Product_type, '')
                AND ISNULL(s.Role_type, '') = ISNULL(h.Role_type, ''));

SELECT h.*
INTO #skip_Address
FROM BDRC_Handinvoer.dbo.Address AS h
WHERE EXISTS (SELECT 1 FROM dbo.t_stg_Address AS s
              WHERE s.Customer_number = h.Customer_number
                AND s.Address_type = h.Address_type);

SELECT h.*
INTO #skip_Relation
FROM BDRC_Handinvoer.dbo.Relation AS h
WHERE EXISTS (SELECT 1 FROM dbo.t_stg_Relation AS s
              WHERE s.Customer_number = h.Customer_number
                AND s.Related_item_number = h.Related_item_number);

-- 2. Kopieer wat nog niet in staging staat. Is_valid blijft leeg (default); dat is van Mylette.
DECLARE @added_Product  int, @added_Customer int, @added_Address int, @added_Relation int;

INSERT INTO dbo.t_stg_Product
    (Product_number, Product_type, Status, Contract_party, Account_name, Opening_date, Closing_Date, Account_currency, Suspense_account)
SELECT h.Product_number, h.Product_type, h.Status, h.Contract_party, h.Account_name, h.Opening_date, h.Closing_Date, h.Account_currency, h.Suspense_account
FROM BDRC_Handinvoer.dbo.Product AS h
WHERE NOT EXISTS (SELECT 1 FROM #skip_Product AS k WHERE k.Id = h.Id)
ORDER BY h.Id;
SET @added_Product = @@ROWCOUNT;

INSERT INTO dbo.t_stg_Customer
    (Customer_number, Customer_type, Product_number, Product_type, Role_type, Relationship, Role_start_date, Role_end_date,
     Citizen_service_number, Date_of_birth, First_initial, Other_initials, First_name, Last_name, Last_name_prefix,
     Chamber_of_commerce_number, Organisation_name)
SELECT h.Customer_number, h.Customer_type, h.Product_number, h.Product_type, h.Role_type, h.Relationship, h.Role_start_date, h.Role_end_date,
       h.Citizen_service_number, h.Date_of_birth, h.First_initial, h.Other_initials, h.First_name, h.Last_name, h.Last_name_prefix,
       h.Chamber_of_commerce_number, h.Organisation_name
FROM BDRC_Handinvoer.dbo.Customer AS h
WHERE NOT EXISTS (SELECT 1 FROM #skip_Customer AS k WHERE k.Id = h.Id)
ORDER BY h.Id;
SET @added_Customer = @@ROWCOUNT;

INSERT INTO dbo.t_stg_Address
    (Customer_number, Address_type, Start_date, End_date, Street, House_number, House_number_suffix, Postal_code, PO_box, City, Other_address_data, Country)
SELECT h.Customer_number, h.Address_type, h.Start_date, h.End_date, h.Street, h.House_number, h.House_number_suffix, h.Postal_code, h.PO_box, h.City, h.Other_address_data, h.Country
FROM BDRC_Handinvoer.dbo.Address AS h
WHERE NOT EXISTS (SELECT 1 FROM #skip_Address AS k WHERE k.Id = h.Id)
ORDER BY h.Id;
SET @added_Address = @@ROWCOUNT;

INSERT INTO dbo.t_stg_Relation
    (Customer_number, Relationship_type, Related_item_number, Related_item_type, Start_date, End_date)
SELECT h.Customer_number, h.Relationship_type, h.Related_item_number, h.Related_item_type, h.Start_date, h.End_date
FROM BDRC_Handinvoer.dbo.Relation AS h
WHERE NOT EXISTS (SELECT 1 FROM #skip_Relation AS k WHERE k.Id = h.Id)
ORDER BY h.Id;
SET @added_Relation = @@ROWCOUNT;

COMMIT TRANSACTION;

-- 3. Samenvatting per tabel.
SELECT N'Product'  AS Tabel, @added_Product  AS Toegevoegd, (SELECT COUNT(*) FROM #skip_Product)  AS Overgeslagen_al_in_CSV
UNION ALL
SELECT N'Customer', @added_Customer, (SELECT COUNT(*) FROM #skip_Customer)
UNION ALL
SELECT N'Address',  @added_Address,  (SELECT COUNT(*) FROM #skip_Address)
UNION ALL
SELECT N'Relation', @added_Relation, (SELECT COUNT(*) FROM #skip_Relation);

-- 4. Overgeslagen regels: kunnen later uit BDRC_Handinvoer worden opgeruimd.
IF EXISTS (SELECT 1 FROM #skip_Product)  SELECT N'Product overgeslagen'  AS Overgeslagen, * FROM #skip_Product  ORDER BY Id;
IF EXISTS (SELECT 1 FROM #skip_Customer) SELECT N'Customer overgeslagen' AS Overgeslagen, * FROM #skip_Customer ORDER BY Id;
IF EXISTS (SELECT 1 FROM #skip_Address)  SELECT N'Address overgeslagen'  AS Overgeslagen, * FROM #skip_Address  ORDER BY Id;
IF EXISTS (SELECT 1 FROM #skip_Relation) SELECT N'Relation overgeslagen' AS Overgeslagen, * FROM #skip_Relation ORDER BY Id;

DROP TABLE #skip_Product, #skip_Customer, #skip_Address, #skip_Relation;
GO
