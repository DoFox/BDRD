-- Handinvoer BDRC – GEUNL01900000002 – ingevoerd door Test Medewerker op 2026-10-29 13:05:11
-- Bestand: handinvoer_GEUNL01900000002_20261029-130511.sql
USE BDRC_Handinvoer;
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRANSACTION;

-- Controles (elke controle stopt het script met een melding en draait alles terug)
IF EXISTS (SELECT 1 FROM dbo.Customer WHERE Customer_number = N'GEUNL01900000002')
   OR EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Customer WHERE Customer_number = N'GEUNL01900000002')
    THROW 50001, N'Klantnummer GEUNL01900000002 bestaat al.', 1;
IF EXISTS (SELECT 1 FROM dbo.Product WHERE Product_number = N'NL15TEST0000000003' AND Product_type = N'Spaarrekening')
   OR EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Product WHERE Product_number = N'NL15TEST0000000003' AND Product_type = N'Spaarrekening')
    THROW 50001, N'Rekening NL15TEST0000000003 (Spaarrekening) bestaat al.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.Customer WHERE Customer_number = N'GEUNL01900000010')
   AND NOT EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Customer WHERE Customer_number = N'GEUNL01900000010')
    THROW 50001, N'UBO-klant GEUNL01900000010 is niet gevonden.', 1;
IF EXISTS (SELECT 1 FROM dbo.Customer WHERE Customer_number = N'GEUNL01900000011')
   OR EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Customer WHERE Customer_number = N'GEUNL01900000011')
    THROW 50001, N'Klantnummer GEUNL01900000011 bestaat al.', 1;

-- Rekeningen
INSERT INTO dbo.Product (Product_number, Product_type, Status, Contract_party, Account_name, Opening_date, Closing_Date, Account_currency, Ingevoerd_door, Scriptbestand)
VALUES (N'NL15TEST0000000003', N'Spaarrekening', N'Active', N'KEB Hana Bank Amsterdam', N'Testbedrijf B.V.', CONVERT(date, '2024-03-01', 23), NULL, N'USD', N'Test Medewerker', N'handinvoer_GEUNL01900000002_20261029-130511.sql');

-- Klantregels
INSERT INTO dbo.Customer (Customer_number, Customer_type, Product_number, Product_type, Role_type, Relationship, Role_start_date, Role_end_date, Citizen_service_number, Date_of_birth, First_initial, Other_initials, First_name, Last_name, Last_name_prefix, Chamber_of_commerce_number, Organisation_name, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000002', N'LegalEntity', N'NL15TEST0000000003', N'Spaarrekening', N'AccountHolder', NULL, CONVERT(date, '2024-03-01', 23), NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'12345678', N'Testbedrijf B.V.', N'Test Medewerker', N'handinvoer_GEUNL01900000002_20261029-130511.sql');
INSERT INTO dbo.Customer (Customer_number, Customer_type, Product_number, Product_type, Role_type, Relationship, Role_start_date, Role_end_date, Citizen_service_number, Date_of_birth, First_initial, Other_initials, First_name, Last_name, Last_name_prefix, Chamber_of_commerce_number, Organisation_name, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000011', N'NaturalPerson', NULL, NULL, NULL, NULL, NULL, NULL, N'300000017', CONVERT(date, '1975-12-01', 23), N'M', NULL, N'Marie', N'Müller-Ñoño', NULL, NULL, NULL, N'Test Medewerker', N'handinvoer_GEUNL01900000002_20261029-130511.sql');

-- Adressen
INSERT INTO dbo.Address (Customer_number, Address_type, Start_date, End_date, Street, House_number, House_number_suffix, Postal_code, PO_box, City, Other_address_data, Country, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000002', N'RegisteredOffice', CONVERT(date, '2020-01-01', 23), NULL, N'Teststraat', N'12', N'B', N'1234AB', NULL, N'Testdorp', NULL, N'NL', N'Test Medewerker', N'handinvoer_GEUNL01900000002_20261029-130511.sql');
INSERT INTO dbo.Address (Customer_number, Address_type, Start_date, End_date, Street, House_number, House_number_suffix, Postal_code, PO_box, City, Other_address_data, Country, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000011', N'Home', NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'München', N'Hauptstraße 5, 80331 München', N'DE', N'Test Medewerker', N'handinvoer_GEUNL01900000002_20261029-130511.sql');

-- UBO-relaties
INSERT INTO dbo.Relation (Customer_number, Relationship_type, Related_item_number, Related_item_type, Start_date, End_date, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000010', N'UBO', N'GEUNL01900000002', N'LegalEntity', CONVERT(date, '2024-03-01', 23), NULL, N'Test Medewerker', N'handinvoer_GEUNL01900000002_20261029-130511.sql');
INSERT INTO dbo.Relation (Customer_number, Relationship_type, Related_item_number, Related_item_type, Start_date, End_date, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000011', N'UBO', N'GEUNL01900000002', N'LegalEntity', NULL, NULL, N'Test Medewerker', N'handinvoer_GEUNL01900000002_20261029-130511.sql');

COMMIT TRANSACTION;
PRINT 'Klaar: 2 klantregels, 1 rekeningen, 2 adressen, 2 UBO-relaties toegevoegd.';
