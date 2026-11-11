# EXPLORATORY DATA ANALYSIS
USE product_sales_analysis;

DESCRIBE sales_log;
DESCRIBE product;
DESCRIBE geography;
DESCRIBE ware_house;

-- checking null values
SELECT *
FROM product
WHERE Product_Link is NULL; --- ONE  NULL 

SELECT *
FROM sales_log
WHERE `Date` AND  `Order_ID` AND Product_ID AND `Dest. Warehouse` AND
	  `Shipping_Time(Expected)` AND `Shipping_Time(Actual)` AND
      `Delay_Risk?` AND `Total_No._of_Pieces` AND `No._of_pieces_sold` AND 
      `No._of_Pieces_Returned` AND  `Avg._Batch_Rating` AND Geograpy_Key AND `Data`
      IS NULL;
      
# DATA CLEANING
-- Removing unwanted columns
ALTER TABLE sales_log
DROP COLUMN data;

-- Changing Data Type
UPDATE sales_log
SET `Date` = str_to_date(`Date`, "%m/%d/%Y");

ALTER TABLE sales_log
MODIFY COLUMN `Date` Date;

-- Filling missing values
UPDATE product
SET Product_Link = "https://www.pngkey.com/png/detail/80-801028_langham-30mm-black-belt-png-image-british-belt.png"
WHERE Product_ID = 'P013';

# DATA ANALYSIS
-- PRODUCT ANALYSIS

-- Which 10 products contribute the most revenue, and for each one, how do their customer 
-- satisfaction ratings and share of returned items compare to the overall market, 
-- including their return-risk classification?

WITH total_returns as(SELECT SUM(`No._of_Pieces_Returned`) AS Total_Returns
					  From sales_log
                      WHERE Geograpy_Key = (SELECT GeographyKey
										     FROM geography 
                                             WHERE State = 'California')),

	top10_analysis as (
				SELECT p.`Name`,
						sum(p.Selling_Price * s.`No._of_pieces_sold`) AS Total_Sales,
                        ROUND(AVG(`Avg._Batch_Rating`)) AS Avg_Rating,
                        CONCAT(ROUND(SUM(`No._of_Pieces_Returned`)/ (SELECT Total_Returns FROM total_returns) *100,2), "%") AS Percent_Of_Return,
                        CASE
							WHEN SUM(`No._of_Pieces_Returned`) <= 5000 THEN "Low Return Rate"
                            WHEN SUM(`No._of_Pieces_Returned`) <= 15000 THEN "Mid Return Rate"
                            WHEN SUM(`No._of_Pieces_Returned`) <= 35000 THEN "High Return Rate"
						ELSE
							"Critical Return Rate"
						END AS Return_Category
                FROM sales_log AS s
                LEFT JOIN product p
                USING (Product_ID)
				WHERE Geograpy_Key = (SELECT GeographyKey FROM geography WHERE State = 'California')
                GROUP BY p.`Name`
				)
SELECT *
FROM top10_analysis
ORDER BY Total_Sales DESC
LIMIT 10;
                
-- Which five products have the highest shipping-delay risk, what percentage of total delays do they account for, and what is their average shipping delay time?
 WITH delay_risk AS (SELECT 
							SUM(CASE 
									WHEN (`Delay_Risk?`)  = "Yes" THEN 1 
                                    ELSE 0
                                    END)AS Total_Delays
				    FROM sales_log
                    WHERE Geograpy_Key = (SELECT GeographyKey FROM geography WHERE State = 'Florida')),
	Top_Delay_Risk_Prod AS(SELECT `Name`,
								   CONCAT(ROUND(COUNT(`Delay_Risk?`)/ (SELECT Total_Delays FROM delay_risk)* 100,2), "%")  AS Percent_of_DelayRisk,
                                   ROUND(AVG(CASE
											WHEN (`Delay_Risk?`)  = "Yes" THEN `Shipping_Time(Actual)` - `Shipping_Time(Expected)` 
										
									   END),0) AS Avg_Ship_Day_Delay
							FROM sales_log
                            LEFT JOIN product 
                            USING (Product_ID)
                            WHERE Geograpy_Key = (SELECT GeographyKey FROM geography WHERE State = 'Florida') AND `Delay_Risk?` = "Yes"
                            GROUP BY `Name`)
