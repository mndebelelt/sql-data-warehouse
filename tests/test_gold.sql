/*
===============================================================================
Tests: GOLD layer checks (PASS/FAIL)
Run after: silver loaded (and gold created / loaded if tables)
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

-- Guard: objects exist
IF OBJECT_ID('gold.dim_customers') IS NULL
BEGIN
    THROW 51001, 'Missing object: gold.dim_customers', 1;
END;

IF OBJECT_ID('gold.dim_products') IS NULL
BEGIN
    THROW 51002, 'Missing object: gold.dim_products', 1;
END;

IF OBJECT_ID('gold.fact_sales') IS NULL
BEGIN
    THROW 51003, 'Missing object: gold.fact_sales', 1;
END;


----------------------------
-- Dim Customers
----------------------------
-- customer_key unique
SELECT @failures = COUNT(*)
FROM (
    SELECT customer_key
    FROM gold.dim_customers
    GROUP BY customer_key
    HAVING COUNT(*) > 1
) d;

INSERT INTO @results
SELECT
    'gold.dim_customers - customer_key UNIQUE',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Duplicate customer_key found';

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


----------------------------
-- Dim Products
----------------------------
-- product_key unique
SELECT @failures = COUNT(*)
FROM (
    SELECT product_key
    FROM gold.dim_products
    GROUP BY product_key
    HAVING COUNT(*) > 1
) d;

INSERT INTO @results
SELECT
    'gold.dim_products - product_key UNIQUE',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Duplicate product_key found';

-- prd_key should not be NULL
SELECT @failures = COUNT(*)
FROM gold.dim_products
WHERE prd_key IS NULL OR LTRIM(RTRIM(prd_key)) = '';

INSERT INTO @results
SELECT
    'gold.dim_products - prd_key populated',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'prd_key is NULL/blank';


----------------------------
-- Fact Sales
----------------------------
-- keys should not be NULL
SELECT @failures = COUNT(*)
FROM gold.fact_sales
WHERE customer_key IS NULL OR product_key IS NULL;

INSERT INTO @results
SELECT
    'gold.fact_sales - FK keys not NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'customer_key/product_key must not be NULL';

-- referential integrity: fact customer_key exists in dim_customers
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

-- referential integrity: fact product_key exists in dim_products
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

-- numeric sanity
SELECT @failures = COUNT(*)
FROM gold.fact_sales
WHERE sls_sales < 0 OR sls_quantity < 0 OR sls_price < 0;

INSERT INTO @results
SELECT
    'gold.fact_sales - measures non-negative',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Sales/quantity/price must be >= 0';


----------------------------
-- Summary output
----------------------------
SELECT *
FROM @results
ORDER BY Status, TestName;
