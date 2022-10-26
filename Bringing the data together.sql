----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- STEP 0 - Load The DATABASE, inspect the datasets, and plan the objectives -----------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------


USE [Transactional Data test1]

SELECT TOP 10 * FROM Account_Lookup
SELECT TOP 10 * FROM Sellers_Lookup
SELECT TOP 10 * FROM Calendar_Lookup

SELECT * FROM Business_Targets
SELECT * FROM Opportunities_Wk25
SELECT * FROM Revenue_Wk25


-- Objective phase 1:
-- 1. See the performance of our Revenue over the months
-- 2. See the Partner fee and Registration fee over the months
-- 3. We want to compare Revenue VS Target
-- 4. Forecast until the end of the year
-- 5. Have a baseline
-- 6. Have a RunRate
-- 7. Be able to slice the data by all categories

-- Objective 2:
-- 1. See all opportunities in on view

-- Objective 3:
-- 1. Be able to track the opportunity changes Week on week (WoW)
-- 2. Have calculated fields on the WoW changes


----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- STEP 1 ----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM Revenue_Wk25

-- Renaming - 1
SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion, Revenue
FROM Revenue_Wk25



-- 2. Creating new columns
SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
--Revenue
FROM Revenue_Wk25



-- 3. Summarizing the Product category
--Check the number of Product Categories in Revenue and Target 
--SELECT DISTINCT Product_Category FROM Revenue_Wk25 -- 6 categories
--SELECT DISTINCT Service_Comp_Group FROM Business_Targets -- 3 categories
-- join them together:
SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
CASE
	WHEN Product_Category LIKE '%Service%' THEN 'Services'
	WHEN Product_Category LIKE '%Support%' THEN 'Support'
	WHEN Product_Category LIKE '%Product%' THEN 'Products'
	ELSE 'Need Mapping'
	END AS Product_Category_2,

IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
--Revenue
FROM Revenue_Wk25
-- 6 categories are still present, remove the original product category and sum the data based on the new product category
--24,803 rows




--4. Summing the data, remove the original product category and sum the data based on the new product category
SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
SUM(Revenue) AS Revenue,
SUM(Partner_Fee) AS Partner_Fee,
SUM(Registration_Fee) AS Registration_Fee
FROM
	(
	SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
	CASE
		WHEN Product_Category LIKE '%Service%' THEN 'Services'
		WHEN Product_Category LIKE '%Support%' THEN 'Support'
		WHEN Product_Category LIKE '%Product%' THEN 'Products'
		ELSE 'Need Mapping'
		END AS Product_Category_2,

	IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
	IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
	IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
	--Revenue
	FROM Revenue_Wk25
	) a
GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
-- 13,703 rows instead of 24,803 because the data was summed, aggregated together




----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- STEP 2 - Cleaning the opportunity Table ----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------


--1. Visualize
SELECT * FROM Opportunities_Wk25

--2. Create a Product Category table based on the type of product

SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
CASE
	WHEN Product LIKE '%Services:%' THEN 'Services'
	WHEN Product LIKE '%Support:%' THEN 'Support'
	WHEN Product LIKE '%Products:%' THEN 'Products'
	ELSE 'Need Mapping'
	END AS Product_Category,

Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage  FROM Opportunities_Wk25
WHERE Product IS NOT NULL AND Product <> 'NULL'


-- Check which product still need mapping
SELECT * FROM
(
SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
CASE
	WHEN Product LIKE '%Services:%' THEN 'Services'
	WHEN Product LIKE '%Support:%' THEN 'Support'
	WHEN Product LIKE '%Products:%' THEN 'Products'
	ELSE 'Need Mapping'
	END AS Product_Category,

Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
WHERE Product IS NOT NULL AND Product <> 'NULL'
) a
WHERE Product_Category = 'Need Mapping'

-- Those are actually also in the category Product but did not have a 's' at the end, so we add them to the list as shown below:
SELECT * FROM
(
SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
CASE
	WHEN Product LIKE '%Services:%' THEN 'Services'
	WHEN Product LIKE '%Support:%' THEN 'Support'
	WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
	ELSE 'Need Mapping'
	END AS Product_Category,

Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
WHERE Product IS NOT NULL AND Product <> 'NULL'
) a
WHERE Product_Category = 'Need Mapping'
-- Nothing shown so everything has been mapped for the new product category column



-- Joining the opportunity table with the calendar:

