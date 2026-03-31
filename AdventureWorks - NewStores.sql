
-- Create SCHEMA 'NewStores':
IF NOT EXISTS (
    SELECT 1 FROM sys.schemas WHERE name = 'NewStores'
)
BEGIN
    EXEC('CREATE SCHEMA NewStores');
END



----------------------Off Limit Cities script----------------------
-- Populates TABLE 'OffLimitCities':
---- Top Client defined by their Total Revenue in comparison to the Total Revenue of other Clients for the available sales data;
---- We took advantage of the already available View that created a directory of stores and their rexpective addresses;
---- As defined by the Business Question, the limitation of location should stay at the city level, so we continued as such; 

IF OBJECT_ID('NewStores.OffLimitCities', 'U') IS NOT NULL
BEGIN
    DROP TABLE NewStores.OffLimitCities;
END

CREATE TABLE NewStores.OffLimitCities (
    StoreName NVARCHAR(100),
    City NVARCHAR(100),
    US_State NVARCHAR(100),
    PostalCode NVARCHAR(20),
    Stores_Revenue DECIMAL(18,2)
);


INSERT INTO NewStores.OffLimitCities (StoreName, City, US_State, PostalCode, Stores_Revenue)
SELECT TOP 30
    vSWA.Name as StoreName,
    vSWA.City,
    vSWA.StateProvinceName AS US_State,
    vSWA.PostalCode,
    SUM(SOH.TotalDue) AS Stores_Revenue
FROM Sales.vStoreWithAddresses AS vSWA
JOIN Sales.Customer AS CS
    ON vSWA.BusinessEntityID = CS.StoreID
JOIN Sales.SalesOrderHeader AS SOH
    ON CS.CustomerID = SOH.CustomerID
WHERE vSWA.CountryRegionName = 'United States'
GROUP BY 
    vSWA.BusinessEntityID, 
    vSWA.Name, 
    vSWA.City, 
    vSWA.StateProvinceName, 
    vSWA.PostalCode, 
    vSWA.CountryRegionName
ORDER BY SUM(SOH.TotalDue) DESC;

select * from NewStores.OffLimitCities



-- Identify Clients with more than one store:
select 
    Name
    , COUNT(Name)
from Sales.Store
group by Name
having COUNT(Name) > 1

---- Two Clients were identified:
    -- Friendly Bike Shop
    -- Sports Products Store

---- Cities where those two clients are:
Select * from Sales.vStoreWithAddresses
where Name = 'Friendly Bike Shop' OR Name = 'Sports Products Store'
    -- Bellingham/US (TOP25), Port Huron/US
    -- Lieusaint/FR, Santa Ana/US

-- Adendum: the code could be better developed in order to return any amount of clients that were identified as >1 store, but this was enough for the job at hand;



----------------------Best Cities script----------------------

-- Best States Analysis:
select 
    vIC.StateProvinceName, 
    SUM(SOH.TotalDue) as Individuals_Revenue
from Sales.vIndividualCustomer as vIC
join Sales.SalesOrderHeader as SOH
on vIC.BusinessEntityID = SOH.CustomerID
where vIC.CountryRegionName = 'United States'
group by vIC.StateProvinceName
order by SUM(SOH.TotalDue) DESC

-- Best City Analysis:
select 
    vIC.City, 
    vIC.PostalCode, 
    vIC.StateProvinceName, 
    SUM(SOH.TotalDue) as Individuals_Revenue, 
    COUNT(SOH.SalesOrderID) as QuantityOfSales, 
    SUM(SOH.TotalDue)/COUNT(SOH.SalesOrderID) as Ticket
from Sales.vIndividualCustomer as vIC
join Sales.SalesOrderHeader as SOH
on vIC.BusinessEntityID = SOH.CustomerID
where vIC.CountryRegionName = 'United States'
group by vIC.City, vIC.PostalCode, vIC.StateProvinceName
order by SUM(SOH.TotalDue) DESC




-- Populates TABLE 'MarketIndividuals':
---- Contrary to the Business Question definition of limitation of location, given the proximity and size of some cities, we took the assumption that a store in one city is capable of impacting some adjacent cities as well;
---- In order to understand the potential new market of one region, we analyzed the total revenue made through direct sales of each Zip Code Regional Identifier (its first two digits) and called it 'Postal_Individual_Revenue';
IF OBJECT_ID('NewStores.MarketIndividuals', 'U') IS NOT NULL
BEGIN
    DROP TABLE NewStores.MarketIndividuals;
END

CREATE TABLE NewStores.MarketIndividuals (
    Postal NVARCHAR(10),
    Postal_Individual_Revenue DECIMAL(18,2)
);


INSERT INTO NewStores.MarketIndividuals (Postal, Postal_Individual_Revenue)

select LEFT(vIC.PostalCode, 2) as Postal, 
    SUM(SOH.TotalDue) as Postal_Individual_Revenue
