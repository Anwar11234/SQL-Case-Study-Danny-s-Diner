-- SQL Queries for Restaurant Sales Analysis

-- 1. What is the total amount each customer spent at the restaurant?
SELECT customer_id, SUM(price) AS total_spent
FROM sales s 
JOIN menu m ON s.product_id = m.product_id
GROUP BY customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT customer_id, COUNT(DISTINCT order_date) AS visit_days
FROM sales
GROUP BY customer_id;

-- 3. What was the first item from the menu purchased by each customer?
WITH first_items AS (
    SELECT customer_id, product_id, DENSE_RANK() OVER(PARTITION BY customer_id ORDER BY order_date) AS rnk
    FROM sales
) 
SELECT customer_id, product_name
FROM first_items f 
JOIN menu m ON f.product_id = m.product_id
WHERE rnk = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT TOP (1) product_name, COUNT(s.product_id) AS purchase_count
FROM sales s 
JOIN menu m ON s.product_id = m.product_id
GROUP BY product_name
ORDER BY purchase_count DESC;

-- 5. Which item was the most popular for each customer?
WITH most_popular AS (
    SELECT customer_id, product_name, 
    RANK() OVER(PARTITION BY customer_id ORDER BY COUNT(s.product_id) DESC) AS rnk
    FROM sales s 
    JOIN menu m ON s.product_id = m.product_id
    GROUP BY customer_id, product_name
)
SELECT customer_id, product_name AS most_popular_product
FROM most_popular
WHERE rnk = 1;

-- 6. Which item was purchased first by the customer after they became a member?
WITH orders_after_membership AS (
    SELECT s.customer_id, order_date, product_name, DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY order_date) AS rnk
    FROM sales s 
    JOIN members mem ON s.customer_id = mem.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date > mem.join_date
)	
SELECT customer_id, product_name 
FROM orders_after_membership
WHERE rnk = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH orders_before_membership AS (
    SELECT s.customer_id, order_date, product_name, DENSE_RANK() OVER(PARTITION BY s.customer_id ORDER BY order_date DESC) AS rnk
    FROM sales s 
    JOIN members mem ON s.customer_id = mem.customer_id
    JOIN menu m ON s.product_id = m.product_id
    WHERE s.order_date < mem.join_date
)	
SELECT customer_id, product_name 
FROM orders_before_membership
WHERE rnk = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT s.customer_id, SUM(price) AS total_amount
FROM sales s 
JOIN members mem ON s.customer_id = mem.customer_id
JOIN menu m ON s.product_id = m.product_id
WHERE s.order_date < mem.join_date
GROUP BY s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier, how many points would each customer have?
SELECT s.customer_id, 
    SUM(CASE WHEN product_name = 'sushi' THEN 20 * price ELSE 10 * price END) AS total_points
FROM sales s 
JOIN menu m ON s.product_id = m.product_id
GROUP BY s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date), how many points do customers A and B have at the end of January?
SELECT s.customer_id, 
    SUM(CASE 
        WHEN product_name = 'sushi' THEN 20 * price 
        WHEN order_date BETWEEN join_date AND DATEADD(day, 6, join_date) THEN 20 * price 
        ELSE 10 * price 
    END) AS total_points
FROM sales s 
JOIN members mem ON s.customer_id = mem.customer_id AND join_date <= order_date
JOIN menu m ON s.product_id = m.product_id
WHERE order_date <= '2021-01-31'
GROUP BY s.customer_id;

-- Create a view to join all the relevant data
GO
CREATE VIEW all_data AS (
    SELECT s.customer_id, order_date, product_name, price, 
           CASE WHEN order_date < join_date OR join_date IS NULL THEN 'N' ELSE 'Y' END AS member
    FROM sales s 
    LEFT JOIN members mem ON s.customer_id = mem.customer_id
    JOIN menu m ON s.product_id = m.product_id
);
GO

-- Select from the view with additional ranking
SELECT customer_id, order_date, product_name, price, member, 
       CASE WHEN member = 'N' THEN NULL
            ELSE RANK() OVER(PARTITION BY customer_id, member ORDER BY order_date) END AS ranking
FROM all_data;
