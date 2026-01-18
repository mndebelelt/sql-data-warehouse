/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    Creates the DataWarehouse database if it does not exist.
    Creates schemas: bronze, silver, gold if they do not exist.
=============================================================
*/

USE master;
GO

-- Create database only if it does not exist
IF DB_ID('DataWarehouse') IS NULL
BEGIN
    CREATE DATABASE DataWarehouse;
    PRINT 'Database DataWarehouse created.';
END
ELSE
BEGIN
    PRINT 'Database DataWarehouse already exists.';
END
GO

USE DataWarehouse;
GO

-- Create schemas only if they do not exist
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO
