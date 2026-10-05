-- ============================================================
-- MarketCo Customer Behaviour Analysis
-- Google BigQuery | dataset: mis784
-- Tables: mis784.customer (21,618 rows), mis784.contract (143,785 rows)
--
-- Method note: contract data has many rows per customer, so every
-- customer-level metric is aggregated to one row per customer
-- BEFORE joining to customer attributes. Joining first would repeat
-- each customer's attributes once per contract and distort averages.
-- ============================================================


-- ------------------------------------------------------------
-- 0. Data checks
-- ------------------------------------------------------------

SELECT COUNT(*) AS total_customers FROM mis784.customer;

SELECT COUNT(*) AS total_contracts FROM mis784.contract;

-- Contracts whose Cost_ID has no matching customer record.
-- Result: 14,574 contracts (10.1%). Used in the Limitations section.
SELECT
  COUNT(*) AS Contracts_Without_Customer,
  ROUND(COUNT(*) / (SELECT COUNT(*) FROM mis784.contract) * 100, 1) AS Pct_Of_All_Contracts
FROM mis784.contract ct
WHERE NOT EXISTS (
  SELECT 1 FROM mis784.customer c WHERE c.Cost_ID = ct.Cost_ID
);


-- ============================================================
-- FINDING 1: Gold Membership behaviour
-- Groups: Active (no end date), Former (ended), Never
-- ============================================================

-- 1a. Purchase frequency and spending by membership status
WITH Active_gold_membership AS (
  SELECT DISTINCT Cost_ID
  FROM mis784.contract
  WHERE Product = 'Gold_Membership' AND Fulfilment_Ended_Date IS NULL
),

Former_gold_membership AS (
  SELECT DISTINCT Cost_ID
  FROM mis784.contract
  WHERE Product = 'Gold_Membership' AND Fulfilment_Ended_Date IS NOT NULL
),

customer_summary AS (
  SELECT
    Cost_ID,
    COUNT(DISTINCT Contract_ID) AS Purchase_Frequency,
    SUM(Total_Paid) AS Total_Spent
  FROM mis784.contract
  GROUP BY Cost_ID
)

SELECT
  CASE
    WHEN c.Cost_ID IN (SELECT Cost_ID FROM Active_gold_membership) THEN 'Active Gold Member'
    WHEN c.Cost_ID IN (SELECT Cost_ID FROM Former_gold_membership) THEN 'Former Gold Member'
    ELSE 'Never Gold Member'
  END AS Membership_Status,
  COUNT(DISTINCT c.Cost_ID) AS Number_Of_Customers,
  ROUND(AVG(COALESCE(cs.Purchase_Frequency, 0)), 2) AS Avg_Purchase_Frequency,
  ROUND(SUM(COALESCE(cs.Total_Spent, 0)), 2) AS Total_Spending,
  ROUND(AVG(COALESCE(cs.Total_Spent, 0)), 2) AS Avg_Spending_Per_Customer
FROM mis784.customer c
LEFT JOIN customer_summary cs ON c.Cost_ID = cs.Cost_ID
GROUP BY Membership_Status
ORDER BY Membership_Status;

-- 1b. Communication by membership status
-- Communication columns belong to the customer table, so no join to
-- contract is needed and each customer appears exactly once.
WITH Active_gold_membership AS (
  SELECT DISTINCT Cost_ID
  FROM mis784.contract
  WHERE Product = 'Gold_Membership' AND Fulfilment_Ended_Date IS NULL
),

Former_gold_membership AS (
  SELECT DISTINCT Cost_ID
  FROM mis784.contract
  WHERE Product = 'Gold_Membership' AND Fulfilment_Ended_Date IS NOT NULL
)

SELECT
  CASE
    WHEN c.Cost_ID IN (SELECT Cost_ID FROM Active_gold_membership) THEN 'Active Gold Member'
    WHEN c.Cost_ID IN (SELECT Cost_ID FROM Former_gold_membership) THEN 'Former Gold Member'
    ELSE 'Never Gold Member'
  END AS Membership_Status,
  COUNT(DISTINCT c.Cost_ID) AS Number_Of_Customers,
  ROUND(AVG(c.Number_Of_Inbound_Communication_In_24_MTH), 2) AS Avg_Inbound_24M,
  ROUND(AVG(c.Number_Of_Outbound_Communication_In_24_MTH), 2) AS Avg_Outbound_24M,
  ROUND(AVG(c.Number_Of_Inbound_Communication_In_60_MTH), 2) AS Avg_Inbound_60M,
  ROUND(AVG(c.Number_Of_Outbound_Communication_In_60_MTH), 2) AS Avg_Outbound_60M
FROM mis784.customer c
GROUP BY Membership_Status
ORDER BY Membership_Status;


-- ============================================================
-- FINDING 2: Age and spending
-- ============================================================

-- 2a. Spending and communication by age group
WITH customer_spend AS (
  SELECT Cost_ID, SUM(Total_Paid) AS Total_Spent
  FROM mis784.contract
  GROUP BY Cost_ID
)

SELECT
  CASE
    WHEN c.Age < 18 THEN 'Under 18'
    WHEN c.Age BETWEEN 18 AND 30 THEN '18 - 30'
    WHEN c.Age BETWEEN 31 AND 45 THEN '31 - 45'
    WHEN c.Age BETWEEN 46 AND 55 THEN '46 - 55'
    ELSE 'Above 55'
  END AS Age_Group,
  COUNT(DISTINCT c.Cost_ID) AS Customer_Count,
  ROUND(AVG(c.Number_Of_Inbound_Communication_In_24_MTH), 2) AS Avg_Inbound_24M,
  ROUND(AVG(c.Number_Of_Outbound_Communication_In_24_MTH), 2) AS Avg_Outbound_24M,
  ROUND(AVG(COALESCE(cs.Total_Spent, 0)), 2) AS Avg_Spending
FROM mis784.customer c
LEFT JOIN customer_spend cs ON c.Cost_ID = cs.Cost_ID
GROUP BY Age_Group
ORDER BY
  CASE
    WHEN Age_Group = 'Under 18' THEN 1
    WHEN Age_Group = '18 - 30' THEN 2
    WHEN Age_Group = '31 - 45' THEN 3
    WHEN Age_Group = '46 - 55' THEN 4
    ELSE 5
  END;

-- 2b. Average tenure by age group
SELECT
  CASE
    WHEN Age < 18 THEN 'Under 18'
    WHEN Age BETWEEN 18 AND 30 THEN '18 - 30'
    WHEN Age BETWEEN 31 AND 45 THEN '31 - 45'
    WHEN Age BETWEEN 46 AND 55 THEN '46 - 55'
    ELSE 'Above 55'
  END AS Age_Group,
  ROUND(AVG(Tenure), 2) AS Avg_Tenure_Months
FROM mis784.customer
GROUP BY Age_Group
ORDER BY
  CASE
    WHEN Age_Group = 'Under 18' THEN 1
    WHEN Age_Group = '18 - 30' THEN 2
    WHEN Age_Group = '31 - 45' THEN 3
    WHEN Age_Group = '46 - 55' THEN 4
    ELSE 5
  END;

-- 2c. Share of High / Highest income customers by age group
WITH age_affluence AS (
  SELECT
    CASE
      WHEN Age < 18 THEN 'Under 18'
      WHEN Age BETWEEN 18 AND 30 THEN '18 - 30'
      WHEN Age BETWEEN 31 AND 45 THEN '31 - 45'
      WHEN Age BETWEEN 46 AND 55 THEN '46 - 55'
      ELSE 'Above 55'
    END AS Age_Group,
    CASE
      WHEN Affluence_Level IN ('High income High assets', 'Highest income and assets') THEN 'High/Highest'
      ELSE 'Other'
    END AS Income_Tier
  FROM mis784.customer
)

SELECT
  Age_Group,
  COUNTIF(Income_Tier = 'High/Highest') AS High_Income_Count,
  COUNT(*) AS Total_Count,
  ROUND(COUNTIF(Income_Tier = 'High/Highest') / COUNT(*) * 100, 1) AS Pct_High_Income
