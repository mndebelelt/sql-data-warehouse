
/*
=============================================================
Create Database and Schemas
=============================================================
Script Purpose:
    This script creates a new database named 'DataWarehouse'. 
    Additionally, the script sets up three schemas 
    within the database: 'bronze', 'silver', and 'gold'.
	
*/


use master;
Go

-- Create the 'DataWarehouse' database
CREATE DATABASE DataWarehouse;
GO

use DataWarehouse;

-- Group database into Schemas 

CREATE SCHEMA bronze;
GO

CREATE SCHEMA silver;
GO

CREATE SCHEMA gold;
GO
