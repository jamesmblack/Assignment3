-- Problem 1: Find the sellers and product names that are out of stock.
select products.name, merchants.name from sell
JOIN products ON sell.pid=products.pid
JOIN merchants ON sell.mid=merchants.mid
WHERE sell.quantity_available=0;

-- Problem 2: Find the products and descriptions that are not sold

select products.name, products.pid, products.description from products
WHERE products.pid NOT IN (select pid from contain);

-- Problem 3: How many customers bought SATA drives but not routers.
-- Error
WITH sata_customers AS (
    -- Customers who bought products with 'SATA' in description
    SELECT DISTINCT customers.cid, customers.fullname
    FROM customers
    JOIN place ON customers.cid = place.cid
    JOIN contain ON place.oid = contain.oid
    JOIN products ON contain.pid = products.pid
    WHERE products.description LIKE '%SATA%'
),
router_customers AS (
    -- Customers who bought products named 'Router'
    SELECT DISTINCT customers.cid
    FROM customers
    JOIN place ON customers.cid = place.cid
    JOIN contain ON place.oid = contain.oid
    JOIN products ON contain.pid = products.pid
    WHERE products.name = 'Router'
)
-- Select customers who bought SATA products but not routers
SELECT DISTINCT sata_customers.cid, sata_customers.fullname
FROM sata_customers
LEFT JOIN router_customers ON sata_customers.cid = router_customers.cid
WHERE router_customers.cid IS NULL
-- Following section returns null values if no data is found.
UNION ALL
SELECT NULL, NULL
WHERE NOT EXISTS (
    SELECT 1
    FROM sata_customers
    LEFT JOIN router_customers ON sata_customers.cid = router_customers.cid
    WHERE router_customers.cid IS NULL);
  
-- Problem 4:  HP has a 20% sale on all products.
	SET SQL_SAFE_UPDATES = 0; -- Get rid of safe updates temporarily.
    update sell 
JOIN products  ON sell.pid = products.pid
JOIN merchants ON sell.mid = merchants.mid
set sell.price = sell.price * 0.8  -- Apply a 20% discount
WHERE merchants.name = 'HP'  -- Only for HP merchant
AND products.category = 'Networking';  -- Only for networking category products

SET SQL_SAFE_UPDATES = 1; -- Reenable safe updates.
    -- Problem 5: What did Uriel Whitney order from Acer?
    
    select products.name, sell.price
from customers
JOIN place ON customers.cid = place.cid
JOIN contain ON place.oid = contain.oid
JOIN products  ON contain.pid = products.pid
JOIN sell  ON products.pid = sell.pid
JOIN merchants ON sell.mid = merchants.mid
WHERE customers.fullname = 'Uriel Whitney' 
  AND merchants.name = 'Acer'; 
  
  -- Problem 6: List the annual total sales for each company (sort the results along the company and the year attributes).
  select  merchants.name AS merchant_name, YEAR(place.order_date) AS year, -- selects the name of the merchants and specifically the year of the date.
  ROUND(SUM(sell.price) * COUNT(contain.pid), 2) AS total_sales -- Last part of selecting from merchants to find the total sales of each company per year. It does this by counting the amount of times a product is ordered, and multiplying it by the price.
from merchants
JOIN sell ON merchants.mid = sell.mid -- Joins
JOIN contain ON sell.pid = contain.pid
JOIN place ON contain.oid = place.oid
JOIN orders ON place.oid = orders.oid
GROUP BY merchants.name, year -- This GROUP BY clause groups the sales of the query that are summed specifically by merchant, and then year, to find the sales.
ORDER BY merchants.name ASC, year ASC;
  
  
  -- Problem 7: Which company had the highest annual revenue and in what year?
  --
  -- With statement to first find total annual sales for all companies.
