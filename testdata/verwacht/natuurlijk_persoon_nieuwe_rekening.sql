-- Handinvoer BDRC – GEUNL01900000001 – ingevoerd door Test Medewerker op 2026-10-29 13:05:11
-- Bestand: handinvoer_GEUNL01900000001_20261029-130511.sql
USE BDRC_Handinvoer;
SET XACT_ABORT ON;
SET NOCOUNT ON;
BEGIN TRANSACTION;

-- Controles (elke controle stopt het script met een melding en draait alles terug)
IF EXISTS (SELECT 1 FROM dbo.Customer WHERE Customer_number = N'GEUNL01900000001')
   OR EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Customer WHERE Customer_number = N'GEUNL01900000001')
    THROW 50001, N'Klantnummer GEUNL01900000001 bestaat al.', 1;
IF EXISTS (SELECT 1 FROM dbo.Product WHERE Product_number = N'NL69TEST0000000001' AND Product_type = N'Betaalrekening')
   OR EXISTS (SELECT 1 FROM [Test_BDRC].dbo.t_stg_Product WHERE Product_number = N'NL69TEST0000000001' AND Product_type = N'Betaalrekening')
    THROW 50001, N'Rekening NL69TEST0000000001 (Betaalrekening) bestaat al.', 1;

-- Rekeningen
INSERT INTO dbo.Product (Product_number, Product_type, Status, Contract_party, Account_name, Opening_date, Closing_Date, Account_currency, Ingevoerd_door, Scriptbestand)
VALUES (N'NL69TEST0000000001', N'Betaalrekening', N'Active', N'KEB Hana Bank Amsterdam', N'J. Jansen', CONVERT(date, '2024-03-01', 23), NULL, N'EUR', N'Test Medewerker', N'handinvoer_GEUNL01900000001_20261029-130511.sql');

-- Klantregels
INSERT INTO dbo.Customer (Customer_number, Customer_type, Product_number, Product_type, Role_type, Relationship, Role_start_date, Role_end_date, Citizen_service_number, Date_of_birth, First_initial, Other_initials, First_name, Last_name, Last_name_prefix, Chamber_of_commerce_number, Organisation_name, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000001', N'NaturalPerson', N'NL69TEST0000000001', N'Betaalrekening', N'AccountHolder', NULL, CONVERT(date, '2024-03-01', 23), NULL, N'100000010', CONVERT(date, '1980-05-17', 23), N'J', N'P', N'Jan', N'D''Angelo', N'van', NULL, NULL, N'Test Medewerker', N'handinvoer_GEUNL01900000001_20261029-130511.sql');

-- Adressen
INSERT INTO dbo.Address (Customer_number, Address_type, Start_date, End_date, Street, House_number, House_number_suffix, Postal_code, PO_box, City, Other_address_data, Country, Ingevoerd_door, Scriptbestand)
VALUES (N'GEUNL01900000001', N'Home', CONVERT(date, '2020-01-01', 23), NULL, N'Teststraat', N'12', N'B', N'1234AB', NULL, N'Testdorp', NULL, N'NL', N'Test Medewerker', N'handinvoer_GEUNL01900000001_20261029-130511.sql');

COMMIT TRANSACTION;
PRINT 'Klaar: 1 klantregels, 1 rekeningen, 1 adressen, 0 UBO-relaties toegevoegd.';
