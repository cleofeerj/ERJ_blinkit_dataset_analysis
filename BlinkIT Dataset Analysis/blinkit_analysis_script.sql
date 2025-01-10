-- ----------------------------------- BLINKIT GROCERY ANALYSIS -----------------------------------

USE blinkit_grocery_dataset;

-- 1.) DUPLICATE DATASET
-- 2.) »¿Item Fat Content to Item Fat Content
-- 3 - 4.) CHANGE THE INCOSISTENT VALUES (LF, low fat, reg)
-- 5.) SPACES
-- 6.) NULL VALUES (Just double checking)
-- 7.) REMOVING DUPLICATE DATA
-- 8.) Replaced Null Values in Item_Weight_New
-- 9.) REPLACE 0 VALUES - Item Visibilty
-- 10.) UPDATE DATA TYPES
-- 11.) ANSWER QUESTIONS

-- ----------------------------------- 1.) DUPLICATE DATASET -----------------------------------
CREATE TABLE blinkit_dupli LIKE `blinkit grocery data excel`;
INSERT blinkit_dupli SELECT * FROM `blinkit grocery data excel`;

SELECT COUNT(*) FROM blinkit_dupli;

-- ----------------------------------- 2.) »¿Item Fat Content to Item Fat Content  -----------------------------------

ALTER TABLE blinkit_dupli
CHANGE COLUMN `ï»¿Item Fat Content` `Item Fat Content` VARCHAR(50);


-- ----------------------------------- 3 - 4.) CHANGE THE INCOSISTENT VALUES -----------------------------------

UPDATE blinkit_dupli
SET `Item Fat Content` = CASE
	WHEN `Item Fat Content` LIKE "LF%" THEN "Low Fat"
    WHEN `Item Fat Content` LIKE "low%" THEN "Low Fat"
    WHEN `Item Fat Content` Like "reg%" THEN "Regular"
    WHEN `Item Fat Content` LIKE "Low%" THEN "Low Fat"
    WHEN `Item Fat Content` LIKE "Regular%" THEN "Regular"
    ELSE NULL
END;


-- ----------------------------------- 5.) SPACES -----------------------------------
UPDATE blinkit_dupli
SET Item_Weight_New = TRIM(Item_Weight_New);

UPDATE blinkit_dupli
SET Sales = TRIM(Sales);

-- ALTERNATE CODE

UPDATE blinkit_dupli
SET Sales = REPLACE(Sales, ' ', '');

UPDATE blinkit_dupli
SET Item_Weight_New = REPLACE(Item_Weight_New, ' ', '');

-- ----------------------------------- 6.) NULL VALUES  -----------------------------------
-- Just double checking
SELECT * FROM blinkit_dupli WHERE Item_Weight_New IS NULL;

SELECT * FROM blinkit_dupli WHERE `Item Identifier` LIKE "NCY18";

SELECT * FROM blinkit_dupli WHERE `Item Fat Content` = "Low Fat";



-- ----------------------------------- .) REMOVING DUPLICATE DATA  -----------------------------------

-- Added row_num that identifies unique rows, 1 & 2 (duplicate)

SELECT *,
	ROW_NUMBER() OVER(
		PARTITION BY `Item Fat Content`, `Item Identifier`, `Item Type`, `Outlet Establishment Year`,
                            `Outlet Identifier`, `Outlet Location Type`, `Outlet Size`, `Outlet Type`,
                            `Item Visibility`, Sales, Rating, Item_Weight_New
    ) AS row_num
FROM blinkit_dupli;