WITH revenue AS ( select  merchants.name AS merchant_name, YEAR(place.order_date) AS year, -- selects the name of the merchants and specifically the year of the date.
 ROUND(SUM(sell.price) * COUNT(contain.pid), 2) AS total_sales -- Last part of selecting from merchants to find the total sales of each company per year. It does this by counting the amount of times a product is ordered, and multiplying it by the price.
from merchants
JOIN sell ON merchants.mid = sell.mid -- Joins
JOIN contain ON sell.pid = contain.pid
JOIN place ON contain.oid = place.oid
JOIN orders ON place.oid = orders.oid
GROUP BY merchants.name, year -- This GROUP BY clause groups the sales of the query that are summed specifically by merchant, and then year, to find the sales.
)
select merchant_name, year, total_sales -- Select statement uses annual revenue table, and queries for maximum value and then displays year, name, and sales.
from revenue
WHERE total_sales = (select MAX(total_sales) from revenue);
  
  -- Problem 8: On average, what was the cheapest shipping method used ever?
  
  select orders.shipping_method, ROUND(AVG(orders.shipping_cost), 2) AS average -- Selects the shipping method and then a average rounded to two decimal places.
from orders
GROUP BY orders.shipping_method
ORDER BY average ASC; -- Ordered in ascending order so the cheapest option is first.

-- Problem 9: What is the best sold ($) category for each company?
-- Error?
-- select statement displays merchant_name, category, and total sales via contain.pid and price, rounded.
WITH counted AS (
    -- Count how many times each product was ordered
    select contain.pid, COUNT(contain.pid) AS count_o
    from contain
    GROUP BY contain.pid
)
select merchants.name AS merchant_name, -- selects name, category, and sales. 
       products.category, 
       ROUND(SUM(sell.price * counted.count_o), 2) AS total_sales
from merchants
JOIN sell ON merchants.mid = sell.mid -- Join statements
JOIN products ON sell.pid = products.pid
JOIN counted ON sell.pid = counted.pid
GROUP BY merchants.name, products.category -- Grouped by merchants and category.
ORDER BY merchants.name, total_sales DESC; -- Ordered in descending order to show the most profitable category for each company.

-- Problem 10: For each company find out which customers have spent the most and the least amounts.

WITH customer_spending AS ( -- Finds the amount the customer spent.
    select customers.cid, -- Selects id, fullname, merchant id and sums the shipping cost AND the price so that the full cost is represented.
           customers.fullname, 
           sell.mid, 
           SUM(sell.price + orders.shipping_cost) AS total
    from customers
    JOIN place ON customers.cid = place.cid -- Joins
    JOIN contain ON place.oid = contain.oid
    JOIN orders ON place.oid = orders.oid
    JOIN sell ON contain.pid = sell.pid
    GROUP BY customers.cid, -- Grouped by cid, fullname, then mid.
             customers.fullname, 
             sell.mid
),
ranked_customers AS ( -- This ranking system finds the first item in each listing when ordered least to greatest and greatest to least, and labels them as the max and min.
    select customer_spending.cid,   -- Uses the customer spending table for finding each of what they paid for.
           customer_spending.fullname, 
           customer_spending.mid, 
           ROUND(customer_spending.total, 2) AS total, -- Round total to 2 decimal places
           ROW_NUMBER() OVER (PARTITION BY customer_spending.mid ORDER BY customer_spending.total DESC) AS rank_highest,
           ROW_NUMBER() OVER (PARTITION BY customer_spending.mid ORDER BY customer_spending.total ASC) AS rank_lowest
    from customer_spending
)
-- Select customers with the highest and lowest spending for each merchant
select merchants.name AS merchant_name,
       ranked_customers.fullname, 
       ranked_customers.total
from ranked_customers
JOIN merchants ON ranked_customers.mid = merchants.mid
WHERE ranked_customers.rank_highest = 1  -- Following or statement finds highest and lowest.
   OR ranked_customers.rank_lowest = 1
ORDER BY merchants.name, 
         ranked_customers.total DESC;