from Sales.vIndividualCustomer as vIC
join Sales.SalesOrderHeader as SOH
on vIC.BusinessEntityID = SOH.CustomerID
where vIC.CountryRegionName = 'United States'
group by LEFT(vIC.PostalCode, 2)
order by SUM(SOH.TotalDue) DESC

select * from NewStores.MarketIndividuals
order by Postal_Individual_Revenue DESC




-- Creates and Populates TABLE 'MarketStores':
---- In order to understand the store market of one region that is already in place, we analyzed the total revenue made through direct sales of each Zip Code Regional Identifier (its first two digits) and called it 'Postal_Market_Revenue';
IF OBJECT_ID('NewStores.MarketStores', 'U') IS NOT NULL
BEGIN
    DROP TABLE NewStores.MarketStores;
END

CREATE TABLE NewStores.MarketStores (
    Postal NVARCHAR(10),
    Postal_Stores_Revenue DECIMAL(18,2)
);


INSERT INTO NewStores.MarketStores (Postal, Postal_Stores_Revenue)

SELECT 
    LEFT(vSWA.PostalCode, 2) AS Postal,
    SUM(SOH.TotalDue) AS Postal_Stores_Revenue
FROM Sales.vStoreWithAddresses AS vSWA
JOIN Sales.Customer AS CS
    ON vSWA.BusinessEntityID = CS.StoreID
JOIN Sales.SalesOrderHeader AS SOH
    ON CS.CustomerID = SOH.CustomerID
WHERE vSWA.CountryRegionName = 'United States'
GROUP BY 
    LEFT(vSWA.PostalCode, 2) 
ORDER BY SUM(SOH.TotalDue) DESC

select * from NewStores.MarketStores
order by Postal_Stores_Revenue DESC



-- Creates and Populates TABLE 'BestCities':
---- For Best Cities, we wanted to map individually the cities that had the highest potentil for a new market
IF OBJECT_ID('NewStores.BestCities', 'U') IS NOT NULL
BEGIN
    DROP TABLE NewStores.BestCities;
END

CREATE TABLE NewStores.BestCities (
    City NVARCHAR(100),
    PostalCode NVARCHAR(10),
    Postal2 INT,
    StateProvinceName NVARCHAR (100),
    Individuals_Revenue DECIMAL (18,2),
    QuantityOfSales INT,
    Ticket DECIMAL (18,2),
    OffLimitCities NVARCHAR (100)
);


INSERT INTO NewStores.BestCities (City, PostalCode, Postal2, StateProvinceName, Individuals_Revenue, QuantityOfSales, Ticket, OffLimitCities)


select vIC.City, 
    vIC.PostalCode,
    LEFT(vIC.PostalCode, 2), 
    vIC.StateProvinceName,
    SUM(SOH.TotalDue) as Individuals_Revenue, 
    COUNT(SOH.SalesOrderID) as QuantityOfSales, 
    SUM(SOH.TotalDue)/COUNT(SOH.SalesOrderID) as Ticket,
    CASE
        WHEN OLC.City IS NULL THEN 'OK'
        ELSE 'Off Limit'
        END AS OffLimitCities
from Sales.vIndividualCustomer as vIC
join Sales.SalesOrderHeader as SOH
on vIC.BusinessEntityID = SOH.CustomerID
left join NewStores.OffLimitCities as OLC
on vIC.City = OLC.City
where vIC.CountryRegionName = 'United States'
group by vIC.City, vIC.PostalCode, vIC.StateProvinceName, OLC.City
order by SUM(SOH.TotalDue) DESC

select * from NewStores.BestCities
order by Individuals_Revenue DESC

---- Adendum: The code for initial two digits could probably be better developed through LIKE 'XX%' in order to avoid creating new tables, this was a time/knowledge/benefit decision




----------------------Decision narrow down----------------------
---- Analysis 1:
SELECT
    BC.City,
    BC.PostalCode,
    BC.Postal2,
    BC.StateProvinceName,
    BC.Individuals_Revenue,
    1-MS.Postal_Stores_Revenue/(MI.Postal_Individual_Revenue+MS.Postal_Stores_Revenue) as MarketAvailability,
    MS.Postal_Stores_Revenue,
    MI.Postal_Individual_Revenue
from NewStores.BestCities as BC
join NewStores.MarketStores as MS
ON BC.Postal2 = MS.Postal
join NewStores.MarketIndividuals as MI
ON LEFT(BC.PostalCode, 2) = MI.Postal
order by MarketAvailability DESC

-- Analysis 2:
SELECT
    Distinct BC.Postal2,
    1-MS.Postal_Stores_Revenue/(MI.Postal_Individual_Revenue+MS.Postal_Stores_Revenue) as MarketAvailability,
    MS.Postal_Stores_Revenue,
    MI.Postal_Individual_Revenue
from NewStores.BestCities as BC
join NewStores.MarketStores as MS
ON BC.Postal2 = MS.Postal
join NewStores.MarketIndividuals as MI
ON LEFT(BC.PostalCode, 2) = MI.Postal
order by MI.Postal_Individual_Revenue DESC