-- Created a temporary table to filter the duplicate (2's)

WITH duplicate_cte AS 
(
SELECT *,
	ROW_NUMBER() OVER(
		PARTITION BY `Item Fat Content`, `Item Identifier`, `Item Type`, `Outlet Establishment Year`,
                            `Outlet Identifier`, `Outlet Location Type`, `Outlet Size`, `Outlet Type`,
                            `Item Visibility`, Sales, Rating, Item_Weight_New
    ) AS row_num
FROM blinkit_dupli
)
SELECT * 
FROM duplicate_cte
WHERE row_num > 1;


-- Since it is not deleteable, we create a table that has the row_num column
-- Inserted the row_num column

CREATE TABLE `blinkit_dupli_2` (
  `Item Fat Content` varchar(50) DEFAULT NULL,
  `Item Identifier` text,
  `Item Type` text,
  `Outlet Establishment Year` int DEFAULT NULL,
  `Outlet Identifier` text,
  `Outlet Location Type` text,
  `Outlet Size` text,
  `Outlet Type` text,
  `Item Visibility` double DEFAULT NULL,
  `Sales` double DEFAULT NULL,
  `Rating` int DEFAULT NULL,
  `Item_Weight_New` double DEFAULT NULL,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- Insertion of data into the new table

SELECT * 
FROM blinkit_dupli_2;

INSERT INTO blinkit_dupli_2
SELECT *,
	ROW_NUMBER() OVER(
		PARTITION BY `Item Fat Content`, `Item Identifier`, `Item Type`, `Outlet Establishment Year`,
                            `Outlet Identifier`, `Outlet Location Type`, `Outlet Size`, `Outlet Type`,
                            `Item Visibility`, Sales, Rating, Item_Weight_New
    ) AS row_num
FROM blinkit_dupli;

-- DELETE THE DUPLICATES (2's)

DELETE FROM blinkit_dupli_2 WHERE row_num > 1;

ALTER TABLE blinkit_dupli_2
DROP COLUMN row_num;


SELECT COUNT(*) FROM blinkit_dupli_2;
SELECT * FROM blinkit_dupli_2;

-- ----------------------------------- .) REPLACE NULL VALUES  -----------------------------------

-- Created a column RowNum for determining Groups
-- Count within each group for determining if it is ODD or EVEN for getting the Median

CREATE TEMPORARY TABLE RankedWeights AS
SELECT 
    `Item Identifier`, 
    Item_Weight_New,
    ROW_NUMBER() OVER (
        PARTITION BY `Item Identifier` 
        ORDER BY Item_Weight_New
    ) AS RowNum,
    COUNT(*) OVER (PARTITION BY `Item Identifier`) AS TotalCount
FROM blinkit_dupli_2
WHERE Item_Weight_New IS NOT NULL;


-- CALCULATIONS

CREATE TEMPORARY TABLE MedianValues AS
SELECT 
    `Item Identifier`,
    -- Calculates when the Total number of instances is ODD
    MAX(CASE WHEN TotalCount % 2 = 1 AND RowNum = (TotalCount + 1) / 2 THEN Item_Weight_New END) AS OddMedian,
    -- Calculates when the Total number of instances is EVEN
    AVG(CASE 
        WHEN TotalCount % 2 = 0 AND RowNum IN (TotalCount / 2, (TotalCount / 2) + 1) 
        THEN Item_Weight_New 
    END) AS EvenMedian,
    CASE 
    -- USED THIS FOR FINAL OUTPUT STORED BEING IN ONE COLUMN
        WHEN TotalCount % 2 = 1 THEN 
            MAX(CASE WHEN RowNum = (TotalCount + 1) / 2 THEN Item_Weight_New END)
        ELSE 
            AVG(CASE 
                WHEN RowNum IN (TotalCount / 2, (TotalCount / 2) + 1) 
                THEN Item_Weight_New 
            END)
    END AS Median_Weight
FROM RankedWeights
GROUP BY `Item Identifier`, TotalCount;


-- Update the values

-- If blinkit_dupli_2 has Item Identifier = 'DRA12',
-- the subquery retrieves the Median_Weight for 'DRA12' from the MedianValues table.

UPDATE blinkit_dupli_2
SET Item_Weight_New = (
    SELECT Median_Weight 
    FROM MedianValues 
    WHERE MedianValues.`Item Identifier` = blinkit_dupli_2.`Item Identifier`
)
WHERE Item_Weight_New IS NULL;


SELECT * FROM blinkit_dupli_2;


-- EXAMPLE:

-- Input Group: Item_Weight_New = [3, 5, 7, 9, 11]
-- TotalCount = 5 (odd).
-- Median = (5 + 1) / 2 = 3rd row = 7.

-- Input Group: Item_Weight_New = [3, 5, 7, 9]
-- TotalCount = 4 (even).
-- Median = AVG(2nd row, 3rd row) = (5 + 7) / 2 = 6.




-- ----------------------------------- .) REPLACE 0 VALUES - Item Visibilty  -----------------------------------


CREATE TEMPORARY TABLE RankedVisibility AS
SELECT 
    `Item Identifier`, 
    `Item Visibility`,
    ROW_NUMBER() OVER (
        PARTITION BY `Item Identifier` 
        ORDER BY `Item Visibility`
    ) AS RowNum,
    COUNT(*) OVER (PARTITION BY `Item Identifier`) AS TotalCount
FROM blinkit_dupli_2
WHERE `Item Visibility` IS NOT NULL AND `Item Visibility` != 0;

CREATE TEMPORARY TABLE MedianVisibility AS
SELECT 
    `Item Identifier`,
    CASE
        WHEN TotalCount % 2 = 1 THEN 
            ROUND(MAX(CASE WHEN RowNum = (TotalCount + 1) / 2 THEN `Item Visibility` END), 9)
        ELSE 
            ROUND(AVG(CASE 
                WHEN RowNum IN (TotalCount / 2, (TotalCount / 2) + 1) 
                THEN `Item Visibility`
            END), 9)
    END AS Median_Visibility
FROM RankedVisibility
GROUP BY `Item Identifier`, TotalCount;

UPDATE blinkit_dupli_2
SET `Item Visibility` = (
    SELECT Median_Visibility 
    FROM MedianVisibility 
    WHERE MedianVisibility.`Item Identifier` = blinkit_dupli_2.`Item Identifier`
)
WHERE `Item Visibility` = 0;


UPDATE blinkit_dupli_2
SET `Item Visibility` = ROUND(`Item Visibility`, 6);

-- ----------------------------------- 10.) UPDATE DATA TYPES -----------------------------------
ALTER TABLE blinkit_dupli_2
MODIFY COLUMN `Item Identifier` VARCHAR(20);

