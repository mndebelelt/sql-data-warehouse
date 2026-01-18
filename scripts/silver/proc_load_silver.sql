/*
===============================================================================
Stored Procedure: silver.load_silver
Purpose:
  Loads data from bronze layer into silver layer with cleansing,
  standardization, deduplication, and type conversion.
  Includes per-table timing + row counts.
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2(7), @end_time DATETIME2(7);
    DECLARE @table SYSNAME;
    DECLARE @rows INT;

    BEGIN TRY
        PRINT '================================================';
        PRINT 'Loading SILVER Layer';
        PRINT '================================================';

        ---------------------------------------------------------------------
        -- 1) silver.crm_cust_info
        ---------------------------------------------------------------------
        SET @table = 'silver.crm_cust_info';
        SET @start_time = SYSUTCDATETIME();

        PRINT '>> Truncating Table: ' + @table;
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data Into: ' + @table;

        ;WITH ranked_customers AS (
            SELECT
                cst_id,
                cst_key,
                cst_firstname,
                cst_lastname,
                cst_marital_status,
                cst_gndr,
                cst_create_date,
                ROW_NUMBER() OVER (
                    PARTITION BY cst_id
                    ORDER BY cst_create_date DESC
                ) AS rn
            FROM bronze.crm_cust_info
            WHERE cst_id IS NOT NULL
        )
        INSERT INTO silver.crm_cust_info
        (
            cst_id,
            cst_key,
            cst_firstname,
            cst_lastname,
            cst_marital_status,
            cst_gndr,
            cst_create_date
        )
        SELECT
            cst_id,
            TRIM(cst_key) AS cst_key,
            TRIM(cst_firstname) AS cst_firstname,
            TRIM(cst_lastname) AS cst_lastname,
            CASE
                WHEN UPPER(TRIM(cst_marital_status)) IN ('S', 'SINGLE') THEN 'Single'
                WHEN UPPER(TRIM(cst_marital_status)) IN ('M', 'MARRIED') THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            CASE
                WHEN UPPER(TRIM(cst_gndr)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(cst_gndr)) IN ('M', 'MALE') THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM ranked_customers
        WHERE rn = 1;

        SET @rows = @@ROWCOUNT;

        SET @end_time = SYSUTCDATETIME();
        PRINT '>> Rows Loaded: ' + CAST(@rows AS NVARCHAR(20));
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';
        PRINT '>> -------------';


        ---------------------------------------------------------------------
        -- 2) silver.crm_prd_info
        ---------------------------------------------------------------------
        SET @table = 'silver.crm_prd_info';
        SET @start_time = SYSUTCDATETIME();

        PRINT '>> Truncating Table: ' + @table;
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: ' + @table;

        ;WITH base_products AS (
            SELECT
                prd_id,
                TRIM(prd_key) AS prd_key,
                TRIM(prd_nm)  AS prd_nm,
                prd_cost,
                TRIM(prd_line) AS prd_line,
                CAST(prd_start_dt AS DATE) AS prd_start_dt
            FROM bronze.crm_prd_info
            WHERE prd_id IS NOT NULL
              AND prd_key IS NOT NULL
        ),
        -- If source includes duplicate rows, dedupe on (prd_key, prd_start_dt)
        ranked_products AS (
            SELECT
                prd_id,
                prd_key,
                prd_nm,
                prd_cost,
                prd_line,
                prd_start_dt,
                ROW_NUMBER() OVER (
                    PARTITION BY prd_key, prd_start_dt
                    ORDER BY prd_id DESC
                ) AS rn
            FROM base_products
        ),
        cleaned_products AS (
            SELECT
                prd_id,
                -- derive category id from first 5 chars of prd_key: 'AC-HE' -> 'AC_HE'
                REPLACE(LEFT(prd_key, 5), '-', '_') AS cat_id,
                prd_key,
                prd_nm,
                TRY_CONVERT(DECIMAL(18,2), prd_cost) AS prd_cost,
                CASE
                    WHEN UPPER(prd_line) = 'M' THEN 'Mountain'
                    WHEN UPPER(prd_line) = 'R' THEN 'Road'
                    WHEN UPPER(prd_line) = 'S' THEN 'Other Sales'
                    WHEN UPPER(prd_line) = 'T' THEN 'Touring'
                    ELSE 'n/a'
                END AS prd_line,
                prd_start_dt
            FROM ranked_products
            WHERE rn = 1
        )
        INSERT INTO silver.crm_prd_info
        (
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            cat_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS prd_end_dt
        FROM cleaned_products;

        SET @rows = @@ROWCOUNT;

        SET @end_time = SYSUTCDATETIME();
        PRINT '>> Rows Loaded: ' + CAST(@rows AS NVARCHAR(20));
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';
        PRINT '>> -------------';


        ---------------------------------------------------------------------
        -- 3) silver.crm_sales_details
        ---------------------------------------------------------------------
        SET @table = 'silver.crm_sales_details';
        SET @start_time = SYSUTCDATETIME();

        PRINT '>> Truncating Table: ' + @table;
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: ' + @table;

        INSERT INTO silver.crm_sales_details
        (
            sls_ord_num,
            sls_prd_key,
            sls_cust_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            TRIM(sls_prd_key) AS sls_prd_key,
            sls_cust_id,

            CASE
                WHEN sls_order_dt IS NULL OR sls_order_dt = 0 OR LEN(CONVERT(VARCHAR(20), sls_order_dt)) <> 8 THEN NULL
                ELSE TRY_CONVERT(DATE, CONVERT(CHAR(8), sls_order_dt), 112)
            END AS sls_order_dt,

            CASE
                WHEN sls_ship_dt IS NULL OR sls_ship_dt = 0 OR LEN(CONVERT(VARCHAR(20), sls_ship_dt)) <> 8 THEN NULL
                ELSE TRY_CONVERT(DATE, CONVERT(CHAR(8), sls_ship_dt), 112)
            END AS sls_ship_dt,

            CASE
                WHEN sls_due_dt IS NULL OR sls_due_dt = 0 OR LEN(CONVERT(VARCHAR(20), sls_due_dt)) <> 8 THEN NULL
                ELSE TRY_CONVERT(DATE, CONVERT(CHAR(8), sls_due_dt), 112)
            END AS sls_due_dt,

            CASE WHEN sls_sales    IS NULL OR sls_sales    < 0 THEN 0 ELSE sls_sales END AS sls_sales,
            CASE WHEN sls_quantity IS NULL OR sls_quantity < 0 THEN 0 ELSE sls_quantity END AS sls_quantity,
            CASE WHEN sls_price    IS NULL OR sls_price    < 0 THEN 0 ELSE sls_price END AS sls_price
        FROM bronze.crm_sales_details;

        SET @rows = @@ROWCOUNT;

        SET @end_time = SYSUTCDATETIME();
        PRINT '>> Rows Loaded: ' + CAST(@rows AS NVARCHAR(20));
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';
        PRINT '>> -------------';


        ---------------------------------------------------------------------
        -- 4) silver.erp_cust_az12
        ---------------------------------------------------------------------
        SET @table = 'silver.erp_cust_az12';
        SET @start_time = SYSUTCDATETIME();

        PRINT '>> Truncating Table: ' + @table;
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: ' + @table;

        INSERT INTO silver.erp_cust_az12
        (
            cid,
            bdate,
            gen
        )
        SELECT
            TRIM(cid) AS cid,
            CASE
                WHEN bdate IS NOT NULL AND bdate > CAST(GETDATE() AS DATE) THEN NULL
                ELSE bdate
            END AS bdate,
            CASE
                WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;

        SET @rows = @@ROWCOUNT;

        SET @end_time = SYSUTCDATETIME();
        PRINT '>> Rows Loaded: ' + CAST(@rows AS NVARCHAR(20));
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';
        PRINT '>> -------------';


        ---------------------------------------------------------------------
        -- 5) silver.erp_loc_a101
        ---------------------------------------------------------------------
        SET @table = 'silver.erp_loc_a101';
        SET @start_time = SYSUTCDATETIME();

        PRINT '>> Truncating Table: ' + @table;
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: ' + @table;

        INSERT INTO silver.erp_loc_a101
        (
            cid,
            cntry
        )
        SELECT
            TRIM(cid) AS cid,
            CASE
                WHEN cntry IS NULL OR TRIM(cntry) = '' THEN 'n/a'
                WHEN UPPER(TRIM(cntry)) IN ('US', 'USA', 'UNITED STATES') THEN 'United States'
                WHEN UPPER(TRIM(cntry)) IN ('DE', 'GERMANY') THEN 'Germany'
                WHEN UPPER(TRIM(cntry)) IN ('FR', 'FRANCE') THEN 'France'
                ELSE TRIM(cntry)
            END AS cntry
        FROM bronze.erp_loc_a101;

        SET @rows = @@ROWCOUNT;

        SET @end_time = SYSUTCDATETIME();
        PRINT '>> Rows Loaded: ' + CAST(@rows AS NVARCHAR(20));
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';
        PRINT '>> -------------';


        ---------------------------------------------------------------------
        -- 6) silver.erp_px_cat_g1v2
        ---------------------------------------------------------------------
        SET @table = 'silver.erp_px_cat_g1v2';
        SET @start_time = SYSUTCDATETIME();

        PRINT '>> Truncating Table: ' + @table;
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: ' + @table;

        INSERT INTO silver.erp_px_cat_g1v2
        (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            TRIM(id) AS id,
            TRIM(cat) AS cat,
            TRIM(subcat) AS subcat,
            TRIM(maintenance) AS maintenance
        FROM bronze.erp_px_cat_g1v2;

        SET @rows = @@ROWCOUNT;

        SET @end_time = SYSUTCDATETIME();
        PRINT '>> Rows Loaded: ' + CAST(@rows AS NVARCHAR(20));
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR(20)) + ' seconds';
        PRINT '>> -------------';


        PRINT '================================================';
        PRINT 'SILVER Layer Load Completed Successfully';
        PRINT '================================================';
    END TRY
    BEGIN CATCH
        PRINT '================================================';
        PRINT 'ERROR OCCURED DURING LOADING SILVER LAYER';
        PRINT '================================================';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS NVARCHAR(20));
        PRINT 'Error State: ' + CAST(ERROR_STATE() AS NVARCHAR(20));
        PRINT 'Error Line: ' + CAST(ERROR_LINE() AS NVARCHAR(20));
        PRINT 'Last Table Attempted: ' + ISNULL(@table, 'n/a');
        THROW;
    END CATCH
END;
GO
