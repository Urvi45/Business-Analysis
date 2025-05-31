CREATE DATABASE Business_Analysis;

USE Business_Analysis;

CREATE TABLE IF NOT EXISTS Brands(
	BrandID	INT PRIMARY KEY,
    BrandName VARCHAR(20)
);

CREATE TABLE IF NOT EXISTS Categories(
	CategoryID INT PRIMARY KEY,
    CategoryName VARCHAR(30)
);

CREATE TABLE IF NOT EXISTS Customers(
	CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(100),
    LastName VARCHAR(100),
	Phone VARCHAR(30),
	Email VARCHAR(255),
	Street VARCHAR(255),
	City VARCHAR(255),
	State VARCHAR(255),
	ZipCode INT NOT NUll
);

CREATE TABLE IF NOT EXISTS OrderItems(
	OrderID INT,
    ItemID INT PRIMARY KEY,
    ProductID INT,
	Quantity INT,
	ListPrice DECIMAL(10, 2),
	Discount DECIMAL(10, 2)
);

CREATE TABLE IF NOT EXISTS Orders(
	OrderID INT PRIMARY KEY,
    CustomerID INT,
    OrderStatus INT,
	OrderDate DATE,
	RequiredDate DATE,
    ShippedDate DATE,
	StoreID INT,
    StaffID INT
);

CREATE TABLE IF NOT EXISTS Staffs(
	StaffID INT PRIMARY KEY,
    FirstName VARCHAR(15),
    LastName VARCHAR(15),
	Email VARCHAR(35),
	Phone VARCHAR(15),
    Active_Stetus INT,
	StoreID INT,
    ManagerID INT,
    ManagerName VARCHAR(15) 
);

CREATE TABLE IF NOT EXISTS Stocks(
	StoreID INT,
	ProductID INT,
    Quantity INT
);

CREATE TABLE IF NOT EXISTS Stores(
	StoreID INT PRIMARY KEY,
    StoreName VARCHAR(200),
    Phone VARCHAR(20),
    Email VARCHAR(200),
    Street VARCHAR(255),
    City VARCHAR(200),
    State VARCHAR(200),
    ZipCode INT
);

CREATE TABLE IF NOT EXISTS Products(
	ProductID INT PRIMARY KEY,
    ProductName VARCHAR(255),
    BrandID INT,
    CategoryID INT,
    ModelYear YEAR,
    ListPrice DECIMAL(10, 2),
    Cost DECIMAL(10, 2)
);

-- 1. SALES & REVENUE ANALYSIS
-- 1. Total Revenue 
SELECT ROUND(SUM(quantity * ListPrice * (1 - discount)), 2) AS total_revenue FROM OrderItems;

-- Total Revenue by Year
SELECT YEAR(o.OrderDate) AS Year,
       ROUND(SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)), 2) AS TotalRevenue
FROM Orders o
JOIN OrderItems oi ON o.OrderID = oi.OrderID
GROUP BY YEAR(o.OrderDate)
ORDER BY Year;

-- Total Revenue and Monthly Sales by Month
SELECT DATE_FORMAT(o.OrderDate, '%M') AS Month,
        ROUND(SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)), 2) AS Revenue,
		SUM(oi.Quantity) AS TotalUnitsSold
FROM Orders o
JOIN OrderItems oi ON o.OrderID = oi.OrderID
GROUP BY Month;

-- Top Revenue-Generating Products
SELECT p.ProductName, ROUND(SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)), 2) AS TotalRevenue
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY TotalRevenue DESC
LIMIT 10;

-- Revenue by Brand
SELECT b.BrandName, ROUND(SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)), 2) AS Revenue
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
JOIN Brands b ON p.BrandID = b.BrandID
GROUP BY b.BrandName
ORDER BY Revenue DESC;

-- Discount Impact on Sales
SELECT Discount, COUNT(*) AS Orders, 
ROUND(SUM(Quantity * ListPrice * (1 - Discount)), 2) AS RevenueAfterDiscount
FROM OrderItems
GROUP BY Discount
ORDER BY Discount DESC;

