/*
===============================================================================
Tests: GOLD layer checks (PASS/FAIL)
Run after: silver loaded and gold objects created
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

-- Guard: objects exist
IF OBJECT_ID('gold.dim_customers') IS NULL THROW 51001, 'Missing object: gold.dim_customers', 1;
IF OBJECT_ID('gold.dim_products')  IS NULL THROW 51002, 'Missing object: gold.dim_products', 1;
IF OBJECT_ID('gold.fact_sales')    IS NULL THROW 51003, 'Missing object: gold.fact_sales', 1;

---------------------------------------
-- Dim Customers
---------------------------------------

-- customer_key not null + unique
SELECT @failures = COUNT(*)
FROM (
    SELECT customer_key
    FROM gold.dim_customers
    GROUP BY customer_key
    HAVING customer_key IS NULL OR COUNT(*) > 1
) d;

INSERT INTO @results
SELECT
    'gold.dim_customers - customer_key NOT NULL + UNIQUE',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'customer_key must be present and unique';

-- cst_id should not be NULL
SELECT @failures = COUNT(*)
FROM gold.dim_customers
WHERE cst_id IS NULL;

INSERT INTO @results
SELECT
    'gold.dim_customers - cst_id NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'cst_id must not be NULL';


---------------------------------------
-- Dim Products
---------------------------------------

-- product_key not null + unique
SELECT @failures = COUNT(*)
FROM (
    SELECT product_key
    FROM gold.dim_products
    GROUP BY product_key
    HAVING product_key IS NULL OR COUNT(*) > 1
) d;

INSERT INTO @results
SELECT
    'gold.dim_products - product_key NOT NULL + UNIQUE',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'product_key must be present and unique';

-- prd_key should not be NULL/blank
SELECT @failures = COUNT(*)
FROM gold.dim_products
WHERE prd_key IS NULL OR TRIM(prd_key) = '';

INSERT INTO @results
SELECT
    'gold.dim_products - prd_key populated',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'prd_key is NULL/blank';


---------------------------------------
-- Fact Sales
---------------------------------------

-- keys should not be NULL
SELECT @failures = COUNT(*)
FROM gold.fact_sales
WHERE customer_key IS NULL OR product_key IS NULL;

INSERT INTO @results
SELECT
    'gold.fact_sales - FK keys NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'customer_key/product_key must not be NULL';

-- referential integrity: customer_key exists in dim_customers
SELECT @failures = COUNT(*)
FROM gold.fact_sales f
LEFT JOIN gold.dim_customers c ON c.customer_key = f.customer_key
WHERE c.customer_key IS NULL;

INSERT INTO @results
SELECT
    'gold.fact_sales - customer_key exists in dim_customers',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Fact contains customer_key not found in dim_customers';

-- referential integrity: product_key exists in dim_products
SELECT @failures = COUNT(*)
FROM gold.fact_sales f
LEFT JOIN gold.dim_products p ON p.product_key = f.product_key
WHERE p.product_key IS NULL;

INSERT INTO @results
SELECT
    'gold.fact_sales - product_key exists in dim_products',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Fact contains product_key not found in dim_products';

-- numeric sanity (adjust if you later model returns as negatives)
SELECT @failures = COUNT(*)
FROM gold.fact_sales
WHERE sls_sales < 0 OR sls_quantity < 0 OR sls_price < 0;

INSERT INTO @results
SELECT
    'gold.fact_sales - measures non-negative',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Sales/quantity/price must be >= 0';

-- ✅ NEW: order date should not be in the future (if column exists)
IF COL_LENGTH('gold.fact_sales', 'sls_order_dt') IS NOT NULL
BEGIN
    SELECT @failures = COUNT(*)
    FROM gold.fact_sales
    WHERE sls_order_dt IS NOT NULL
      AND sls_order_dt > CAST(GETDATE() AS DATE);

    INSERT INTO @results
    SELECT
        'gold.fact_sales - sls_order_dt not in future',
        IIF(@failures = 0, 'PASS', 'FAIL'),
        @failures,
        'Order date cannot be in the future';
END

---------------------------------------
-- Summary output + optional fail
---------------------------------------
SELECT *
FROM @results
ORDER BY Status, TestName;

IF @fail_on_error = 1 AND EXISTS (SELECT 1 FROM @results WHERE Status = 'FAIL')
    THROW 51010, 'GOLD tests failed. Review the results above.', 1;