FROM age_affluence
GROUP BY Age_Group
ORDER BY
  CASE
    WHEN Age_Group = 'Under 18' THEN 1
    WHEN Age_Group = '18 - 30' THEN 2
    WHEN Age_Group = '31 - 45' THEN 3
    WHEN Age_Group = '46 - 55' THEN 4
    ELSE 5
  END;

-- 2d. Value per contract by product and age group
-- Value per contract is nearly fixed within each product.
SELECT
  CASE
    WHEN c.Age < 18 THEN 'Under 18'
    WHEN c.Age BETWEEN 18 AND 30 THEN '18 - 30'
    WHEN c.Age BETWEEN 31 AND 45 THEN '31 - 45'
    WHEN c.Age BETWEEN 46 AND 55 THEN '46 - 55'
    ELSE 'Above 55'
  END AS Age_Group,
  ct.Product,
  ROUND(AVG(ct.Total_Paid), 2) AS Avg_Paid_Per_Contract,
  COUNT(*) AS Contract_Count
FROM mis784.customer c
JOIN mis784.contract ct ON c.Cost_ID = ct.Cost_ID
GROUP BY Age_Group, ct.Product
ORDER BY Age_Group, ct.Product;

-- 2e. Average contracts per customer by age group
SELECT
  CASE
    WHEN c.Age < 18 THEN 'Under 18'
    WHEN c.Age BETWEEN 18 AND 30 THEN '18 - 30'
    WHEN c.Age BETWEEN 31 AND 45 THEN '31 - 45'
    WHEN c.Age BETWEEN 46 AND 55 THEN '46 - 55'
    ELSE 'Above 55'
  END AS Age_Group,
  COUNT(DISTINCT c.Cost_ID) AS Customer_Count,
  COUNT(ct.Contract_ID) AS Total_Contracts,
  ROUND(COUNT(ct.Contract_ID) / COUNT(DISTINCT c.Cost_ID), 2) AS Avg_Contracts_Per_Customer
FROM mis784.customer c
LEFT JOIN mis784.contract ct ON c.Cost_ID = ct.Cost_ID
GROUP BY Age_Group
ORDER BY
  CASE
    WHEN Age_Group = 'Under 18' THEN 1
    WHEN Age_Group = '18 - 30' THEN 2
    WHEN Age_Group = '31 - 45' THEN 3
    WHEN Age_Group = '46 - 55' THEN 4
    ELSE 5
  END;


-- ============================================================
-- FINDING 3: Technology (operating system and browser)
-- ============================================================

-- 3a. Customers and communication by operating system
SELECT
  CASE Operating_System
    WHEN 1 THEN 'Windows'
    WHEN 2 THEN 'macOS'
    WHEN 3 THEN 'Linux'
    WHEN 4 THEN 'Android'
    ELSE 'Unknown'
  END AS OS,
  COUNT(*) AS Customer_Count,
  ROUND(AVG(Number_Of_Inbound_Communication_In_24_MTH), 2) AS Avg_Inbound_24M,
  ROUND(AVG(Number_Of_Outbound_Communication_In_24_MTH), 2) AS Avg_Outbound_24M
FROM mis784.customer
GROUP BY OS
ORDER BY Customer_Count DESC;

-- 3b. Customers and communication by browser
SELECT
  CASE Browser_type
    WHEN 1 THEN 'Chrome'
    WHEN 2 THEN 'Firefox'
    WHEN 3 THEN 'Safari'
    WHEN 4 THEN 'Edge'
    WHEN 5 THEN 'Opera'
    ELSE 'Unknown'
  END AS Browser,
  COUNT(*) AS Customer_Count,
  ROUND(AVG(Number_Of_Inbound_Communication_In_24_MTH), 2) AS Avg_Inbound_24M,
  ROUND(AVG(Number_Of_Outbound_Communication_In_24_MTH), 2) AS Avg_Outbound_24M
FROM mis784.customer
GROUP BY Browser
ORDER BY Customer_Count DESC;