-- Average Order Value
SELECT ROUND(SUM(oi.quantity * oi.ListPrice * (1 - oi.discount)) / COUNT(DISTINCT o.OrderID), 2) AS avg_order_value
FROM Orders o
JOIN OrderItems oi ON o.OrderID = oi.OrderID;

-- Brand Revenue by Year
SELECT b.BrandName, YEAR(o.OrderDate) AS OrderYear,
SUM(oi.Quantity * p.ListPrice * (1 - oi.Discount)) AS TotalRevenue
FROM Orders o
JOIN OrderItems oi ON o.OrderID = oi.OrderID
JOIN Products p ON oi.ProductID = p.ProductID
JOIN Brands b ON p.BrandID = b.BrandID
GROUP BY b.BrandName, YEAR(o.OrderDate)
ORDER BY b.BrandName, OrderYear;

-- 2. CUSTOMERS ANALYSIS
-- Total Number of Customers
SELECT COUNT(*) AS total_customers FROM Customers;

-- Top Customers by Orders and Revenue
SELECT 
    c.CustomerID,
    CONCAT(c.FirstName, ' ', c.LastName) AS CustomerName,
    COUNT(DISTINCT o.OrderID) AS OrdersCount,
    ROUND(SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)), 2) AS TotalRevenue
FROM Customers c
JOIN Orders o ON c.CustomerID = o.CustomerID
JOIN OrderItems oi ON o.OrderID = oi.OrderID
GROUP BY c.CustomerID
ORDER BY OrdersCount DESC, TotalRevenue DESC
LIMIT 10;

-- Customer Retention
SELECT 
  ROUND(
    (COUNT(retained.CustomerID) * 100.0) / COUNT(DISTINCT o.CustomerID), 
    2
  ) AS retention_percentage
FROM Orders o
LEFT JOIN (
  SELECT CustomerID
  FROM Orders
  GROUP BY CustomerID
  HAVING COUNT(OrderID) > 1
) AS retained ON o.CustomerID = retained.CustomerID;

-- Customers Who Ordered from All Brands 
SELECT c.CustomerID, c.FirstName, c.LastName
FROM Customers c
WHERE NOT EXISTS (
    SELECT b.BrandID
    FROM Brands b
    WHERE NOT EXISTS (
        SELECT oi.ProductID
        FROM Orders o
        JOIN OrderItems oi ON o.OrderID = oi.OrderID
        JOIN Products p ON oi.ProductID = p.ProductID
        WHERE o.CustomerID = c.CustomerID
        AND p.BrandID = b.BrandID
    )
);

-- Customers Who Ordered from All Categories 
SELECT c.CustomerID, c.FirstName, c.LastName
FROM Customers c
WHERE NOT EXISTS (
    SELECT cat.CategoryID
    FROM Categories cat
    WHERE NOT EXISTS (
        SELECT oi.ProductID
        FROM Orders o
        JOIN OrderItems oi ON o.OrderID = oi.OrderID
        JOIN Products p ON oi.ProductID = p.ProductID
        WHERE o.CustomerID = c.CustomerID
        AND p.CategoryID = cat.CategoryID
    )
);

-- Average of Average Days Between Orders 
WITH OrderedDates AS (
    SELECT CustomerID, OrderDate,
           LAG(OrderDate) OVER (PARTITION BY CustomerID ORDER BY OrderDate) AS PreviousOrderDate
    FROM Orders
),
OrderDateDifferences AS (
    SELECT CustomerID, DATEDIFF(OrderDate, PreviousOrderDate) AS DaysBetweenOrders
    FROM OrderedDates
    WHERE PreviousOrderDate IS NOT NULL
),
CustomerAverages AS (
    SELECT CustomerID, AVG(DaysBetweenOrders) AS AverageDaysBetweenOrders
    FROM OrderDateDifferences
    GROUP BY CustomerID
)
SELECT AVG(AverageDaysBetweenOrders) AS OverallAverageDaysBetweenOrders
FROM CustomerAverages;

-- Customer Location Distribution 
SELECT city, COUNT(*) AS customer_count FROM Customers GROUP BY city ORDER BY customer_count DESC;

-- 3. PRODUCT & INVENTORY INSIGHTS
-- Top 5 Best-Selling Products
SELECT 
    p.ProductName,
    SUM(oi.quantity) AS total_sold
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY total_sold DESC
LIMIT 5;