ALTER TABLE blinkit_dupli_2
MODIFY COLUMN `Outlet Identifier` VARCHAR(20);

ALTER TABLE blinkit_dupli_2
MODIFY COLUMN `Outlet Location Type` VARCHAR(20);

ALTER TABLE blinkit_dupli_2
MODIFY COLUMN `Outlet Type` VARCHAR(50);


-- ----------------------------------- ANSWER QUESTIONS -----------------------------------

-- 1.) Total Sales by Fat Content: Chart Type: Donut Chart.

-- Objective: Analyze the impact of fat content on total sales.
-- Additional KPI Metrics: Assess how other KPIs (Average Sales, Number of Items, Average Rating) vary with fat content.

SELECT 
    `Item Fat Content`,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales,
    COUNT(*) AS Number_of_Items,
    ROUND(AVG(Rating), 2) AS Average_Rating
FROM blinkit_dupli_2
GROUP BY `Item Fat Content`;


-- 2.) Total Sales by Item Type: -- Chart Type: Bar Chart.

-- Objective: Identify the performance of different item types in terms of total sales.
-- Additional KPI Metrics: Assess how other KPIs (Average Sales, Number of Items, Average Rating) vary with fat content.

SELECT 
    `Item Fat Content`,
    `Item Type`,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales,
    COUNT(*) AS Number_of_Items,
    ROUND(AVG(Rating), 2) AS Average_Rating
FROM blinkit_dupli_2
GROUP BY `Item Fat Content`, `Item Type`;