SELECT *
FROM Top_Delay_Risk_Prod
ORDER BY Percent_of_DelayRisk DESC
LIMIT 5;

-- Which months recorded growth or decline in Sales and Profit on a month-over-month basis, and how do monthly product returns correlate with those changes?
SELECT Month_Num,
	   CONCAT(ROUND((MOM_Diff_Sales)/1000000,2),"M") AS MOM_Diff_Sales,
       CONCAT(ROUND(Percent_MOM_Diff_Sales,2),"%") AS Percent_MOM_Diff_Sales,
       CONCAT(ROUND(Percent_MOM_Diff_Profit,2),"%")AS Percent_MOM_Diff_Profit,
       Monthly_Returns
FROM (
	SELECT 

		   MONTH(`Date`) AS Month_Num,
		   (sum(p.Selling_Price * s.`No._of_pieces_sold`) - lag(sum(p.Selling_Price * s.`No._of_pieces_sold`), 1, 0) over (ORDER BY MONTH(`Date`))) AS MOM_Diff_Sales,
		   ((sum(p.Selling_Price * s.`No._of_pieces_sold`) - lag(sum(p.Selling_Price * s.`No._of_pieces_sold`), 1, 0) over (ORDER BY MONTH(`Date`)))/
		   lag(sum(p.Selling_Price * s.`No._of_pieces_sold`), 1, 0) over (ORDER BY MONTH(`Date`))) * 100 AS Percent_MOM_Diff_Sales,
		   (((sum(p.Selling_Price * s.`No._of_pieces_sold`)  - sum(p.Manufac_Cost * s.`No._of_pieces_sold`)) - 
		   lag((sum(p.Selling_Price * s.`No._of_pieces_sold`)  - sum(p.Manufac_Cost * s.`No._of_pieces_sold`)), 1, 0) over (ORDER BY MONTH(`Date`)))/
		   lag((sum(p.Selling_Price * s.`No._of_pieces_sold`)  - sum(p.Manufac_Cost * s.`No._of_pieces_sold`)), 1, 0) over (ORDER BY MONTH(`Date`)))*100 AS Percent_MOM_Diff_Profit,
		   sum(`No._of_Pieces_Returned`) AS Monthly_Returns
	FROM sales_log AS s
	LEFT JOIN product AS p
	USING (Product_ID)
	WHERE Geograpy_Key = (SELECT GeographyKey FROM geography WHERE State = 'Florida') AND YEAR(`Date`) = 2023
	GROUP BY Month_Num
	ORDER BY MONTH(`Date`)) AS MOM;
    
-- What is the percentage distribution of delayed vs. on-time orders, and which delay status has the greatest impact on shipping performance?
WITH total_yes_risk as(SELECT COUNT(`Delay_Risk?`) AS Yes_count
					   FROM sales_log
                       WHERE Geograpy_Key = (SELECT GeographyKey FROM geography WHERE State = 'Florida') AND `Delay_Risk?` = "Yes"),
	 total_no_risk as(SELECT COUNT(`Delay_Risk?`) AS No_count
					   FROM sales_log
                       WHERE Geograpy_Key = (SELECT GeographyKey FROM geography WHERE State = 'Florida') AND `Delay_Risk?` = "No"),
	 Percent_Dist as (SELECT  COUNT(`Delay_Risk?`) Total_Count 
					  FROM sales_log
                      WHERE Geograpy_Key = (SELECT GeographyKey FROM geography WHERE State = 'Florida')
                      )
SELECT CONCAT(ROUND(((SELECT Yes_count FROM total_yes_risk)/ (SELECT Total_Count From Percent_Dist)) * 100,2), "%") AS Percent_Delay,
	   CONCAT(ROUND(((SELECT No_count FROM total_no_risk)/ (SELECT Total_Count From Percent_Dist)) * 100,2), "%") AS Percent_OnTime;

 
 # TIME SERIES SALES ANALYSIS
 
 -- How have clothing sales and Pieces returns shifted over time, and what do these trends reveal about buying behavior and product performance?
