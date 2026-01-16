/*
===============================================================================
Stored Procedure: bronze.load_bronze
Purpose: Loads raw CSV data into bronze layer tables using BULK INSERT.
         Uses a base folder parameter to avoid hardcoded local paths.
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
    @base_path NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2, @end_time DATETIME2;
    DECLARE @sql NVARCHAR(MAX);

    -- Build file paths
    DECLARE @crm_cust  NVARCHAR(4000) = CONCAT(@base_path, '\datasets\source_crm\cust_info.csv');
    DECLARE @crm_prd   NVARCHAR(4000) = CONCAT(@base_path, '\datasets\source_crm\prd_info.csv');
    DECLARE @crm_sales NVARCHAR(4000) = CONCAT(@base_path, '\datasets\source_crm\sales_details.csv');

    DECLARE @erp_cust  NVARCHAR(4000) = CONCAT(@base_path, '\datasets\source_erp\CUST_AZ12.csv');
    DECLARE @erp_loc   NVARCHAR(4000) = CONCAT(@base_path, '\datasets\source_erp\LOC_A101.csv');
    DECLARE @erp_cat   NVARCHAR(4000) = CONCAT(@base_path, '\datasets\source_erp\PX_CAT_G1V2.csv');

    BEGIN TRY
        PRINT '================================================';
        PRINT 'Loading BRONZE Layer';
        PRINT 'Base path: ' + @base_path;
        PRINT '================================================';

        ------------------------------------------------------------
        -- Load: bronze.crm_cust_info
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_cust_info';
        TRUNCATE TABLE bronze.crm_cust_info;

        PRINT '>> Bulk Insert: ' + @crm_cust;

        SET @sql = N'
			BULK INSERT bronze.crm_cust_info
			FROM ''' + REPLACE(@crm_cust, '''', '''''') + N'''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0a'',
				TABLOCK
			);';

        EXEC sys.sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: bronze.crm_prd_info
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_prd_info';
        TRUNCATE TABLE bronze.crm_prd_info;

        PRINT '>> Bulk Insert: ' + @crm_prd;

        SET @sql = N'
			BULK INSERT bronze.crm_prd_info
			FROM ''' + REPLACE(@crm_prd, '''', '''''') + N'''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0a'',
				TABLOCK
			);';

        EXEC sys.sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: bronze.crm_sales_details
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.crm_sales_details';
        TRUNCATE TABLE bronze.crm_sales_details;

        PRINT '>> Bulk Insert: ' + @crm_sales;

        SET @sql = N'
			BULK INSERT bronze.crm_sales_details
			FROM ''' + REPLACE(@crm_sales, '''', '''''') + N'''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0a'',
				TABLOCK
			);';

        EXEC sys.sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: bronze.erp_cust_az12
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_cust_az12';
        TRUNCATE TABLE bronze.erp_cust_az12;

        PRINT '>> Bulk Insert: ' + @erp_cust;

        SET @sql = N'
			BULK INSERT bronze.erp_cust_az12
			FROM ''' + REPLACE(@erp_cust, '''', '''''') + N'''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0a'',
				TABLOCK
			);';

        EXEC sys.sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: bronze.erp_loc_a101
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_loc_a101';
        TRUNCATE TABLE bronze.erp_loc_a101;

        PRINT '>> Bulk Insert: ' + @erp_loc;

        SET @sql = N'
			BULK INSERT bronze.erp_loc_a101
			FROM ''' + REPLACE(@erp_loc, '''', '''''') + N'''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0a'',
				TABLOCK
			);';

        EXEC sys.sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: bronze.erp_px_cat_g1v2
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: bronze.erp_px_cat_g1v2';
        TRUNCATE TABLE bronze.erp_px_cat_g1v2;

        PRINT '>> Bulk Insert: ' + @erp_cat;

        SET @sql = N'
			BULK INSERT bronze.erp_px_cat_g1v2
			FROM ''' + REPLACE(@erp_cat, '''', '''''') + N'''
			WITH (
				FIRSTROW = 2,
				FIELDTERMINATOR = '','',
				ROWTERMINATOR = ''0x0a'',
				TABLOCK
			);';

        EXEC sys.sp_executesql @sql;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        PRINT '================================================';
        PRINT 'BRONZE Layer Load Completed Successfully';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR OCCURED DURING LOADING BRONZE LAYER';
        PRINT '================================================';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR(20));
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR(20));
        THROW;
    END CATCH
END;
GO