-- 3.) Fat Content by Outlet for Total Sales: Chart Type: Stacked Column Chart.
SELECT * FROM blinkit_dupli_2;
-- Objective: Compare total sales across different outlets segmented by fat content.
-- Additional KPI Metrics: Assess how other KPIs (Average Sales, Number of Items, Average Rating) vary with fat content.
SELECT 
    `Outlet Identifier`,
    `Item Fat Content`,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales,
    COUNT(*) AS Number_of_Items,
    ROUND(AVG(Rating), 2) AS Average_Rating
FROM blinkit_dupli_2
GROUP BY `Outlet Identifier`, `Item Fat Content`
ORDER BY `Outlet Identifier`, `Item Fat Content`;

-- 4.) Total Sales by Outlet Establishment:

-- Objective: Evaluate how the age or type of outlet establishment influences total sales.
-- Chart Type: Line Chart.

SELECT 
    `Outlet Establishment Year`,
    `Outlet Type`,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales,
    COUNT(*) AS Number_of_Items,
    ROUND(AVG(Rating), 2) AS Average_Rating
FROM blinkit_dupli_2
GROUP BY `Outlet Establishment Year`, `Outlet Type`;



-- 5.) Sales by Outlet Size:

-- Objective: Analyze the correlation between outlet size and total sales.
-- Chart Type: Donut/Pie Chart.

SELECT 
    `Outlet Size`,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales,
    COUNT(*) AS Number_of_Items,
    ROUND(AVG(Rating), 2) AS Average_Rating
FROM blinkit_dupli_2
GROUP BY `Outlet Size`;



-- 6.) Sales by Outlet Location:

-- Objective: Assess the geographic distribution of sales across different locations.
-- Chart Type: Funnel Map.

SELECT
	`Outlet Location Type`,
	ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales,
    COUNT(*) AS Number_of_Items,
    ROUND(AVG(Rating), 2) AS Average_Rating
FROM blinkit_dupli_2
GROUP BY `Outlet Location Type`;




-- 7.) All Metrics by Outlet Type:

-- Objective: Provide a comprehensive view of all key metrics (Total Sales, Average Sales, Number of Items, Average Rating) broken down by different outlet types.
-- Chart Type: Matrix Card.
SELECT
	`Outlet Type`,
	ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales,
    COUNT(*) AS Number_of_Items,
    ROUND(AVG(Rating), 2) AS Average_Rating
FROM blinkit_dupli_2
GROUP BY `Outlet Type`;


-- 8.) Determine the relation of Item Visibility & Sales

SELECT * FROM blinkit_dupli_2;

-- Add a New Column for Categorization
ALTER TABLE blinkit_dupli_2
ADD COLUMN Visibility_Category VARCHAR(10);

-- Update the New Column with Categories
UPDATE blinkit_dupli_2
SET Visibility_Category = CASE 
    WHEN `Item Visibility` <= 0.10 THEN 'Low'
    WHEN `Item Visibility` > 0.10 AND `Item Visibility` <= 0.20 THEN 'Medium'
    ELSE 'High'
END;


SELECT `Item Visibility`, Visibility_Category
FROM blinkit_dupli_2;

-- Relation of Item Visibilty to Sales

SELECT 
    Visibility_Category,
    COUNT(*) AS Number_of_Items,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(AVG(Sales), 2) AS Average_Sales
FROM blinkit_dupli_2
GROUP BY Visibility_Category
ORDER BY Total_Sales DESC;


-- 9.) TOTAL SALES

SELECT 
    CONCAT('$', ROUND(SUM(Sales), 0)) AS Overall_Sales
FROM blinkit_dupli_2;

-- 10.) AVERAGE SALES

SELECT
	CONCAT('$', ROUND(AVG(Sales), 0)) AS Average_Sales
FROM blinkit_dupli_2;

-- 11.) TOTAL INSTANCES/ITEMS

SELECT COUNT(*) AS Total_Items FROM blinkit_dupli_2;

-- 12.) AVERAGE RATING

SELECT
	ROUND(AVG(Rating), 1) AS Average_Rating
FROM blinkit_dupli_2;
    