SELECT a.Account_no, Product_Category, b.Fiscal_Month,
SUM(CAST(REPLACE(Opportunity_Usage, ',','') AS FLOAT)) AS Opportunity_Usage
FROM

	(
	SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
	CASE
		WHEN Product LIKE '%Services:%' THEN 'Services'
		WHEN Product LIKE '%Support:%' THEN 'Support'
		WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
		ELSE 'Need Mapping'
		END AS Product_Category,

	Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
	WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' -- AND Project_Status <> 'Inactive'
	) a

	-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
	LEFT JOIN
	(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
	ON a.Opportunity_Est_Date = b.Date_Value

GROUP BY a.Account_no, Product_Category, b.Fiscal_Month

-- 8,296 rows vs 12,317 after aggreegation by account, product and month
-- By removing the Inactive opportunity we go down to 5,832 rows (opportunities)
--SELECT * FROM Calendar_Lookup





-- STEP 3: opportunity extrapolation: If an opportunity usage lands on May, we would like to determine how many months left it has before the end of the fiscal year by store and take that number and multiply it by the Opportunity_Usage
-- to get the total extrapolation per account, per product and per month.
-- Also, id the opportunity per usage is less than zero (negative), then the opportinity extrapolation is not calculated (=0) if not, the extrapolation is performed:

SELECT a.*,
IIF(Opportunity_Usage < 0, 0,Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
FROM
	(
	SELECT a.*, 

	CASE
		WHEN Fiscal_Month LIKE '%July%' THEN 11
		WHEN Fiscal_Month LIKE '%August%' THEN 10
		WHEN Fiscal_Month LIKE '%September%' THEN 9
		WHEN Fiscal_Month LIKE '%October%' THEN 8
		WHEN Fiscal_Month LIKE '%November%' THEN 7
		WHEN Fiscal_Month LIKE '%December%' THEN 6
		WHEN Fiscal_Month LIKE '%January%' THEN 5
		WHEN Fiscal_Month LIKE '%February%' THEN 4
		WHEN Fiscal_Month LIKE '%March%' THEN 3
		WHEN Fiscal_Month LIKE '%April%' THEN 2
		WHEN Fiscal_Month LIKE '%May%' THEN 1
		WHEN Fiscal_Month LIKE '%June%' THEN 0
		END AS Extrap_Month_Left_For_FY
	FROM
		(
		SELECT a.Account_no, Product_Category, b.Fiscal_Month,
		SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
		FROM

			(
			SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
			CASE
				WHEN Product LIKE '%Services:%' THEN 'Services'
				WHEN Product LIKE '%Support:%' THEN 'Support'
				WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
				ELSE 'Need Mapping'
				END AS Product_Category,

			Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
			WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
			) a

			-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
			LEFT JOIN
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
			ON a.Opportunity_Est_Date = b.Date_Value

		GROUP BY a.Account_no, Product_Category, b.Fiscal_Month
		) a
	)a




----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- STEP 3 - joining cleaned revenue with cleaned opportunity datasets----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

--If the accoutn number is from table a take it from a if not take it from table b
SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No,
ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
ISNULL(Revenue, 0) AS Revenue, 
ISNULL(Partner_Fee, 0) AS Partner_Fee, 
ISNULL(Registration_Fee, 0) AS Registration_Fee, -- add columns not in common in table revenue
ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
ISNULL(Opportunity_Extrapolation, 0) AS Opportunity_Extrapolation -- add columns not in common in table opportunity
FROM

-- Get the cleaned revenue table
	(
	SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Revenue, Partner_Fee, Registration_Fee
	FROM
		(
		SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
		SUM(Revenue) AS Revenue,
		SUM(Partner_Fee) AS Partner_Fee,
		SUM(Registration_Fee) AS Registration_Fee
		FROM
			(
			SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
			CASE
				WHEN Product_Category LIKE '%Service%' THEN 'Services'
				WHEN Product_Category LIKE '%Support%' THEN 'Support'
				WHEN Product_Category LIKE '%Product%' THEN 'Products'
				ELSE 'Need Mapping'
				END AS Product_Category_2,

			IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
			IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
			IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
			--Revenue
			FROM Revenue_Wk25
			) a
		GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
		-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
		) a 


	-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
		LEFT JOIN
		(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
		ON a.Fiscal_Month = b.Date_Value
	)a


FULL JOIN


-- Get the cleaned opportunity table:
(
	SELECT a.*,
	IIF(Opportunity_Usage < 0, 0,Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
	FROM
		(
		SELECT a.*, 

		CASE
			WHEN Fiscal_Month LIKE '%July%' THEN 11
			WHEN Fiscal_Month LIKE '%August%' THEN 10
			WHEN Fiscal_Month LIKE '%September%' THEN 9
			WHEN Fiscal_Month LIKE '%October%' THEN 8
			WHEN Fiscal_Month LIKE '%November%' THEN 7
			WHEN Fiscal_Month LIKE '%December%' THEN 6
			WHEN Fiscal_Month LIKE '%January%' THEN 5
			WHEN Fiscal_Month LIKE '%February%' THEN 4
			WHEN Fiscal_Month LIKE '%March%' THEN 3
			WHEN Fiscal_Month LIKE '%April%' THEN 2
			WHEN Fiscal_Month LIKE '%May%' THEN 1
			WHEN Fiscal_Month LIKE '%June%' THEN 0
			END AS Extrap_Month_Left_For_FY
		FROM
			(
			SELECT a.Account_no, Product_Category, b.Fiscal_Month,
			SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
			FROM

				(
				SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
				CASE
					WHEN Product LIKE '%Services:%' THEN 'Services'
					WHEN Product LIKE '%Support:%' THEN 'Support'
					WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category,

				Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
				WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
				) a

				-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
				LEFT JOIN
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
				ON a.Opportunity_Est_Date = b.Date_Value

			GROUP BY a.Account_no, Product_Category, b.Fiscal_Month
			) a
		)a
	) b
	ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
	-- In this case we join the two tables with the account number, the fiscal month as well as the product category to make sure there is no duplication


	----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- STEP 4 - Create a baseline ----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- We assume here that the baseline is based on the same revenue that the previous month. Other ideas can be used such as average of the last 3 or 6 months

-- Get the cleaned revenue table and rename the revenue as baseline

	(
	-- This is the baseline table
	SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
	FROM

		(
		SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
		FROM

			(
			SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
			SUM(Revenue) AS Revenue,
			SUM(Partner_Fee) AS Partner_Fee,
			SUM(Registration_Fee) AS Registration_Fee
			FROM

				(
				SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
				CASE
					WHEN Product_Category LIKE '%Service%' THEN 'Services'
					WHEN Product_Category LIKE '%Support%' THEN 'Support'
					WHEN Product_Category LIKE '%Product%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category_2,

				IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
				IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
				IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
				--Revenue
				FROM Revenue_Wk25
				) a
			GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
			-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
			) a 


			-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
			LEFT JOIN
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
			ON a.Fiscal_Month = b.Date_Value
	
		WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
		) a
	
		CROSS JOIN
		(
		SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
		(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
		(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
		) b

	)a
		----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- CLEAN THE TARGETS and JOIN the Baseline table with the Target table----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

SELECT * FROM Business_Targets

	(
	-- This is the Target table
	SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target]
	FROM

		(SELECT Store_Number AS Account_No, Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a --16,014 rows

		LEFT JOIN
		(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
		ON a.Fiscal_Month = b.Date_Value

	-- 16,014 rows
	)b
		----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- JOIN the Baseline table with the Target table----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------
SELECT ISNULL (a.Account_No, b.Account_No) AS Account_No, --use is not to take from table b if not in table a and vice versa
ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
ISNULL (a.Baseline, 0) AS Baseline,
ISNULL (b.[Target], 0) AS [Target]
FROM

	(
	-- This is the baseline table
	SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
	FROM

		(
		SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
		FROM

			(
			SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
			SUM(Revenue) AS Revenue,
			SUM(Partner_Fee) AS Partner_Fee,
			SUM(Registration_Fee) AS Registration_Fee
			FROM

				(
				SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
				CASE
					WHEN Product_Category LIKE '%Service%' THEN 'Services'
					WHEN Product_Category LIKE '%Support%' THEN 'Support'
					WHEN Product_Category LIKE '%Product%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category_2,

				IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
				IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
				IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
				--Revenue
				FROM Revenue_Wk25
				) a
			GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
			-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
			) a 


			-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
			LEFT JOIN
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
			ON a.Fiscal_Month = b.Date_Value
	
		WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
		) a
	
		CROSS JOIN
		(
		SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
		(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
		(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
		) b
	)a

-- We use a FULL JOIN because we want to keep everything from both tables a and b (baseline and target)
	FULL JOIN

	(
	-- This is the Target table
	SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target]
	FROM

		(SELECT Store_Number AS Account_No, Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a --16,014 rows

		LEFT JOIN
		(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
		ON a.Fiscal_Month = b.Date_Value

	-- 16,014 rows
	)b
	
	--Specify on which columns we want to join
	ON a.Account_no = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category

-- 19,924 rows


	----------------------------------------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------------------- Opportunities into RunRate (RR)----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Similarly with the baseline we are going to do the same for the opportunities
SELECT a.Account_no, a.Product_Category, b.Fiscal_Month, 
IIF (Opportunity_Usage < 0, 0, Opportunity_Usage) AS Opportunities_Into_RR
FROM
	(
	SELECT a.*, b.Fiscal_Month AS Future_Fiscal_Months, b.Month_ID + 1 AS Est_Month_Id
	FROM
		
			(-- This is the cleaned opportunities dataset
			SELECT a.*,
			IIF(Opportunity_Usage < 0, 0, Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
			FROM
				(
				SELECT a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID,
				SUM(a.Opportunity_Usage) AS Opportunity_Usage,

				CASE
					WHEN Fiscal_Month LIKE '%July%' THEN 11
					WHEN Fiscal_Month LIKE '%August%' THEN 10
					WHEN Fiscal_Month LIKE '%September%' THEN 9
					WHEN Fiscal_Month LIKE '%October%' THEN 8
					WHEN Fiscal_Month LIKE '%November%' THEN 7
					WHEN Fiscal_Month LIKE '%December%' THEN 6
					WHEN Fiscal_Month LIKE '%January%' THEN 5
					WHEN Fiscal_Month LIKE '%February%' THEN 4
					WHEN Fiscal_Month LIKE '%March%' THEN 3
					WHEN Fiscal_Month LIKE '%April%' THEN 2
					WHEN Fiscal_Month LIKE '%May%' THEN 1
					WHEN Fiscal_Month LIKE '%June%' THEN 0
					END AS Extrap_Month_Left_For_FY

				FROM
					(
					SELECT a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID,
					SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
					FROM

						(
						SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
						CASE
							WHEN Product LIKE '%Services:%' THEN 'Services'
							WHEN Product LIKE '%Support:%' THEN 'Support'
							WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
							ELSE 'Need Mapping'
							END AS Product_Category,

						Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
						WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
						) a

						-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
						LEFT JOIN
						(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
						ON a.Opportunity_Est_Date = b.Date_Value

					WHERE -- HERE we filter out the fiscal month that are only future fiscal month (After January 2019)
					a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND
					b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))

					GROUP BY a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID
					) a
				GROUP BY a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID
				)a
			) a

			CROSS JOIN
			(
			SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
			(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
			(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
			)b
	--9,505 rows
	WHERE a.Month_ID <= b.Month_ID
	)a
--5761 rows

	LEFT JOIN
	(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup) b
	ON a.Est_Month_Id = b.Month_ID

-- Now we want to filter out the fiscal month that are only future fiscal month. We don't care about past ones. We want to keep february march april may and June, which are before the end of the fiscal year (in July)
-- Two ways are possible, manually:
-- OPTION 1: WHERE IN ('','','','','') 
-- AUTOMATICALLY:
-- OPTION 2: 
-- WHERE
-- a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)
-- We can also filter the Fiscal_Year by adding it (after the LEFT JOIN) from the Calendar_Lookup and add the filter query WHERE clause to have only the opportunities for the coming months of the CURRENT Fiscal year (2019)

-- 1,901 rows of opportunities for the futur months of the current fiscal year (2019)

-- We need now to do the cross join between the futur fical months on this opportunities, similarly to the cross join we made for the baseline
-- We also need to add a WHERE clause WHERE a.Month_ID <= b.Month_ID that only takes the future months from table b  that are bigger than table a in the fiscal months. For this the month ID is used

-- Now we need to exclude the current month considered as it is already captured in the Opportunity Usage, and don't need to be added into the extrapolation of future fiscal months of this FY. As a result we need only to take it from the Month ID +1 (Est_Month_Id)
-- This can be done by left join the calendar again and get the actual fiscal month that corresponds into the Est_Month_Id, then rename the opportunity usage 

-- Finally, if we have a negative opportunity we do not want to recure in the following months in the run rate, as it will be already captured in the opportunity usage.
-- To do this we can add an IF condition at the top while selecting the table to exclude those values into the table

-- In the end we have for each account, and for the category of product indicated, has a "x" opportunity into run rate that started in the earlier month indicated and it will recure in each of this month 




	----------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------STEP 7 - Full join between (Baseline+Target) and (Opportunities Into Run Rate)----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Full join between (Baseline+Target) and (Opportunities Into Run Rate)

SELECT ISNULL (a.Account_No, b.Account_No) AS Account_No, --use is not to take from table b if not in table a and vice versa
ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
ISNULL (a.Baseline, 0) AS Baseline,
ISNULL (a.[Target], 0) AS [Target],
ISNULL (b.Opportunities_Into_RR, 0) AS Opportunities_Into_RR
FROM

	(
	SELECT ISNULL (a.Account_No, b.Account_No) AS Account_No, --use is not to take from table b if not in table a and vice versa
	ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
	ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
	ISNULL (a.Baseline, 0) AS Baseline,
	ISNULL (b.[Target], 0) AS [Target]
	FROM

		(--This is the baseline+Target full join table
		-- This is the baseline table
		SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
		FROM

			(
			SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
			FROM

				(
				SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
				SUM(Revenue) AS Revenue,
				SUM(Partner_Fee) AS Partner_Fee,
				SUM(Registration_Fee) AS Registration_Fee
				FROM

					(
					SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
					CASE
						WHEN Product_Category LIKE '%Service%' THEN 'Services'
						WHEN Product_Category LIKE '%Support%' THEN 'Support'
						WHEN Product_Category LIKE '%Product%' THEN 'Products'
						ELSE 'Need Mapping'
						END AS Product_Category_2,

					IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
					IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
					IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
					--Revenue
					FROM Revenue_Wk25
					) a
				GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
				-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
				) a 


				-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
				LEFT JOIN
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
				ON a.Fiscal_Month = b.Date_Value
	
			WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
			) a
	
			CROSS JOIN
			(
			SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
			(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
			(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
			) b
		)a

	-- We use a FULL JOIN because we want to keep everything from both tables a and b (baseline and target)
		FULL JOIN

		(
		-- This is the Target table
		SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target]
		FROM

			(SELECT Store_Number AS Account_No, Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a --16,014 rows

			LEFT JOIN
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
			ON a.Fiscal_Month = b.Date_Value

		-- 16,014 rows
		)b
	
		--Specify on which columns we want to join
		ON a.Account_no = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
	)a




	----------------------------
	FULL JOIN

	(--THIS IS MILESTONES IN RR
	SELECT a.Account_no, a.Product_Category, b.Fiscal_Month, 
	IIF (Opportunity_Usage < 0, 0, Opportunity_Usage) AS Opportunities_Into_RR
	FROM
		(
		SELECT a.*, b.Fiscal_Month AS Future_Fiscal_Months, b.Month_ID + 1 AS Est_Month_Id
		FROM
		
				(-- This is the cleaned opportunities dataset
				SELECT a.*,
				IIF(Opportunity_Usage < 0, 0, Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
				FROM
					(
					SELECT a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID,
					SUM(a.Opportunity_Usage) AS Opportunity_Usage,

					CASE
						WHEN Fiscal_Month LIKE '%July%' THEN 11
						WHEN Fiscal_Month LIKE '%August%' THEN 10
						WHEN Fiscal_Month LIKE '%September%' THEN 9
						WHEN Fiscal_Month LIKE '%October%' THEN 8
						WHEN Fiscal_Month LIKE '%November%' THEN 7
						WHEN Fiscal_Month LIKE '%December%' THEN 6
						WHEN Fiscal_Month LIKE '%January%' THEN 5
						WHEN Fiscal_Month LIKE '%February%' THEN 4
						WHEN Fiscal_Month LIKE '%March%' THEN 3
						WHEN Fiscal_Month LIKE '%April%' THEN 2
						WHEN Fiscal_Month LIKE '%May%' THEN 1
						WHEN Fiscal_Month LIKE '%June%' THEN 0
						END AS Extrap_Month_Left_For_FY

					FROM
						(
						SELECT a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID,
						SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
						FROM

							(
							SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
							CASE
								WHEN Product LIKE '%Services:%' THEN 'Services'
								WHEN Product LIKE '%Support:%' THEN 'Support'
								WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
								ELSE 'Need Mapping'
								END AS Product_Category,

							Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
							WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
							) a

							-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
							LEFT JOIN
							(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
							ON a.Opportunity_Est_Date = b.Date_Value

						WHERE -- HERE we filter out the fiscal month that are only future fiscal month (After January 2019)
						a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND
						b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))

						GROUP BY a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID
						) a
					GROUP BY a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID
					)a
				) a

				CROSS JOIN
				(
				SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
				(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
				(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
				)b
		--9,505 rows
		WHERE a.Month_ID <= b.Month_ID
		)a
	--5761 rows

		LEFT JOIN
		(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup) b
		ON a.Est_Month_Id = b.Month_ID
	)b
	ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category



----------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------STEP 8 - JOIN all transactional data together ----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- 1. Revenue + Opportunities Full Join
--FULL JOIN--
-- 2. Baseline + Targets Full Join with Opportunities into RunRate table

SELECT 
ISNULL(a.Account_No, b.Account_No) AS Account_No, --If the accoutn number is from table a take it from a if not take it from table b
ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
ISNULL(a.Revenue, 0) AS Revenue, 
ISNULL(a.Partner_Fee, 0) AS Partner_Fee, 
ISNULL(a.Registration_Fee, 0) AS Registration_Fee, -- add columns not in common in table revenue
ISNULL(a.Opportunity_Usage, 0) AS Opportunity_Usage, 
ISNULL(a.Opportunity_Extrapolation, 0) AS Opportunity_Extrapolation, -- add columns not in common in table opportunity

ISNULL (b.Baseline, 0) AS Baseline,
ISNULL (b.[Target], 0) AS [Target],
ISNULL (b.Opportunities_Into_RR, 0) AS Opportunities_Into_RR

FROM
	( -- This is the REVENUE+OPPORTUNITIES
	SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No, --If the accoutn number is from table a take it from a if not take it from table b
	ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
	ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
	ISNULL(Revenue, 0) AS Revenue, 
	ISNULL(Partner_Fee, 0) AS Partner_Fee, 
	ISNULL(Registration_Fee, 0) AS Registration_Fee, -- add columns not in common in table revenue
	ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
	ISNULL(Opportunity_Extrapolation, 0) AS Opportunity_Extrapolation -- add columns not in common in table opportunity
	FROM

	-- Get the cleaned revenue table
		(
		SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Revenue, Partner_Fee, Registration_Fee
		FROM
			(
			SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
			SUM(Revenue) AS Revenue,
			SUM(Partner_Fee) AS Partner_Fee,
			SUM(Registration_Fee) AS Registration_Fee
			FROM
				(
				SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
				CASE
					WHEN Product_Category LIKE '%Service%' THEN 'Services'
					WHEN Product_Category LIKE '%Support%' THEN 'Support'
					WHEN Product_Category LIKE '%Product%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category_2,

				IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
				IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
				IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
				--Revenue
				FROM Revenue_Wk25
				) a
			GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
			-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
			) a 


		-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
			LEFT JOIN
			(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
			ON a.Fiscal_Month = b.Date_Value
		)a


	FULL JOIN


	-- Get the cleaned opportunity table:
		(
			SELECT a.*,
			IIF(Opportunity_Usage < 0, 0,Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
			FROM
				(
				SELECT a.Account_no, a.Product_Category, a.Fiscal_Month,
				SUM(Opportunity_Usage) AS Opportunity_Usage,

				CASE
					WHEN Fiscal_Month LIKE '%July%' THEN 11
					WHEN Fiscal_Month LIKE '%August%' THEN 10
					WHEN Fiscal_Month LIKE '%September%' THEN 9
					WHEN Fiscal_Month LIKE '%October%' THEN 8
					WHEN Fiscal_Month LIKE '%November%' THEN 7
					WHEN Fiscal_Month LIKE '%December%' THEN 6
					WHEN Fiscal_Month LIKE '%January%' THEN 5
					WHEN Fiscal_Month LIKE '%February%' THEN 4
					WHEN Fiscal_Month LIKE '%March%' THEN 3
					WHEN Fiscal_Month LIKE '%April%' THEN 2
					WHEN Fiscal_Month LIKE '%May%' THEN 1
					WHEN Fiscal_Month LIKE '%June%' THEN 0
					END AS Extrap_Month_Left_For_FY
				FROM
					(
					SELECT a.Account_no, Product_Category, b.Fiscal_Month,
					SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
					FROM

						(
						SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
						CASE
							WHEN Product LIKE '%Services:%' THEN 'Services'
							WHEN Product LIKE '%Support:%' THEN 'Support'
							WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
							ELSE 'Need Mapping'
							END AS Product_Category,

						Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
						WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
						) a

						-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
						LEFT JOIN
						(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
						ON a.Opportunity_Est_Date = b.Date_Value

					GROUP BY a.Account_no, Product_Category, b.Fiscal_Month
					) a
				GROUP BY a.Account_no, a.Product_Category, a.Fiscal_Month
				)a
			) b
			ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
			-- In this case we join the two tables with the account number, the fiscal month as well as the product category to make sure there is no duplication
		)a

	
		-----------------------------------
		FULL JOIN 

		(--THIS IS (Baseline + Targets) table Full Join with Opportunities into RunRate table
		SELECT ISNULL (a.Account_No, b.Account_No) AS Account_No, --use is not to take from table b if not in table a and vice versa
		ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
		ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
		ISNULL (a.Baseline, 0) AS Baseline,
		ISNULL (a.[Target], 0) AS [Target],
		ISNULL (b.Opportunities_Into_RR, 0) AS Opportunities_Into_RR
		FROM

			(
			SELECT ISNULL (a.Account_No, b.Account_No) AS Account_No, --use is not to take from table b if not in table a and vice versa
			ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
			ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
			ISNULL (a.Baseline, 0) AS Baseline,
			ISNULL (b.[Target], 0) AS [Target]
			FROM

				(--This is the baseline+Target full join table
				-- This is the baseline table
				SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
				FROM

					(
					SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
					FROM

						(
						SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
						SUM(Revenue) AS Revenue,
						SUM(Partner_Fee) AS Partner_Fee,
						SUM(Registration_Fee) AS Registration_Fee
						FROM

							(
							SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
							CASE
								WHEN Product_Category LIKE '%Service%' THEN 'Services'
								WHEN Product_Category LIKE '%Support%' THEN 'Support'
								WHEN Product_Category LIKE '%Product%' THEN 'Products'
								ELSE 'Need Mapping'
								END AS Product_Category_2,

							IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
							IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
							IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
							--Revenue
							FROM Revenue_Wk25
							) a
						GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
						-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
						) a 


						-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
						LEFT JOIN
						(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
						ON a.Fiscal_Month = b.Date_Value
	
					WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
					) a
	
					CROSS JOIN
					(
					SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
					(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
					(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
					) b
				)a

			-- We use a FULL JOIN because we want to keep everything from both tables a and b (baseline and target)
				FULL JOIN

				(
				-- This is the Target table
				SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target]
				FROM

					(SELECT Store_Number AS Account_No, Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a --16,014 rows

					LEFT JOIN
					(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
					ON a.Fiscal_Month = b.Date_Value

				-- 16,014 rows
				)b
	
				--Specify on which columns we want to join
				ON a.Account_no = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
			)a




			----------------------------
			FULL JOIN

			(--THIS IS MILESTONES IN RR
			SELECT a.Account_no, a.Product_Category, b.Fiscal_Month, 
			IIF (Opportunity_Usage < 0, 0, Opportunity_Usage) AS Opportunities_Into_RR
			FROM
				(
				SELECT a.*, b.Fiscal_Month AS Future_Fiscal_Months, b.Month_ID + 1 AS Est_Month_Id
				FROM
		
						(-- This is the cleaned opportunities dataset
						SELECT a.*,
						IIF(Opportunity_Usage < 0, 0, Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
						FROM
							(
							SELECT a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID,
							SUM(a.Opportunity_Usage) AS Opportunity_Usage,

							CASE
								WHEN Fiscal_Month LIKE '%July%' THEN 11
								WHEN Fiscal_Month LIKE '%August%' THEN 10
								WHEN Fiscal_Month LIKE '%September%' THEN 9
								WHEN Fiscal_Month LIKE '%October%' THEN 8
								WHEN Fiscal_Month LIKE '%November%' THEN 7
								WHEN Fiscal_Month LIKE '%December%' THEN 6
								WHEN Fiscal_Month LIKE '%January%' THEN 5
								WHEN Fiscal_Month LIKE '%February%' THEN 4
								WHEN Fiscal_Month LIKE '%March%' THEN 3
								WHEN Fiscal_Month LIKE '%April%' THEN 2
								WHEN Fiscal_Month LIKE '%May%' THEN 1
								WHEN Fiscal_Month LIKE '%June%' THEN 0
								END AS Extrap_Month_Left_For_FY

							FROM
								(
								SELECT a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID,
								SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
								FROM

									(
									SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
									CASE
										WHEN Product LIKE '%Services:%' THEN 'Services'
										WHEN Product LIKE '%Support:%' THEN 'Support'
										WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
										ELSE 'Need Mapping'
										END AS Product_Category,

									Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
									WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
									) a

									-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
									LEFT JOIN
									(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
									ON a.Opportunity_Est_Date = b.Date_Value

								WHERE -- HERE we filter out the fiscal month that are only future fiscal month (After January 2019)
								a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND
								b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))

								GROUP BY a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID
								) a
							GROUP BY a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID
							)a
						) a

						CROSS JOIN
						(
						SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
						(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
						(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
						)b
				--9,505 rows
				WHERE a.Month_ID <= b.Month_ID
				)a
			--5761 rows

				LEFT JOIN
				(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup) b
				ON a.Est_Month_Id = b.Month_ID
			)b
			ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
		)b
		ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category






		-----------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------STEP 9 - JOIN Transactional Data to Lookups data ----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

--Create a view to run the query
CREATE VIEW ipi_data_Revenue_Summary AS

-- 1. Transactional data
--FULL JOIN--
-- 2. Lookups data

SELECT 
final.*,
b.Fiscal_Quarter, b.Fiscal_Year, b.Month_ID,
c.Account_Name, c.Industry, c.Vertical, c.Segment, c.Store_Manager_Alias, c.Potential_Account, c.Vertical_Manager_Alias,
d.General_Seller, d.Services_Seller, d.Product_Seller, d.Support_Seller
FROM

	(-- This is all the transactional data
	SELECT 
	ISNULL(a.Account_No, b.Account_No) AS Account_No, --If the accoutn number is from table a take it from a if not take it from table b
	ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
	ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
	ISNULL(a.Revenue, 0) AS Revenue, 
	ISNULL(a.Partner_Fee, 0) AS Partner_Fee, 
	ISNULL(a.Registration_Fee, 0) AS Registration_Fee, -- add columns not in common in table revenue
	ISNULL(a.Opportunity_Usage, 0) AS Opportunity_Usage, 
	ISNULL(a.Opportunity_Extrapolation, 0) AS Opportunity_Extrapolation, -- add columns not in common in table opportunity

	ISNULL (b.Baseline, 0) AS Baseline,
	ISNULL (b.[Target], 0) AS [Target],
	ISNULL (b.Opportunities_Into_RR, 0) AS Opportunities_Into_RR

	FROM
		( -- This is the REVENUE+OPPORTUNITIES
		SELECT ISNULL(a.Account_No, b.Account_No) AS Account_No, --If the accoutn number is from table a take it from a if not take it from table b
		ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
		ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
		ISNULL(Revenue, 0) AS Revenue, 
		ISNULL(Partner_Fee, 0) AS Partner_Fee, 
		ISNULL(Registration_Fee, 0) AS Registration_Fee, -- add columns not in common in table revenue
		ISNULL(Opportunity_Usage, 0) AS Opportunity_Usage, 
		ISNULL(Opportunity_Extrapolation, 0) AS Opportunity_Extrapolation -- add columns not in common in table opportunity
		FROM

		-- Get the cleaned revenue table
			(
			SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Revenue, Partner_Fee, Registration_Fee
			FROM
				(
				SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
				SUM(Revenue) AS Revenue,
				SUM(Partner_Fee) AS Partner_Fee,
				SUM(Registration_Fee) AS Registration_Fee
				FROM
					(
					SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
					CASE
						WHEN Product_Category LIKE '%Service%' THEN 'Services'
						WHEN Product_Category LIKE '%Support%' THEN 'Support'
						WHEN Product_Category LIKE '%Product%' THEN 'Products'
						ELSE 'Need Mapping'
						END AS Product_Category_2,

					IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
					IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
					IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
					--Revenue
					FROM Revenue_Wk25
					) a
				GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
				-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
				) a 


			-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
				LEFT JOIN
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
				ON a.Fiscal_Month = b.Date_Value
			)a


		FULL JOIN


		-- Get the cleaned opportunity table:
			(
				SELECT a.*,
				IIF(Opportunity_Usage < 0, 0,Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
				FROM
					(
					SELECT a.Account_no, a.Product_Category, a.Fiscal_Month,
					SUM(Opportunity_Usage) AS Opportunity_Usage,

					CASE
						WHEN Fiscal_Month LIKE '%July%' THEN 11
						WHEN Fiscal_Month LIKE '%August%' THEN 10
						WHEN Fiscal_Month LIKE '%September%' THEN 9
						WHEN Fiscal_Month LIKE '%October%' THEN 8
						WHEN Fiscal_Month LIKE '%November%' THEN 7
						WHEN Fiscal_Month LIKE '%December%' THEN 6
						WHEN Fiscal_Month LIKE '%January%' THEN 5
						WHEN Fiscal_Month LIKE '%February%' THEN 4
						WHEN Fiscal_Month LIKE '%March%' THEN 3
						WHEN Fiscal_Month LIKE '%April%' THEN 2
						WHEN Fiscal_Month LIKE '%May%' THEN 1
						WHEN Fiscal_Month LIKE '%June%' THEN 0
						END AS Extrap_Month_Left_For_FY
					FROM
						(
						SELECT a.Account_no, Product_Category, b.Fiscal_Month,
						SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
						FROM

							(
							SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
							CASE
								WHEN Product LIKE '%Services:%' THEN 'Services'
								WHEN Product LIKE '%Support:%' THEN 'Support'
								WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
								ELSE 'Need Mapping'
								END AS Product_Category,

							Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
							WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
							) a

							-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
							LEFT JOIN
							(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
							ON a.Opportunity_Est_Date = b.Date_Value

						GROUP BY a.Account_no, Product_Category, b.Fiscal_Month
						) a
					GROUP BY a.Account_no, a.Product_Category, a.Fiscal_Month
					)a
				) b
				ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
				-- In this case we join the two tables with the account number, the fiscal month as well as the product category to make sure there is no duplication
			)a

	
			-----------------------------------
			FULL JOIN 

			(--THIS IS (Baseline + Targets) table Full Join with Opportunities into RunRate table
			SELECT ISNULL (a.Account_No, b.Account_No) AS Account_No, --use is not to take from table b if not in table a and vice versa
			ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
			ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
			ISNULL (a.Baseline, 0) AS Baseline,
			ISNULL (a.[Target], 0) AS [Target],
			ISNULL (b.Opportunities_Into_RR, 0) AS Opportunities_Into_RR
			FROM

				(
				SELECT ISNULL (a.Account_No, b.Account_No) AS Account_No, --use is not to take from table b if not in table a and vice versa
				ISNULL (a.Fiscal_Month, b.Fiscal_Month) AS Fiscal_Month,
				ISNULL (a.Product_Category, b.Product_Category) AS Product_Category,
				ISNULL (a.Baseline, 0) AS Baseline,
				ISNULL (b.[Target], 0) AS [Target]
				FROM

					(--This is the baseline+Target full join table
					-- This is the baseline table
					SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, a.Baseline
					FROM

						(
						SELECT a.Account_No, b.Fiscal_Month, a.Product_Category, Partner_Fee+Revenue AS Baseline
						FROM

							(
							SELECT Account_No, Fiscal_Month, Product_Category_2 AS Product_Category, 
							SUM(Revenue) AS Revenue,
							SUM(Partner_Fee) AS Partner_Fee,
							SUM(Registration_Fee) AS Registration_Fee
							FROM

								(
								SELECT StoreNo AS Account_No, [Month] AS Fiscal_Month, Revenue_Type, Revenue_Motion, Product_Category, Motion AS Account_Motion,
								CASE
									WHEN Product_Category LIKE '%Service%' THEN 'Services'
									WHEN Product_Category LIKE '%Support%' THEN 'Support'
									WHEN Product_Category LIKE '%Product%' THEN 'Products'
									ELSE 'Need Mapping'
									END AS Product_Category_2,

								IIF (Revenue_Type = 'Actuals', Revenue, 0) AS Revenue, --If the value in the column Revenue Type is equal to Actuals, the value of the revenu fee is transfered into a new Revenue column
								IIF (Revenue_Type = 'Partner Fee', Revenue, 0) AS Partner_Fee,
								IIF (Revenue_Type = 'Registration Fee', Revenue, 0) AS Registration_Fee
								--Revenue
								FROM Revenue_Wk25
								) a
							GROUP BY Account_No, Fiscal_Month, Product_Category_2 -- use the old name of Product_Category_2
							-- 13,703 rows instead of 24,803 because the data was summed, aggregated together
							) a 


							-- Account_no, Fiscal_Month, Product_Category are the three columns two join together in both tables. However the fiscal month in each table is written in a different way and must be changed.
							LEFT JOIN
							(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
							ON a.Fiscal_Month = b.Date_Value
	
						WHERE b.Fiscal_Month = (SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
						) a
	
						CROSS JOIN
						(
						SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
						(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
						(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
						) b
					)a

				-- We use a FULL JOIN because we want to keep everything from both tables a and b (baseline and target)
					FULL JOIN

					(
					-- This is the Target table
					SELECT a.Account_No, a.Product_Category, b.Fiscal_Month, a.[Target]
					FROM

						(SELECT Store_Number AS Account_No, Product_Category, Fiscal_Month, [Target] FROM Business_Targets) a --16,014 rows

						LEFT JOIN
						(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
						ON a.Fiscal_Month = b.Date_Value

					-- 16,014 rows
					)b
	
					--Specify on which columns we want to join
					ON a.Account_no = b.Account_No AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
				)a




				----------------------------
				FULL JOIN

				(--THIS IS MILESTONES IN RR
				SELECT a.Account_no, a.Product_Category, b.Fiscal_Month, 
				IIF (Opportunity_Usage < 0, 0, Opportunity_Usage) AS Opportunities_Into_RR
				FROM
					(
					SELECT a.*, b.Fiscal_Month AS Future_Fiscal_Months, b.Month_ID + 1 AS Est_Month_Id
					FROM
		
							(-- This is the cleaned opportunities dataset
							SELECT a.*,
							IIF(Opportunity_Usage < 0, 0, Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
							FROM
								(
								SELECT a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID,
								SUM(a.Opportunity_Usage) AS Opportunity_Usage,

								CASE
									WHEN Fiscal_Month LIKE '%July%' THEN 11
									WHEN Fiscal_Month LIKE '%August%' THEN 10
									WHEN Fiscal_Month LIKE '%September%' THEN 9
									WHEN Fiscal_Month LIKE '%October%' THEN 8
									WHEN Fiscal_Month LIKE '%November%' THEN 7
									WHEN Fiscal_Month LIKE '%December%' THEN 6
									WHEN Fiscal_Month LIKE '%January%' THEN 5
									WHEN Fiscal_Month LIKE '%February%' THEN 4
									WHEN Fiscal_Month LIKE '%March%' THEN 3
									WHEN Fiscal_Month LIKE '%April%' THEN 2
									WHEN Fiscal_Month LIKE '%May%' THEN 1
									WHEN Fiscal_Month LIKE '%June%' THEN 0
									END AS Extrap_Month_Left_For_FY

								FROM
									(
									SELECT a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID,
									SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
									FROM

										(
										SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
										CASE
											WHEN Product LIKE '%Services:%' THEN 'Services'
											WHEN Product LIKE '%Support:%' THEN 'Support'
											WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
											ELSE 'Need Mapping'
											END AS Product_Category,

										Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
										WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL' AND Project_Status <> 'Inactive'
										) a

										-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
										LEFT JOIN
										(SELECT DISTINCT Date_Value, Fiscal_Month, Fiscal_Year, Month_ID FROM Calendar_Lookup) b
										ON a.Opportunity_Est_Date = b.Date_Value

									WHERE -- HERE we filter out the fiscal month that are only future fiscal month (After January 2019)
									a.Opportunity_Est_Date > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND
									b.Fiscal_Year = (SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))

									GROUP BY a.Account_no, Product_Category, b.Fiscal_Month, b.Month_ID
									) a
								GROUP BY a.Account_no, a.Product_Category, a.Fiscal_Month, a.Month_ID
								)a
							) a

							CROSS JOIN
							(
							SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup WHERE Date_Value > (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0) AND Fiscal_Year = 
							(SELECT DISTINCT Fiscal_Year FROM Calendar_Lookup WHERE Date_Value = (SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0)) AND Fiscal_Month <>
							(SELECT DISTINCT Fiscal_Month FROM Calendar_Lookup WHERE Date_Value =(SELECT MAX([Month]) FROM Revenue_Wk25 WHERE Revenue <> 0))
							)b
					--9,505 rows
					WHERE a.Month_ID <= b.Month_ID
					)a
				--5761 rows

					LEFT JOIN
					(SELECT DISTINCT Fiscal_Month, Month_ID FROM Calendar_Lookup) b
					ON a.Est_Month_Id = b.Month_ID
				)b
				ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
			)b
			ON a.Account_No = b.Account_no AND a.Fiscal_Month = b.Fiscal_Month AND a.Product_Category = b.Product_Category
	) final

-- 29,753 rows for final table

-----------------------------------------------------------
LEFT JOIN
(--This is the calendar
SELECT DISTINCT Fiscal_Month, Fiscal_Quarter, Fiscal_Year, Month_ID -- A month has many days therefore we select only the dinstinct values to avoid massive duplications
FROM Calendar_Lookup
)b
ON final.Fiscal_Month = b.Fiscal_Month 


LEFT JOIN
(-- This is the Account Lookup
SELECT AccountNo, Store AS Account_Name, Industry, Vertical, Segment, Store_Manager_Alias, Potential_Account, Vertical_Manager_Alias
FROM Account_Lookup
)c
ON final.Account_No = c.AccountNo


LEFT JOIN
(-- This is the Sellers Lookup
SELECT Store_ID, General_Seller, Services_Seller, Product_Seller, Support_Seller
FROM Sellers_Lookup
)d
ON final.Account_No = d.Store_ID 

-- 29,753 rows which is similar to the final table before the LEFT JOIN : OKAY

-- Run the query to run the query
SELECT * FROM ipi_data_Revenue_Summary




----------------------------------------------------------------------------------------------------------------------------------------------------------------------
---------------------------------------------------------STEP 10 - Create the opportunity view ----------------------------------------------------------------------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------------------------------

-- Create a query view
CREATE VIEW ipi_data_Opportunity_Summary AS



--STEP 1: COPY and PASTE the basic query from before and add the additional fields
SELECT a.*, 
-- Create some ranges for people to easily filter out great opportunities:
CASE
	WHEN Opportunity_Usage < 0 THEN 'Below $0'
	WHEN Opportunity_Usage BETWEEN 0 AND 10000 THEN '$0 to $10,000'
	WHEN Opportunity_Usage BETWEEN 10000 AND 50000 THEN '$10000 to $50,000'
	WHEN Opportunity_Usage BETWEEN 50000 AND 100000 THEN '$50000 to $100,000'
	WHEN Opportunity_Usage BETWEEN 100000 AND 200000 THEN '$100,000 to $200,000'
	ELSE '$200,000 +'
	END AS Opportunity_Usage_Range, 

CASE
	WHEN Opportunity_Extrapolation < 0 THEN 'Below $0'
	WHEN Opportunity_Extrapolation BETWEEN 0 AND 10000 THEN '$0 to $10,000'
	WHEN Opportunity_Extrapolation BETWEEN 10000 AND 50000 THEN '$10000 to $50,000'
	WHEN Opportunity_Extrapolation BETWEEN 50000 AND 100000 THEN '$50000 to $100,000'
	WHEN Opportunity_Extrapolation BETWEEN 100000 AND 200000 THEN '$100,000 to $200,000'
	ELSE '$200,000 +'
	END AS Opportunity_Extrapolation_Range, 

Fiscal_Quarter, Fiscal_Year, Month_ID
Account_Name, Industry, Vertical, Segment, Store_Manager_Alias, Potential_Account, Vertical_Manager_Alias
General_Seller, Services_Seller, Product_Seller, Support_Seller
FROM

	(--THIS IS THE OPPORTUNITY DATASET
	SELECT a.*,
	IIF(Opportunity_Usage < 0, 0,Extrap_Month_Left_For_FY * Opportunity_Usage) AS Opportunity_Extrapolation
	FROM
		(
		SELECT a.Account_no, a.Product_Category, a.Fiscal_Month, Product, Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage,
		SUM(Opportunity_Usage) AS Opportunity_Usage,

		CASE
			WHEN Fiscal_Month LIKE '%July%' THEN 12 -- Now the number reflect the whole vaule of the opportunity
			WHEN Fiscal_Month LIKE '%August%' THEN 11
			WHEN Fiscal_Month LIKE '%September%' THEN 10
			WHEN Fiscal_Month LIKE '%October%' THEN 9
			WHEN Fiscal_Month LIKE '%November%' THEN 8
			WHEN Fiscal_Month LIKE '%December%' THEN 7
			WHEN Fiscal_Month LIKE '%January%' THEN 6
			WHEN Fiscal_Month LIKE '%February%' THEN 5
			WHEN Fiscal_Month LIKE '%March%' THEN 4
			WHEN Fiscal_Month LIKE '%April%' THEN 3
			WHEN Fiscal_Month LIKE '%May%' THEN 2
			WHEN Fiscal_Month LIKE '%June%' THEN 1
			END AS Extrap_Month_Left_For_FY
		FROM
			(
			SELECT a.Account_no, Product_Category, b.Fiscal_Month, Product, Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage,
			SUM(CAST(REPLACE(Opportunity_Usage, ',', '') AS FLOAT)) AS Opportunity_Usage
			FROM

				(
				SELECT Store_No AS Account_no, Opportunity_Est_Date, Product, 
				CASE
					WHEN Product LIKE '%Services:%' THEN 'Services'
					WHEN Product LIKE '%Support:%' THEN 'Support'
					WHEN Product LIKE '%Products:%' OR Product LIKE '%Product:%' THEN 'Products'
					ELSE 'Need Mapping'
					END AS Product_Category,

				Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage, Opportunity_Usage FROM Opportunities_Wk25
				WHERE Product IS NOT NULL AND Product <> 'NULL' AND Opportunity_Usage <> 'NULL'
				) a

				-- here we need the date value and the fiscal month to be merged with the estimated date from the other table. The fiscal year and quarter can be joined at the end of the query in case we work with big data to keep the table small
				LEFT JOIN
				(SELECT DISTINCT Date_Value, Fiscal_Month FROM Calendar_Lookup) b
				ON a.Opportunity_Est_Date = b.Date_Value

			GROUP BY a.Account_no, Product_Category, b.Fiscal_Month, Product, Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage
			) a
		GROUP BY a.Account_no, a.Product_Category, a.Fiscal_Month, Product, Opportunity_ID, Opportunity_Name, Project_Status, Opportunity_Status, Opportunity_Stage
		) a
	) a

LEFT JOIN
(--This is the calendar
SELECT DISTINCT Fiscal_Month, Fiscal_Quarter, Fiscal_Year, Month_ID -- A month has many days therefore we select only the dinstinct values to avoid massive duplications
FROM Calendar_Lookup
)b
ON a.Fiscal_Month = b.Fiscal_Month 


LEFT JOIN
(-- This is the Account Lookup
SELECT AccountNo, Store AS Account_Name, Industry, Vertical, Segment, Store_Manager_Alias, Potential_Account, Vertical_Manager_Alias
FROM Account_Lookup
)c
ON a.Account_No = c.AccountNo


LEFT JOIN
(-- This is the Sellers Lookup
SELECT Store_ID, General_Seller, Services_Seller, Product_Seller, Support_Seller
FROM Sellers_Lookup
)d
ON a.Account_No = d.Store_ID 

	-- SELECT * FROM Opportunities_Wk25

SELECT * FROM ipi_data_Opportunity_Summary