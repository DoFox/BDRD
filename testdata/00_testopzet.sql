-- 00_testopzet.sql: lege testdatabase Test_BDRC met alleen de vier t_stg_*-tabellen (volgens staging-kolommen.md).
-- Daarna: 01_create_handinvoer.sql (zet @BdrcDatabase bovenaan op Test_BDRC), dan de verwachte scripts uit testdata/verwacht/
-- (zij gebruiken Test_BDRC) en 02_handinvoer_naar_staging.sql (USE Test_BDRC).
-- Verwacht: scripts draaien foutloos; een tweede keer draaien stopt met "bestaat al"; 02 voegt toe en slaat bij herhaling alles over.
IF DB_ID(N'Test_BDRC') IS NULL CREATE DATABASE Test_BDRC;
GO
USE Test_BDRC;
GO
IF OBJECT_ID(N'dbo.t_stg_Product') IS NULL
CREATE TABLE dbo.t_stg_Product (Product_number nvarchar(34) NOT NULL, Product_type varchar(30) NOT NULL, Status varchar(20) NOT NULL,
  Contract_party nvarchar(200) NULL, Account_name nvarchar(200) NULL, Opening_date date NULL, Closing_Date date NULL,
  Account_currency varchar(3) NULL, Suspense_account bit NOT NULL DEFAULT 0, Is_valid int NOT NULL DEFAULT 0);
IF OBJECT_ID(N'dbo.t_stg_Customer') IS NULL
CREATE TABLE dbo.t_stg_Customer (Customer_number nvarchar(50) NOT NULL, Customer_type varchar(16) NOT NULL, Product_number nvarchar(34) NULL,
  Product_type varchar(30) NULL, Role_type varchar(30) NULL, Relationship nvarchar(200) NULL, Role_start_date date NULL, Role_end_date date NULL,
  Citizen_service_number nvarchar(9) NULL, Date_of_birth date NULL, First_initial nchar(1) NULL, Other_initials nvarchar(50) NULL,
  First_name nvarchar(50) NULL, Last_name nvarchar(200) NULL, Last_name_prefix nvarchar(10) NULL,
  Chamber_of_commerce_number nvarchar(200) NULL, Organisation_name nvarchar(200) NULL, Is_valid int NOT NULL DEFAULT 0);
IF OBJECT_ID(N'dbo.t_stg_Address') IS NULL
CREATE TABLE dbo.t_stg_Address (Customer_number nvarchar(50) NOT NULL, Address_type varchar(30) NOT NULL, Start_date date NULL, End_date date NULL,
  Street nvarchar(100) NULL, House_number nvarchar(15) NULL, House_number_suffix nvarchar(10) NULL, Postal_code nvarchar(10) NULL,
  PO_box nvarchar(20) NULL, City nvarchar(100) NULL, Other_address_data nvarchar(500) NULL, Country char(2) NULL, Is_valid int NOT NULL DEFAULT 0);
IF OBJECT_ID(N'dbo.t_stg_Relation') IS NULL
CREATE TABLE dbo.t_stg_Relation (Customer_number nvarchar(50) NOT NULL, Relationship_type varchar(30) NOT NULL, Related_item_number nvarchar(50) NOT NULL,
  Related_item_type varchar(30) NULL, Start_date date NULL, End_date date NULL, Is_valid int NOT NULL DEFAULT 0);
GO
