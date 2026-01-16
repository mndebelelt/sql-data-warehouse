/*
===============================================================================
Tests: SILVER layer data quality checks (PASS/FAIL)
Run after: EXEC bronze.load_bronze ...; EXEC silver.load_silver;
===============================================================================
*/

SET NOCOUNT ON;

DECLARE @results TABLE (
    TestName NVARCHAR(200),
    Status   VARCHAR(4),
    Failures INT,
    Notes    NVARCHAR(4000)
);

DECLARE @failures INT;

----------------------------
-- 1) silver.crm_cust_info
----------------------------

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


----------------------------
-- 2) silver.crm_prd_info
----------------------------

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

-- cost should not be negative (NULL allowed if source bad)
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


----------------------------
-- 3) silver.crm_sales_details
----------------------------

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

-- dates: if present, must be valid (already converted to DATE)
-- here we check for logical ordering: order <= ship <= due (when all exist)
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

-- numeric sanity: quantity and price non-negative
SELECT @failures = COUNT(*)
FROM silver.crm_sales_details
WHERE sls_quantity < 0 OR sls_price < 0 OR sls_sales < 0;

INSERT INTO @results
SELECT
    'silver.crm_sales_details - non-negative measures',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Sales/quantity/price must be >= 0';


----------------------------
-- 4) ERP silver tables
----------------------------

-- bdate should not be in the future
SELECT @failures = COUNT(*)
FROM silver.erp_cust_az12
WHERE bdate IS NOT NULL
  AND bdate > GETDATE();

INSERT INTO @results
SELECT
    'silver.erp_cust_az12 - bdate not in future',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Birthdate cannot be in the future';

-- country should not be NULL/blank after cleanup
SELECT @failures = COUNT(*)
FROM silver.erp_loc_a101
WHERE cntry IS NULL OR LTRIM(RTRIM(cntry)) = '';

INSERT INTO @results
SELECT
    'silver.erp_loc_a101 - cntry populated',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'cntry must be populated (or n/a)';


----------------------------
-- Summary output
----------------------------
SELECT *
FROM @results
ORDER BY Status, TestName;