-- 3c. Contracts, spending and spread of spending by operating system
-- NOTE: the Std_Dev_Spending column is new and should be re-run to
-- confirm the "$700 to $800" figure quoted in Recommendation 3.
WITH customer_contracts AS (
  SELECT Cost_ID, COUNT(Contract_ID) AS Contract_Count, SUM(Total_Paid) AS Total_Spent
  FROM mis784.contract
  GROUP BY Cost_ID
)

SELECT
  CASE c.Operating_System
    WHEN 1 THEN 'Windows'
    WHEN 2 THEN 'macOS'
    WHEN 3 THEN 'Linux'
    WHEN 4 THEN 'Android'
    ELSE 'Unknown'
  END AS OS,
  COUNT(*) AS Customer_Count,
  ROUND(AVG(COALESCE(cc.Contract_Count, 0)), 2) AS Avg_Contracts,
  ROUND(AVG(COALESCE(cc.Total_Spent, 0)), 2) AS Avg_Spending,
  ROUND(STDDEV(COALESCE(cc.Total_Spent, 0)), 2) AS Std_Dev_Spending
FROM mis784.customer c
LEFT JOIN customer_contracts cc ON c.Cost_ID = cc.Cost_ID
GROUP BY OS
ORDER BY Avg_Spending DESC;

-- 3d. Contracts, spending and spread of spending by browser
WITH customer_contracts AS (
  SELECT Cost_ID, COUNT(Contract_ID) AS Contract_Count, SUM(Total_Paid) AS Total_Spent
  FROM mis784.contract
  GROUP BY Cost_ID
)

SELECT
  CASE c.Browser_type
    WHEN 1 THEN 'Chrome'
    WHEN 2 THEN 'Firefox'
    WHEN 3 THEN 'Safari'
    WHEN 4 THEN 'Edge'
    WHEN 5 THEN 'Opera'
    ELSE 'Unknown'
  END AS Browser,
  COUNT(*) AS Customer_Count,
  ROUND(AVG(COALESCE(cc.Contract_Count, 0)), 2) AS Avg_Contracts,
  ROUND(AVG(COALESCE(cc.Total_Spent, 0)), 2) AS Avg_Spending,
  ROUND(STDDEV(COALESCE(cc.Total_Spent, 0)), 2) AS Std_Dev_Spending
FROM mis784.customer c
LEFT JOIN customer_contracts cc ON c.Cost_ID = cc.Cost_ID
GROUP BY Browser
ORDER BY Avg_Spending DESC;


-- ============================================================
-- FINDING 4: State
-- ============================================================

-- 4a. Customers and communication by state
SELECT
  State,
  COUNT(*) AS Customer_Count,
  ROUND(AVG(Number_Of_Inbound_Communication_In_24_MTH), 2) AS Avg_Inbound_24M,
  ROUND(AVG(Number_Of_Outbound_Communication_In_24_MTH), 2) AS Avg_Outbound_24M
FROM mis784.customer
GROUP BY State
ORDER BY Customer_Count DESC;

-- 4b. Contracts and spending by state
WITH customer_contracts AS (
  SELECT
    Cost_ID,
    COUNT(Contract_ID) AS Contract_Count,
    SUM(Total_Paid) AS Total_Spent
  FROM mis784.contract
  GROUP BY Cost_ID
)

SELECT
  c.State,
  COUNT(DISTINCT c.Cost_ID) AS Customer_Count,
  ROUND(AVG(COALESCE(cc.Contract_Count, 0)), 2) AS Avg_Contracts_Per_Customer,
  ROUND(AVG(COALESCE(cc.Total_Spent, 0)), 2) AS Avg_Spending
FROM mis784.customer c
LEFT JOIN customer_contracts cc ON c.Cost_ID = cc.Cost_ID
GROUP BY c.State
ORDER BY Avg_Spending DESC;


-- ============================================================
-- FINDING 5: Gender
-- ============================================================

