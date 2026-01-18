/*
===============================================================================
Stored Procedure: bronze.load_bronze
Purpose:
  Loads raw CSV data into bronze layer tables using BULK INSERT.
  Uses a base folder parameter to avoid hardcoded local paths.
  Includes per-table timing + row counts, and reduces repetition.
===============================================================================
*/

CREATE OR ALTER PROCEDURE bronze.load_bronze
    @base_path NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;

    -- Basic validation
    IF @base_path IS NULL OR LTRIM(RTRIM(@base_path)) = ''
        THROW 50001, '@base_path cannot be NULL or empty.', 1;

    -- Normalize base path (remove trailing slash/backslash)
    WHILE RIGHT(@base_path, 1) IN ('\', '/')
        SET @base_path = LEFT(@base_path, LEN(@base_path) - 1);

    DECLARE @start_time DATETIME2(7), @end_time DATETIME2(7);
    DECLARE @sql NVARCHAR(MAX);

    DECLARE @table SYSNAME;
    DECLARE @file  NVARCHAR(4000);

    DECLARE @loads TABLE
    (
        load_order INT IDENTITY(1,1) PRIMARY KEY,
        table_name SYSNAME NOT NULL,
        file_path  NVARCHAR(4000) NOT NULL
    );

    INSERT INTO @loads (table_name, file_path)
    VALUES
        ('bronze.crm_cust_info',     CONCAT(@base_path, '\datasets\source_crm\cust_info.csv')),
        ('bronze.crm_prd_info',      CONCAT(@base_path, '\datasets\source_crm\prd_info.csv')),
        ('bronze.crm_sales_details', CONCAT(@base_path, '\datasets\source_crm\sales_details.csv')),
        ('bronze.erp_cust_az12',     CONCAT(@base_path, '\datasets\source_erp\CUST_AZ12.csv')),
        ('bronze.erp_loc_a101',      CONCAT(@base_path, '\datasets\source_erp\LOC_A101.csv')),
        ('bronze.erp_px_cat_g1v2',   CONCAT(@base_path, '\datasets\source_erp\PX_CAT_G1V2.csv'));

    BEGIN TRY
        PRINT '================================================';
        PRINT 'Loading BRONZE Layer';
        PRINT 'Base path: ' + @base_path;
        PRINT '================================================';

        DECLARE load_cursor CURSOR FAST_FORWARD FOR
            SELECT table_name, file_path
            FROM @loads
            ORDER BY load_order;

        OPEN load_cursor;
        FETCH NEXT FROM load_cursor INTO @table, @file;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @start_time = SYSUTCDATETIME();

            PRINT '>> Truncating Table: ' + @table;
            SET @sql = N'TRUNCATE TABLE ' + QUOTENAME(PARSENAME(@table, 2)) + N'.' + QUOTENAME(PARSENAME(@table, 1)) + N';';
            EXEC sys.sp_executesql @sql;


            SET @sql = N'
BULK INSERT ' + QUOTENAME(PARSENAME(@table, 2)) + N'.' + QUOTENAME(PARSENAME(@table, 1)) + N'
FROM ''' + REPLACE(@file, '''', '''''') + N'''
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0d0a'',
    TABLOCK
);';

            EXEC sys.sp_executesql @sql;

            PRINT '>> Rows Loaded: ' + CAST(@@ROWCOUNT AS NVARCHAR(20));

            SET @end_time = SYSUTCDATETIME();
            PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';
            PRINT '>> -------------';

            FETCH NEXT FROM load_cursor INTO @table, @file;
        END

        CLOSE load_cursor;
        DEALLOCATE load_cursor;

        PRINT '================================================';
        PRINT 'BRONZE Layer Load Completed Successfully';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        -- Clean up cursor if an error happens mid-loop
        IF CURSOR_STATUS('local', 'load_cursor') >= -1
        BEGIN
            CLOSE load_cursor;
            DEALLOCATE load_cursor;
        END

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