-- Slow-Moving Products (Sold < 5 units)
SELECT p.ProductName, SUM(oi.quantity) AS total_sold
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
GROUP BY p.ProductName
HAVING total_sold < 5;

-- Products with Highest Discount 
SELECT p.ProductName, MAX(oi.discount) AS max_discount
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
GROUP BY p.ProductName
ORDER BY max_discount DESC
LIMIT 10;

-- Out-of-Stock Products 
SELECT p.ProductName, s.quantity
FROM Stocks s
JOIN Products p ON s.ProductID = p.ProductID
WHERE s.quantity = 0;

-- High-Performing Categories 
SELECT c.CategoryName, SUM(oi.quantity) AS units_sold
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY c.CategoryName
ORDER BY units_sold DESC;

-- Average Discount per Order 
SELECT ROUND(AVG(discount), 2) AS avg_discount FROM OrderItems;

-- Average Items per Order
SELECT ROUND(SUM(quantity) / COUNT(DISTINCT OrderId)) AS avg_items_per_order FROM OrderItems;

-- 4. PROFITABILITY ANALYSIS
-- Gross Profit by Product
SELECT 
       ROUND(SUM(oi.quantity * oi.ListPrice * (1 - oi.discount)), 2) AS revenue,
       ROUND(SUM(oi.quantity * cost), 2) AS cost,
       ROUND(SUM(oi.quantity * oi.ListPrice * (1 - oi.discount)) - SUM(oi.quantity * cost), 2) AS profit
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
ORDER BY profit DESC
LIMIT 10;

-- Category Profitability
SELECT c.CategoryName,
       ROUND(SUM(oi.quantity * oi.ListPrice * (1 - oi.discount)), 2) AS revenue
FROM OrderItems oi
JOIN Products p ON oi.ProductID = p.ProductID
JOIN Categories c ON p.CategoryID = c.CategoryID
GROUP BY c.CategoryName
ORDER BY revenue DESC;

-- 5. TIME-BASED ANALYSIS
-- Sales Growth: Current vs Previous Month 
SELECT 
    DATE_FORMAT(OrderDate, '%Y-%m') AS month,
    ROUND(SUM(oi.quantity * oi.ListPrice * (1 - oi.discount)), 2) AS revenue
FROM Orders o
JOIN OrderItems oi ON o.OrderId = oi.OrderId
GROUP BY month
ORDER BY month DESC
LIMIT 2;

-- Average Monthly Orders per Customer 
SELECT ROUND(COUNT(*) / COUNT(DISTINCT DATE_FORMAT(OrderDate, '%Y-%m')), 2) AS avg_orders_per_month
FROM Orders;

-- 6. STAFF PERFORMANCE
-- Sales Performance by Staff 
SELECT s.FirstName, s.LastName, COUNT(o.OrderID) AS OrdersHandled,
ROUND(SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)), 2) AS TotalSales
FROM Staffs s
JOIN Orders o ON s.StaffID = o.StaffID
JOIN OrderItems oi ON o.OrderID = oi.OrderID
GROUP BY s.StaffID
ORDER BY TotalSales DESC;

-- Staff Revenue Contribution
SELECT s.FirstName, s.LastName, ROUND(SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)), 2) AS StaffRevenue
FROM Orders o
JOIN Staffs s ON o.StaffID = s.StaffID
JOIN OrderItems oi ON o.OrderID = oi.OrderID
GROUP BY s.StaffID
ORDER BY StaffRevenue DESC;

-- Order Count by Staff
SELECT CONCAT(s.FirstName, ' ', s.LastName) AS staff_name, COUNT(o.OrderID) AS orders_handled
FROM Orders o
JOIN Staffs s ON o.StaffID = s.StaffID
GROUP BY staff_name
ORDER BY orders_handled DESC;

