-- 01_create_handinvoer.sql
-- Eenmalig uitvoeren in SSMS (rechten: CREATE DATABASE). Veilig om opnieuw te draaien.
-- Maakt database BDRC_Handinvoer en de vier tabellen voor handmatig ingevoerde klanten.
-- Kolommen, types en lengtes zijn gelijk aan t_stg_* (zie staging-kolommen.md), zonder Is_valid.
-- In MyletteBDRC wordt niets aangemaakt of gewijzigd.

SET NOCOUNT ON;

-- Database waarvan de collation wordt overgenomen (voor testen: Test_BDRC).
DECLARE @BdrcDatabase sysname = N'MyletteBDRC';

IF DB_ID(N'BDRC_Handinvoer') IS NULL
BEGIN
    -- CREATE DATABASE accepteert geen variabele voor de collation, vandaar dit ene stukje dynamische SQL.
    DECLARE @collation sysname = CONVERT(sysname, DATABASEPROPERTYEX(@BdrcDatabase, 'Collation'));
    IF @collation IS NULL
        THROW 50001, N'Database om de collation van over te nemen bestaat niet. Pas @BdrcDatabase bovenaan aan.', 1;

    DECLARE @sql nvarchar(max) = N'CREATE DATABASE BDRC_Handinvoer COLLATE ' + QUOTENAME(@collation) + N';';
    EXEC (@sql);
    PRINT N'Database BDRC_Handinvoer aangemaakt (collation ' + @collation + N').';
END
GO

USE BDRC_Handinvoer;
GO

IF OBJECT_ID(N'dbo.Customer', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Customer
    (
        Id                          int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Customer PRIMARY KEY,
        Customer_number             nvarchar(50)  NOT NULL,
        Customer_type               varchar(16)   NOT NULL,
        Product_number              nvarchar(34)  NULL,
        Product_type                varchar(30)   NULL,
        Role_type                   varchar(30)   NULL,
        Relationship                nvarchar(200) NULL,
        Role_start_date             date          NULL,
        Role_end_date               date          NULL,
        Citizen_service_number      nvarchar(9)   NULL,
        Date_of_birth               date          NULL,
        First_initial               nchar(1)      NULL,
        Other_initials              nvarchar(50)  NULL,
        First_name                  nvarchar(50)  NULL,
        Last_name                   nvarchar(200) NULL,
        Last_name_prefix            nvarchar(10)  NULL,
        Chamber_of_commerce_number  nvarchar(200) NULL,
        Organisation_name           nvarchar(200) NULL,
        Ingevoerd_door              nvarchar(100) NOT NULL,
        Ingevoerd_op                datetime2     NOT NULL CONSTRAINT DF_Customer_Ingevoerd_op DEFAULT SYSDATETIME(),
        Scriptbestand               nvarchar(200) NULL
    );
    -- Geen unieke index: een klant heeft meerdere regels. Dubbelingen controleert het gegenereerde script.
    CREATE INDEX IX_Customer_Customer_number ON dbo.Customer (Customer_number);
    CREATE INDEX IX_Customer_Product ON dbo.Customer (Product_number, Product_type);
END
GO

IF OBJECT_ID(N'dbo.Product', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Product
    (
        Id                  int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Product PRIMARY KEY,
        Product_number      nvarchar(34)  NOT NULL,
        Product_type        varchar(30)   NOT NULL,
        Status              varchar(20)   NOT NULL,
        Contract_party      nvarchar(200) NULL,
        Account_name        nvarchar(200) NULL,
        Opening_date        date          NULL,
        Closing_Date        date          NULL,
        Account_currency    varchar(3)    NULL,
        Suspense_account    bit           NOT NULL CONSTRAINT DF_Product_Suspense_account DEFAULT 0,
        Ingevoerd_door      nvarchar(100) NOT NULL,
        Ingevoerd_op        datetime2     NOT NULL CONSTRAINT DF_Product_Ingevoerd_op DEFAULT SYSDATETIME(),
        Scriptbestand       nvarchar(200) NULL
    );
    CREATE UNIQUE INDEX UX_Product ON dbo.Product (Product_number, Product_type, Account_currency);
END
GO

IF OBJECT_ID(N'dbo.Address', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Address
    (
        Id                   int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Address PRIMARY KEY,
        Customer_number      nvarchar(50)  NOT NULL,
        Address_type         varchar(30)   NOT NULL,
        Start_date           date          NULL,
        End_date             date          NULL,
        Street               nvarchar(100) NULL,
        House_number         nvarchar(15)  NULL,
        House_number_suffix  nvarchar(10)  NULL,
        Postal_code          nvarchar(10)  NULL,
        PO_box               nvarchar(20)  NULL,
        City                 nvarchar(100) NULL,
        Other_address_data   nvarchar(500) NULL,
        Country              char(2)       NULL,
        Ingevoerd_door       nvarchar(100) NOT NULL,
        Ingevoerd_op         datetime2     NOT NULL CONSTRAINT DF_Address_Ingevoerd_op DEFAULT SYSDATETIME(),
        Scriptbestand        nvarchar(200) NULL
    );
    CREATE UNIQUE INDEX UX_Address ON dbo.Address (Customer_number, Address_type);
END
GO

IF OBJECT_ID(N'dbo.Relation', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Relation
    (
        Id                    int IDENTITY(1,1) NOT NULL CONSTRAINT PK_Relation PRIMARY KEY,
        Customer_number       nvarchar(50) NOT NULL,
        Relationship_type     varchar(30)  NOT NULL,
        Related_item_number   nvarchar(50) NOT NULL,
        Related_item_type     varchar(30)  NULL,
        Start_date            date         NULL,
        End_date              date         NULL,
        Ingevoerd_door        nvarchar(100) NOT NULL,
        Ingevoerd_op          datetime2    NOT NULL CONSTRAINT DF_Relation_Ingevoerd_op DEFAULT SYSDATETIME(),
        Scriptbestand         nvarchar(200) NULL
    );
    CREATE UNIQUE INDEX UX_Relation ON dbo.Relation (Customer_number, Related_item_number);
END
GO

PRINT N'Klaar: BDRC_Handinvoer en de tabellen Customer, Product, Address en Relation zijn aanwezig.';
GO
