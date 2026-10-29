-- Handinvoer BDRC – GEUNL01900000003 – ingevoerd door Test Medewerker op 2026-10-29 13:05:11
-- Bestand: handinvoer_GEUNL01900000003_20261029-130511.sql
USE BDRC_Handinvoer;
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRANSACTION;

-- Controles (elke controle stopt het script met een melding en draait alles terug)
IF EXISTS (SELECT 1 FROM dbo.Customer WHERE Customer_number = N'GEUNL01900000003')
   OR EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Customer WHERE Customer_number = N'GEUNL01900000003')
    THROW 50001, N'Klantnummer GEUNL01900000003 bestaat al.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Product WHERE Product_number = N'NL42TEST0000000002' AND Product_type = N'Betaalrekening')
   AND NOT EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Product WHERE Product_number = N'NL42TEST0000000002' AND Product_type = N'Betaalrekening')
    THROW 50001, N'Bestaande rekening NL42TEST0000000002 (Betaalrekening) is niet gevonden.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE Product_number = N'NL42TEST0000000002' AND Product_type = N'Betaalrekening' AND Role_type = N'AccountHolder')
   AND NOT EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Customer WHERE Product_number = N'NL42TEST0000000002' AND Product_type = N'Betaalrekening' AND Role_type = N'AccountHolder')
    THROW 50001, N'Rekening NL42TEST0000000002 (Betaalrekening) heeft nog geen AccountHolder.', 1;

-- Klantregels
INSERT INTO dbo.Customer (Customer_number, Customer_type, Product_number, Product_type, Role_type, Relationship, Role_start_date, Role_end_date, Citizen_service_number, Date_of_birth, First_initial, Other_initials, First_name, Last_name, Last_name_prefix, Chamber_of_commerce_number, Organisation_name, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000003', N'NaturalPerson', N'NL42TEST0000000002', N'Betaalrekening', N'AuthorizedRepresentative', N'Guardian', CONVERT(date, '2025-02-01', 23), NULL, N'200000019', CONVERT(date, '1980-05-17', 23), N'J', N'P', N'Jan', N'Testman', N'van', NULL, NULL, N'Test Medewerker', N'handinvoer_GEUNL01900000003_20261029-130511.sql');

-- Adressen
INSERT INTO dbo.Address (Customer_number, Address_type, Start_date, End_date, Street, House_number, House_number_suffix, Postal_code, PO_box, City, Other_address_data, Country, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000003', N'Home', CONVERT(date, '2020-01-01', 23), NULL, N'Teststraat', N'12', N'B', N'1234AB', NULL, N'Testdorp', NULL, N'NL', N'Test Medewerker', N'handinvoer_GEUNL01900000003_20261029-130511.sql');

COMMIT TRANSACTION;
PRINT 'Klaar: 1 klantregels, 0 rekeningen, 1 adressen, 0 UBO-relaties toegevoegd.';