-- 5a. Customers and communication by gender
SELECT
  Gender,
  COUNT(*) AS Customer_Count,
  ROUND(AVG(Number_Of_Inbound_Communication_In_24_MTH), 2) AS Avg_Inbound_24M,
  ROUND(AVG(Number_Of_Outbound_Communication_In_24_MTH), 2) AS Avg_Outbound_24M
FROM mis784.customer
GROUP BY Gender
ORDER BY Customer_Count DESC;

-- 5b. Contracts and spending by gender
WITH customer_contracts AS (
  SELECT
    Cost_ID,
    COUNT(Contract_ID) AS Contract_Count,
    SUM(Total_Paid) AS Total_Spent
  FROM mis784.contract
  GROUP BY Cost_ID
)

SELECT
  c.Gender,
  COUNT(DISTINCT c.Cost_ID) AS Customer_Count,
  ROUND(AVG(COALESCE(cc.Contract_Count, 0)), 2) AS Avg_Contracts_Per_Customer,
  ROUND(AVG(COALESCE(cc.Total_Spent, 0)), 2) AS Avg_Spending
FROM mis784.customer c
LEFT JOIN customer_contracts cc ON c.Cost_ID = cc.Cost_ID
GROUP BY c.Gender;

-- 5c. Value per contract by product and gender
SELECT
  c.Gender,
  ct.Product,
  COUNT(*) AS Contract_Count,
  ROUND(AVG(ct.Total_Paid), 2) AS Avg_Paid_Per_Contract
FROM mis784.customer c
JOIN mis784.contract ct ON c.Cost_ID = ct.Cost_ID
GROUP BY c.Gender, ct.Product
ORDER BY c.Gender, ct.Product;

-- 5d. Where the male/female spending gap comes from:
-- contracts and spending per customer by product
-- (denominator = all customers of that gender, including those with no contracts)
WITH gender_customers AS (
  SELECT Gender, COUNT(*) AS Customers
  FROM mis784.customer
  GROUP BY Gender
)

SELECT
  c.Gender,
  ct.Product,
  ROUND(COUNT(*) / ANY_VALUE(g.Customers), 3) AS Contracts_Per_Customer,
  ROUND(SUM(ct.Total_Paid) / ANY_VALUE(g.Customers), 1) AS Spending_Per_Customer
FROM mis784.customer c
JOIN mis784.contract ct ON c.Cost_ID = ct.Cost_ID
JOIN gender_customers g ON c.Gender = g.Gender
WHERE c.Gender IN ('Female', 'Male')
GROUP BY c.Gender, ct.Product
ORDER BY ct.Product, c.Gender;


-- ============================================================
-- RECOMMENDATION 4: International customers
-- ============================================================

-- 6a. Tenure, contracts and spending: International vs Australian states
-- (customers with no recorded state are excluded)
WITH customer_contracts AS (
  SELECT Cost_ID, COUNT(Contract_ID) AS Contract_Count, SUM(Total_Paid) AS Total_Spent
  FROM mis784.contract
  GROUP BY Cost_ID
)

SELECT
  CASE WHEN c.State = 'INTERNATIONAL' THEN 'International' ELSE 'Australian states' END AS Market,
  COUNT(*) AS Customer_Count,
  ROUND(AVG(c.Tenure), 2) AS Avg_Tenure_Months,
  ROUND(AVG(COALESCE(cc.Contract_Count, 0)), 2) AS Avg_Contracts,
  ROUND(AVG(COALESCE(cc.Total_Spent, 0)), 2) AS Avg_Spending
FROM mis784.customer c
LEFT JOIN customer_contracts cc ON c.Cost_ID = cc.Cost_ID
WHERE c.State IS NOT NULL
GROUP BY Market;

-- 6b. Product mix of International customers
SELECT
  ct.Product,
  COUNT(*) AS Contract_Count,
  ROUND(AVG(ct.Total_Paid), 2) AS Avg_Paid_Per_Contract
FROM mis784.customer c
JOIN mis784.contract ct ON c.Cost_ID = ct.Cost_ID
WHERE c.State = 'INTERNATIONAL'
GROUP BY ct.Product
ORDER BY Contract_Count DESC;