SELECT `Month`,
		CASE
			WHEN Total_Sales > 1000000000 THEN CONCAT(ROUND((Total_Sales/1000000000),2), "B")
            ELSE CONCAT(ROUND((Total_Sales/1000000),2), "M")
	   END AS Total_Sales,
       CASE
			WHEN Monthly_Returns > 1000000 THEN CONCAT(ROUND((Monthly_Returns/1000000),2), "M")
            ELSE CONCAT(ROUND((Monthly_Returns/1000),2), "K")
	   END AS Monthly_Returns
FROM
    (SELECT 
		   MONTHNAME(`Date`) AS `Month`,
		   SUM(p.Selling_Price * s.`No._of_pieces_sold`) AS Total_Sales,
		   SUM(`No._of_Pieces_Returned`) AS Monthly_Returns
	FROM sales_log AS s
	LEFT JOIN product AS p
	USING (Product_ID)
	GROUP BY `Month`) Sales_overTime;

-- What is the average monthly sales figure, and what does it reveal about demand patterns and revenue stability over time?
SELECT 
		   MONTHNAME(`Date`) AS `Month`,
		   ROUND(AVG(p.Selling_Price * s.`No._of_pieces_sold`),2) AS Avg_Sales
	FROM sales_log AS s
	LEFT JOIN product AS p
	USING (Product_ID)
	GROUP BY `Month`;

-- How do weekly sales vary within each month, and what insights do these trends revel
SELECT Day_of_week,
	CASE 
		WHEN Total_Sales > 1000000000 THEN CONCAT(ROUND(Total_Sales/1000000000,2),"B")
	ELSE CONCAT(ROUND(Total_Sales/1000000,2),"M") END AS Total_Sales
FROM(SELECT 
		DAYNAME(`Date`) AS Day_of_week,
		SUM(p.Selling_Price * s.`No._of_pieces_sold`) AS Total_Sales
		FROM sales_log AS s
		LEFT JOIN product AS p
		USING (Product_ID)
		WHERE Month(`Date`) = 4 AND YEAR(`Date`) = 2023
		GROUP BY Day_of_week
		ORDER BY Day_of_week) Weekly_sales;
         
-- What patterns exist in weekday versus weekend sales, and how can these insights inform business strategy and operational planning?
WITH Weekly_sales AS(
					  SELECT dayofweek(`Date`) AS Weekly,
							 SUM(p.Selling_Price * s.`No._of_pieces_sold`) AS Total_Sales
                      FROM sales_log AS s
					  LEFT JOIN product AS p
					  USING (Product_ID)
					  WHERE Month(`Date`) = 4 AND YEAR(`Date`) = 2023
                      GROUP BY Weekly),
	Week_day_end AS(SELECT 
						CASE WHEN Weekly > 1 AND Weekly < 7 THEN "Week Day"
                        ELSE  "Week End"
						END AS Week_Type,
                        SUM(Total_Sales) AS Total_Sales
					FROM Weekly_sales
                    GROUP BY Week_Type),
	Total_Weekly_Sales AS(SELECT SUM(Total_Sales) AS Weekly_Sales
						  FROM Week_day_end)
SELECT Week_Type,
	   CASE
			WHEN Total_Sales > 1000000000 THEN CONCAT(ROUND(Total_Sales/1000000000,2), "B") 
            ELSE CONCAT(ROUND(Total_Sales/1000000,2), "M") 
		END AS Total_Sales,
	   CONCAT(ROUND(CASE
						WHEN Week_Type = "Week End" THEN (Total_Sales / (SELECT Weekly_Sales FROM Total_Weekly_Sales))
						ELSE (Total_Sales / (SELECT Weekly_Sales FROM Total_Weekly_Sales))
						END * 100 ,2), "%") AS Percent_Weeks
FROM  Week_day_end
GROUP BY Week_Type
				

