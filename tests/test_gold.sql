/*
===============================================================================
Tests: GOLD layer checks (PASS/FAIL)
Run after: silver loaded and gold objects created
===============================================================================
*/

SET NOCOUNT ON;

DECLARE @fail_on_error BIT = 1;  -- set to 0 if we only want results (no THROW)

DECLARE @results TABLE (
    TestName NVARCHAR(200),
    Status   VARCHAR(4),
    Failures INT,
    Notes    NVARCHAR(4000)
);

DECLARE @failures INT;

-- Guard: objects exist
IF OBJECT_ID('gold.dim_customers', 'V') IS NULL THROW 51001, 'Missing object: gold.dim_customers', 1;
IF OBJECT_ID('gold.dim_products',  'V') IS NULL THROW 51002, 'Missing object: gold.dim_products', 1;
IF OBJECT_ID('gold.fact_sales',    'V') IS NULL THROW 51003, 'Missing object: gold.fact_sales', 1;

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

-- customer_id should not be NULL
SELECT @failures = COUNT(*)
FROM gold.dim_customers
WHERE customer_id IS NULL;

INSERT INTO @results
SELECT
    'gold.dim_customers - customer_id NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'customer_id must not be NULL';

-- customer_number should be populated
SELECT @failures = COUNT(*)
FROM gold.dim_customers
WHERE customer_number IS NULL OR LTRIM(RTRIM(customer_number)) = '';

INSERT INTO @results
SELECT
    'gold.dim_customers - customer_number populated',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'customer_number is NULL/blank';

-- gender domain (optional, but useful)
SELECT @failures = COUNT(*)
FROM gold.dim_customers
WHERE gender NOT IN ('Male', 'Female', 'n/a');

INSERT INTO @results
SELECT
    'gold.dim_customers - gender domain',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Allowed: Male, Female, n/a';

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

-- product_id should not be NULL
SELECT @failures = COUNT(*)
FROM gold.dim_products
WHERE product_id IS NULL;

INSERT INTO @results
SELECT
    'gold.dim_products - product_id NOT NULL',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'product_id must not be NULL';

-- product_number should be populated (this is prd_key in source)
SELECT @failures = COUNT(*)
FROM gold.dim_products
WHERE product_number IS NULL OR LTRIM(RTRIM(product_number)) = '';

INSERT INTO @results
SELECT
    'gold.dim_products - product_number populated',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'product_number is NULL/blank';

-- cost non-negative (NULL allowed)
SELECT @failures = COUNT(*)
FROM gold.dim_products
WHERE cost IS NOT NULL AND cost < 0;

INSERT INTO @results
SELECT
    'gold.dim_products - cost non-negative',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'cost cannot be negative';

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
WHERE sales_amount < 0 OR quantity < 0 OR price < 0;

INSERT INTO @results
SELECT
    'gold.fact_sales - measures non-negative',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'sales_amount/quantity/price must be >= 0';

-- order date should not be in the future
SELECT @failures = COUNT(*)
FROM gold.fact_sales
WHERE order_date IS NOT NULL
  AND order_date > CAST(GETDATE() AS DATE);

INSERT INTO @results
SELECT
    'gold.fact_sales - order_date not in future',
    IIF(@failures = 0, 'PASS', 'FAIL'),
    @failures,
    'Order date cannot be in the future';

---------------------------------------
-- Summary output + optional fail
---------------------------------------
SELECT *
FROM @results
ORDER BY Status, TestName;

IF @fail_on_error = 1 AND EXISTS (SELECT 1 FROM @results WHERE Status = 'FAIL')
    THROW 51010, 'GOLD tests failed. Review the results above.', 1;
