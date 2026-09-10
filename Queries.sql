-- ============================================================
-- LinkGuard-style project note: this is the Retail Sales SQL layer
-- Schema: fact_sales (Item_Identifier, Outlet_Identifier, Item_Outlet_Sales)
--         dim_item   (Item_Identifier, Item_Weight, Item_Fat_Content, Item_Visibility, Item_Type, Item_MRP)
--         dim_outlet (Outlet_Identifier, Outlet_Establishment_Year, Outlet_Size, Outlet_Location_Type, Outlet_Type)
-- ============================================================

-- Q1: Total and average sales by outlet type (JOIN + GROUP BY)
SELECT
    o.Outlet_Type,
    COUNT(f.sale_id)                AS num_transactions,
    ROUND(SUM(f.Item_Outlet_Sales),2)  AS total_sales,
    ROUND(AVG(f.Item_Outlet_Sales),2)  AS avg_sales_per_item
FROM fact_sales f
JOIN dim_outlet o ON f.Outlet_Identifier = o.Outlet_Identifier
GROUP BY o.Outlet_Type
ORDER BY total_sales DESC;

-- Q2: Top 3 best-selling item types within EACH outlet type (WINDOW FUNCTION)
WITH item_type_sales AS (
    SELECT
        o.Outlet_Type,
        i.Item_Type,
        SUM(f.Item_Outlet_Sales) AS total_sales
    FROM fact_sales f
    JOIN dim_item i   ON f.Item_Identifier = i.Item_Identifier
    JOIN dim_outlet o ON f.Outlet_Identifier = o.Outlet_Identifier
    GROUP BY o.Outlet_Type, i.Item_Type
),
ranked AS (
    SELECT *,
        RANK() OVER (PARTITION BY Outlet_Type ORDER BY total_sales DESC) AS sales_rank
    FROM item_type_sales
)
SELECT Outlet_Type, Item_Type, total_sales, sales_rank
FROM ranked
WHERE sales_rank <= 3
ORDER BY Outlet_Type, sales_rank;

-- Q3: Outlets performing ABOVE the overall average outlet sales (SUBQUERY)
SELECT
    o.Outlet_Identifier,
    o.Outlet_Type,
    o.Outlet_Location_Type,
    ROUND(SUM(f.Item_Outlet_Sales),2) AS outlet_total_sales
FROM fact_sales f
JOIN dim_outlet o ON f.Outlet_Identifier = o.Outlet_Identifier
GROUP BY o.Outlet_Identifier
HAVING SUM(f.Item_Outlet_Sales) > (
    SELECT AVG(outlet_total) FROM (
        SELECT SUM(Item_Outlet_Sales) AS outlet_total
        FROM fact_sales
        GROUP BY Outlet_Identifier
    )
)
ORDER BY outlet_total_sales DESC;

-- Q4: Sales trend by outlet establishment year (CTE + aggregation)
WITH yearly_sales AS (
    SELECT
        o.Outlet_Establishment_Year,
        SUM(f.Item_Outlet_Sales) AS total_sales,
        COUNT(DISTINCT o.Outlet_Identifier) AS num_outlets
    FROM fact_sales f
    JOIN dim_outlet o ON f.Outlet_Identifier = o.Outlet_Identifier
    GROUP BY o.Outlet_Establishment_Year
)
SELECT
    Outlet_Establishment_Year,
    num_outlets,
    total_sales,
    ROUND(total_sales * 1.0 / num_outlets, 2) AS avg_sales_per_outlet
FROM yearly_sales
ORDER BY Outlet_Establishment_Year;

-- Q5: Running (cumulative) sales total by outlet, ordered by sales rank (WINDOW FUNCTION)
WITH outlet_sales AS (
    SELECT
        o.Outlet_Identifier,
        o.Outlet_Type,
        SUM(f.Item_Outlet_Sales) AS total_sales
    FROM fact_sales f
    JOIN dim_outlet o ON f.Outlet_Identifier = o.Outlet_Identifier
    GROUP BY o.Outlet_Identifier
)
SELECT
    Outlet_Identifier,
    Outlet_Type,
    total_sales,
    ROUND(SUM(total_sales) OVER (ORDER BY total_sales DESC), 2) AS running_total_sales,
    ROUND(100.0 * total_sales / SUM(total_sales) OVER (), 2) AS pct_of_total_sales
FROM outlet_sales
ORDER BY total_sales DESC;

-- Q6: Fat content vs average item visibility and average sales (JOIN + GROUP BY, business framing)
SELECT
    i.Item_Fat_Content,
    COUNT(*) AS num_items,
    ROUND(AVG(i.Item_Visibility)*100, 3) AS avg_visibility_pct,
    ROUND(AVG(f.Item_Outlet_Sales), 2) AS avg_sales
FROM fact_sales f
JOIN dim_item i ON f.Item_Identifier = i.Item_Identifier
GROUP BY i.Item_Fat_Content
ORDER BY avg_sales DESC;