-- Calculate the percentage of orders that were shipped late (ShippedDate > RequiredDate).
WITH OrderTimeliness AS (
    SELECT
        OrderID,
        CASE
            WHEN ShippedDate > RequiredDate THEN 1
            ELSE 0
        END AS IsLate
    FROM Orders
    WHERE ShippedDate IS NOT NULL AND RequiredDate IS NOT NULL
),
TotalOrders AS (
    SELECT COUNT(*) AS Total FROM Orders WHERE ShippedDate IS NOT NULL AND RequiredDate IS NOT NULL
),
LateOrders AS (
    SELECT SUM(IsLate) AS LateCount FROM OrderTimeliness
)
SELECT
    (SELECT LateCount FROM LateOrders) / (SELECT Total FROM TotalOrders) * 100 AS PercentageLateOrders;

-- 7. STORE & STOCK INSIGHTS
-- Top Performing Store
SELECT s.StoreName, ROUND(SUM(oi.quantity * oi.ListPrice * (1 - oi.discount)), 2) AS total_sales
FROM Orders o
JOIN OrderItems oi ON o.OrderID = oi.OrderID
JOIN Stores s ON o.StoreID = s.StoreID
GROUP BY s.StoreName
ORDER BY total_sales DESC
LIMIT 1;

-- Revenue by Store
SELECT 
    s.StoreName,
    ROUND(SUM(oi.quantity * oi.ListPrice * (1 - oi.discount)), 2) AS revenue
FROM Orders o
JOIN OrderItems oi ON o.OrderID = oi.OrderID
JOIN Stores s ON o.StoreID = s.StoreID
GROUP BY s.StoreName
ORDER BY revenue DESC;

-- Stock Levels by Store
SELECT st.StoreName, p.ProductName, s.Quantity
FROM Stocks s
JOIN Stores st ON s.StoreID = st.StoreID
JOIN Products p ON s.ProductID = p.ProductID
ORDER BY st.StoreName, p.ProductName;

-- Products Never in Stock
SELECT p.ProductID, p.ProductName
FROM Products p
WHERE NOT EXISTS (
    SELECT 1 FROM Stocks s WHERE s.ProductID = p.ProductID
);

-- Top-Spending Customer by Store
WITH StoreCustomerSpending AS (
    SELECT o.StoreID, c.CustomerID, c.FirstName, c.LastName,
           SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)) AS TotalSpending,
           ROW_NUMBER() OVER (PARTITION BY o.StoreID ORDER BY SUM(oi.Quantity * oi.ListPrice * (1 - oi.Discount)) DESC) AS rn
    FROM Orders o
    JOIN Customers c ON o.CustomerID = c.CustomerID
    JOIN OrderItems oi ON o.OrderID = oi.OrderID
    GROUP BY o.StoreID, c.CustomerID, c.FirstName, c.LastName
)
SELECT s.StoreName, scs.FirstName, scs.LastName, scs.TotalSpending AS HighestSpendingCustomer
FROM StoreCustomerSpending scs
JOIN Stores s ON scs.StoreID = s.StoreID
WHERE scs.rn = 1;

-- Top Order Day by Store 
WITH OrdersWithDayOfWeek AS (
    SELECT
        StoreID,
        DATE_FORMAT(OrderDate, '%w') AS DayOfWeek, -- 0=Sunday, 1=Monday, ..., 6=Saturday
        COUNT(*) AS OrderCount,
        ROW_NUMBER() OVER (PARTITION BY StoreID ORDER BY COUNT(*) DESC) AS rn
    FROM Orders
    GROUP BY StoreID, DATE_FORMAT(OrderDate, '%w')
)
SELECT
    s.StoreName,
    CASE
        WHEN ow.DayOfWeek = '0' THEN 'Sunday'
        WHEN ow.DayOfWeek = '1' THEN 'Monday'
        WHEN ow.DayOfWeek = '2' THEN 'Tuesday'
        WHEN ow.DayOfWeek = '3' THEN 'Wednesday'
        WHEN ow.DayOfWeek = '4' THEN 'Thursday'
        WHEN ow.DayOfWeek = '5' THEN 'Friday'
        WHEN ow.DayOfWeek = '6' THEN 'Saturday'
        ELSE ''
    END AS MostOrdersDay,
    ow.OrderCount AS NumberOfOrders
FROM OrdersWithDayOfWeek ow
JOIN Stores s ON ow.StoreID = s.StoreID
WHERE ow.rn = 1;

