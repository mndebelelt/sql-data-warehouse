/*
===============================================================================
Stored Procedure: silver.load_silver
Purpose: Loads data from bronze layer into silver layer with cleansing,
         standardization, deduplication, and type conversion.
===============================================================================
*/

CREATE OR ALTER PROCEDURE silver.load_silver
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @start_time DATETIME2, @end_time DATETIME2;

    BEGIN TRY
        PRINT '================================================';
        PRINT 'Loading SILVER Layer';
        PRINT '================================================';

        ------------------------------------------------------------
        -- Load: silver.crm_cust_info
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_cust_info';
        TRUNCATE TABLE silver.crm_cust_info;

        PRINT '>> Inserting Data Into: silver.crm_cust_info';

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
            LTRIM(RTRIM(cst_key)) AS cst_key,
            LTRIM(RTRIM(cst_firstname)) AS cst_firstname,
            LTRIM(RTRIM(cst_lastname)) AS cst_lastname,
            CASE
                WHEN UPPER(LTRIM(RTRIM(cst_marital_status))) IN ('S', 'SINGLE') THEN 'Single'
                WHEN UPPER(LTRIM(RTRIM(cst_marital_status))) IN ('M', 'MARRIED') THEN 'Married'
                ELSE 'n/a'
            END AS cst_marital_status,
            CASE
                WHEN UPPER(LTRIM(RTRIM(cst_gndr))) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(LTRIM(RTRIM(cst_gndr))) IN ('M', 'MALE') THEN 'Male'
                ELSE 'n/a'
            END AS cst_gndr,
            cst_create_date
        FROM ranked_customers
        WHERE rn = 1;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: silver.crm_prd_info
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_prd_info';
        TRUNCATE TABLE silver.crm_prd_info;

        PRINT '>> Inserting Data Into: silver.crm_prd_info';

        ;WITH cleaned_products AS (
            SELECT
                prd_id,
                prd_key,
                prd_nm,
                prd_cost,
                prd_line,
                prd_start_dt,
                ROW_NUMBER() OVER (
                    PARTITION BY prd_id
                    ORDER BY prd_start_dt DESC
                ) AS rn
            FROM bronze.crm_prd_info
            WHERE prd_id IS NOT NULL
        ),
        final_products AS (
            SELECT
                prd_id,
                LTRIM(RTRIM(prd_key)) AS prd_key,
                LTRIM(RTRIM(prd_nm)) AS prd_nm,
                TRY_CONVERT(DECIMAL(18,2), prd_cost) AS prd_cost,
                CASE
                    WHEN UPPER(LTRIM(RTRIM(prd_line))) = 'M' THEN 'Mountain'
                    WHEN UPPER(LTRIM(RTRIM(prd_line))) = 'R' THEN 'Road'
                    WHEN UPPER(LTRIM(RTRIM(prd_line))) = 'S' THEN 'Other Sales'
                    WHEN UPPER(LTRIM(RTRIM(prd_line))) = 'T' THEN 'Touring'
                    ELSE 'n/a'
                END AS prd_line,
                CAST(prd_start_dt AS DATE) AS prd_start_dt
            FROM cleaned_products
            WHERE rn = 1
        )
        INSERT INTO silver.crm_prd_info
        (
            prd_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            prd_end_dt
        )
        SELECT
            prd_id,
            prd_key,
            prd_nm,
            prd_cost,
            prd_line,
            prd_start_dt,
            DATEADD(DAY, -1, LEAD(prd_start_dt) OVER (PARTITION BY prd_key ORDER BY prd_start_dt)) AS prd_end_dt
        FROM final_products;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: silver.crm_sales_details
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.crm_sales_details';
        TRUNCATE TABLE silver.crm_sales_details;

        PRINT '>> Inserting Data Into: silver.crm_sales_details';

        INSERT INTO silver.crm_sales_details
        (
            sls_ord_num,
            sls_prd_key,
            sls_cst_id,
            sls_order_dt,
            sls_ship_dt,
            sls_due_dt,
            sls_sales,
            sls_quantity,
            sls_price
        )
        SELECT
            sls_ord_num,
            LTRIM(RTRIM(sls_prd_key)) AS sls_prd_key,
            sls_cst_id,

            CASE
                WHEN sls_order_dt = 0 OR LEN(CONVERT(VARCHAR(20), sls_order_dt)) <> 8 THEN NULL
                ELSE TRY_CONVERT(DATE, CONVERT(CHAR(8), sls_order_dt), 112)
            END AS sls_order_dt,

            CASE
                WHEN sls_ship_dt = 0 OR LEN(CONVERT(VARCHAR(20), sls_ship_dt)) <> 8 THEN NULL
                ELSE TRY_CONVERT(DATE, CONVERT(CHAR(8), sls_ship_dt), 112)
            END AS sls_ship_dt,

            CASE
                WHEN sls_due_dt = 0 OR LEN(CONVERT(VARCHAR(20), sls_due_dt)) <> 8 THEN NULL
                ELSE TRY_CONVERT(DATE, CONVERT(CHAR(8), sls_due_dt), 112)
            END AS sls_due_dt,

            -- Sales / quantity / price cleanup
            CASE WHEN sls_sales IS NULL OR sls_sales < 0 THEN 0 ELSE sls_sales END AS sls_sales,
            CASE WHEN sls_quantity IS NULL OR sls_quantity < 0 THEN 0 ELSE sls_quantity END AS sls_quantity,
            CASE WHEN sls_price IS NULL OR sls_price < 0 THEN 0 ELSE sls_price END AS sls_price
        FROM bronze.crm_sales_details;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: silver.erp_cust_az12
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_cust_az12';
        TRUNCATE TABLE silver.erp_cust_az12;

        PRINT '>> Inserting Data Into: silver.erp_cust_az12';

        INSERT INTO silver.erp_cust_az12
        (
            cid,
            bdate,
            gen
        )
        SELECT
            cid,
            CASE
                WHEN bdate > GETDATE() THEN NULL
                ELSE bdate
            END AS bdate,
            CASE
                WHEN UPPER(LTRIM(RTRIM(gen))) IN ('F', 'FEMALE') THEN 'Female'
                WHEN UPPER(LTRIM(RTRIM(gen))) IN ('M', 'MALE') THEN 'Male'
                ELSE 'n/a'
            END AS gen
        FROM bronze.erp_cust_az12;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: silver.erp_loc_a101
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_loc_a101';
        TRUNCATE TABLE silver.erp_loc_a101;

        PRINT '>> Inserting Data Into: silver.erp_loc_a101';

        INSERT INTO silver.erp_loc_a101
        (
            cid,
            cntry
        )
        SELECT
            cid,
            CASE
                WHEN LTRIM(RTRIM(cntry)) = '' OR cntry IS NULL THEN 'n/a'
                WHEN UPPER(LTRIM(RTRIM(cntry))) IN ('US', 'USA', 'UNITED STATES') THEN 'United States'
                WHEN UPPER(LTRIM(RTRIM(cntry))) IN ('DE', 'GERMANY') THEN 'Germany'
                WHEN UPPER(LTRIM(RTRIM(cntry))) IN ('FR', 'FRANCE') THEN 'France'
                ELSE LTRIM(RTRIM(cntry))
            END AS cntry
        FROM bronze.erp_loc_a101;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
        PRINT '>> -------------';


        ------------------------------------------------------------
        -- Load: silver.erp_px_cat_g1v2
        ------------------------------------------------------------
        SET @start_time = GETDATE();
        PRINT '>> Truncating Table: silver.erp_px_cat_g1v2';
        TRUNCATE TABLE silver.erp_px_cat_g1v2;

        PRINT '>> Inserting Data Into: silver.erp_px_cat_g1v2';

        INSERT INTO silver.erp_px_cat_g1v2
        (
            id,
            cat,
            subcat,
            maintenance
        )
        SELECT
            id,
            LTRIM(RTRIM(cat)) AS cat,
            LTRIM(RTRIM(subcat)) AS subcat,
            LTRIM(RTRIM(maintenance)) AS maintenance
        FROM bronze.erp_px_cat_g1v2;

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(SECOND, @start_time, @end_time) AS NVARCHAR) + ' seconds';
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
        THROW;
    END CATCH
END;
GO
