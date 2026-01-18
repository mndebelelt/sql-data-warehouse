/*
===============================================================================
Tests: SILVER layer data quality checks (PASS/FAIL)
Run after: EXEC bronze.load_bronze ...; EXEC silver.load_silver;
===============================================================================
*/

SET NOCOUNT ON;

DECLARE @fail_on_error BIT = 1;  -- set to 0 if you only want results (no THROW)

DECLARE @results TABLE (
    TestName NVARCHAR(200),
    Status   VARCHAR(4),
    Failures INT,
    Notes    NVARCHAR(4000)
);

DECLARE @failures INT;

---------------------------------------
-- 1) silver.crm_cust_info
---------------------------------------

-- cst_id should not be NULL
SELECT @failures = COUNT(*)
FROM silver.crm_cust_info
WHERE cst_id IS NULL;

INSERT INTO @results
SELECT
    'silver.crm_cust_info - cst_id NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'cst_id must never be NULL';

-- cst_id should be unique (one row per customer after dedupe)
SELECT @failures = COUNT(*)
FROM (
    SELECT cst_id
    FROM silver.crm_cust_info
    GROUP BY cst_id
    HAVING COUNT(*) > 1
) d;

INSERT INTO @results
SELECT
    'silver.crm_cust_info - cst_id UNIQUE',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Duplicate cst_id values found';

-- cst_key should be trimmed (no leading/trailing spaces)
SELECT @failures = COUNT(*)
FROM silver.crm_cust_info
WHERE cst_key IS NOT NULL
  AND cst_key <> TRIM(cst_key);

INSERT INTO @results
SELECT
    'silver.crm_cust_info - cst_key trimmed',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'cst_key contains leading/trailing spaces';

-- marital status should be standardized
SELECT @failures = COUNT(*)
FROM silver.crm_cust_info
WHERE cst_marital_status NOT IN ('Single', 'Married', 'n/a');

INSERT INTO @results
SELECT
    'silver.crm_cust_info - marital status domain',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Allowed: Single, Married, n/a';

-- gender should be standardized
SELECT @failures = COUNT(*)
FROM silver.crm_cust_info
WHERE cst_gndr NOT IN ('Male', 'Female', 'n/a');

INSERT INTO @results
SELECT
    'silver.crm_cust_info - gender domain',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Allowed: Male, Female, n/a';


---------------------------------------
-- 2) silver.crm_prd_info
---------------------------------------

-- prd_id should not be NULL
SELECT @failures = COUNT(*)
FROM silver.crm_prd_info
WHERE prd_id IS NULL;

INSERT INTO @results
SELECT
    'silver.crm_prd_info - prd_id NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'prd_id must never be NULL';

-- prd_key should be trimmed
SELECT @failures = COUNT(*)
FROM silver.crm_prd_info
WHERE prd_key IS NOT NULL
  AND prd_key <> TRIM(prd_key);

INSERT INTO @results
SELECT
    'silver.crm_prd_info - prd_key trimmed',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'prd_key contains leading/trailing spaces';

-- product start date should not be NULL
SELECT @failures = COUNT(*)
FROM silver.crm_prd_info
WHERE prd_start_dt IS NULL;

INSERT INTO @results
SELECT
    'silver.crm_prd_info - prd_start_dt NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'prd_start_dt should be populated';

-- end date (if present) must be >= start date
SELECT @failures = COUNT(*)
FROM silver.crm_prd_info
WHERE prd_end_dt IS NOT NULL
  AND prd_end_dt < prd_start_dt;

INSERT INTO @results
SELECT
    'silver.crm_prd_info - prd_end_dt >= prd_start_dt',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Found prd_end_dt earlier than prd_start_dt';

-- cost should not be negative (NULL allowed)
SELECT @failures = COUNT(*)
FROM silver.crm_prd_info
WHERE prd_cost IS NOT NULL
  AND prd_cost < 0;

INSERT INTO @results
SELECT
    'silver.crm_prd_info - prd_cost non-negative',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'prd_cost cannot be negative';


---------------------------------------
-- 3) silver.crm_sales_details
---------------------------------------

-- order number should not be NULL
SELECT @failures = COUNT(*)
FROM silver.crm_sales_details
WHERE sls_ord_num IS NULL;

INSERT INTO @results
SELECT
    'silver.crm_sales_details - sls_ord_num NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'sls_ord_num must never be NULL';

-- product key should be trimmed
SELECT @failures = COUNT(*)
FROM silver.crm_sales_details
WHERE sls_prd_key IS NOT NULL
  AND sls_prd_key <> TRIM(sls_prd_key);

INSERT INTO @results
SELECT
    'silver.crm_sales_details - sls_prd_key trimmed',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'sls_prd_key contains leading/trailing spaces';

-- dates logical ordering: ship >= order (when both exist)
SELECT @failures = COUNT(*)
FROM silver.crm_sales_details
WHERE sls_order_dt IS NOT NULL
  AND sls_ship_dt IS NOT NULL
  AND sls_ship_dt < sls_order_dt;

INSERT INTO @results
SELECT
    'silver.crm_sales_details - ship_dt >= order_dt',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Ship date earlier than order date';

-- due >= order (when both exist)
SELECT @failures = COUNT(*)
FROM silver.crm_sales_details
WHERE sls_order_dt IS NOT NULL
  AND sls_due_dt IS NOT NULL
  AND sls_due_dt < sls_order_dt;

INSERT INTO @results
SELECT
    'silver.crm_sales_details - due_dt >= order_dt',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Due date earlier than order date';

-- numeric sanity: quantity/price/sales non-negative
SELECT @failures = COUNT(*)
FROM silver.crm_sales_details
WHERE sls_quantity < 0 OR sls_price < 0 OR sls_sales < 0;

INSERT INTO @results
SELECT
    'silver.crm_sales_details - non-negative measures',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Sales/quantity/price must be >= 0';

-- sales rows must match a customer in silver (avoid orphan facts later)
SELECT @failures = COUNT(*)
FROM silver.crm_sales_details s
LEFT JOIN silver.crm_cust_info c ON c.cst_id = s.sls_cust_id
WHERE s.sls_cust_id IS NOT NULL
  AND c.cst_id IS NULL;

INSERT INTO @results
SELECT
    'silver.crm_sales_details - sls_cust_id exists in silver.crm_cust_info',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Sales contains customer IDs missing from silver customer table';

---------------------------------------
-- 4) ERP silver tables
---------------------------------------

-- bdate should not be in the future
SELECT @failures = COUNT(*)
FROM silver.erp_cust_az12
WHERE bdate IS NOT NULL
  AND bdate > CAST(GETDATE() AS DATE);

INSERT INTO @results
SELECT
    'silver.erp_cust_az12 - bdate not in future',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Birthdate cannot be in the future';

-- country should not be NULL/blank
SELECT @failures = COUNT(*)
FROM silver.erp_loc_a101
WHERE cntry IS NULL OR TRIM(cntry) = '';

INSERT INTO @results
SELECT
    'silver.erp_loc_a101 - cntry populated',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'cntry must be populated (or n/a)';

-- px_cat columns trimmed
SELECT @failures = COUNT(*)
FROM silver.erp_px_cat_g1v2
WHERE (cat IS NOT NULL AND cat <> TRIM(cat))
   OR (subcat IS NOT NULL AND subcat <> TRIM(subcat))
   OR (maintenance IS NOT NULL AND maintenance <> TRIM(maintenance));

INSERT INTO @results
SELECT
    'silver.erp_px_cat_g1v2 - trimmed columns',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'cat/subcat/maintenance contains leading/trailing spaces';


---------------------------------------
-- Summary output + optional fail
---------------------------------------
SELECT *
FROM @results
ORDER BY Status, TestName;

IF @fail_on_error = 1 AND EXISTS (SELECT 1 FROM @results WHERE Status = 'FAIL')
    THROW 51000, 'SILVER tests failed. Review the results above.', 1;
