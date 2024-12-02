## Business Request-1: City-Level Fare and Trip Summary Report

SELECT 
    c.city_name,
    COUNT(ft.trip_id) AS total_trips,
    AVG(ft.fare_amount / ft.distance_travelled_km) AS avg_fare_per_km,
    AVG(ft.fare_amount) AS avg_fare_per_trip,
    (COUNT(ft.trip_id) / (SELECT 
            COUNT(*)
        FROM
            fact_trips)) * 100 AS pct_contribution_to_total_trips
FROM
    fact_trips ft
        JOIN
    dim_city c ON ft.city_id = c.city_id
GROUP BY c.city_name;

## Business Request-2: Monthly City-Level Trips Target Performance Report

SELECT 
    c.city_name,
    DATE_FORMAT(dt.date, '%M') AS month_name,
    COUNT(ft.trip_id) AS actual_trips,
    MAX(tt.total_target_trips) AS target_trips, -- Use MAX() since target trips are constant for the city and month
    CASE
        WHEN COUNT(ft.trip_id) > MAX(tt.total_target_trips) THEN 'Above Target'
        ELSE 'Below Target'
    END AS performance_status,
    ((COUNT(ft.trip_id) - MAX(tt.total_target_trips)) / MAX(tt.total_target_trips)) * 100 AS percentage_difference
FROM 
    trips_db.fact_trips ft
JOIN 
    trips_db.dim_city c ON ft.city_id = c.city_id
JOIN 
    trips_db.dim_date dt ON ft.date = dt.date
JOIN 
    targets_db.monthly_target_trips tt ON c.city_id = tt.city_id AND dt.start_of_month = tt.month
GROUP BY 
    c.city_name, DATE_FORMAT(dt.date, '%M');
    
## Business Request-3: City-Level Repeat Passenger Trip Frequency Report

SELECT 
    c.city_name,
    SUM(CASE WHEN dr.trip_count = '2-Trips' THEN dr.repeat_passenger_count ELSE 0 END) / SUM(dr.repeat_passenger_count) * 100 AS `2-Trips`,
    SUM(CASE WHEN dr.trip_count = '3-Trips' THEN dr.repeat_passenger_count ELSE 0 END) / SUM(dr.repeat_passenger_count) * 100 AS `3-Trips`,
    SUM(CASE WHEN dr.trip_count = '4-Trips' THEN dr.repeat_passenger_count ELSE 0 END) / SUM(dr.repeat_passenger_count) * 100 AS `4-Trips`
FROM 
    dim_repeat_trip_distribution dr
JOIN 
    dim_city c ON dr.city_id = c.city_id
GROUP BY 
    c.city_name;
    
## Business Request-4: Cities with Highest and Lowest Total New Passengers

WITH ranked_data AS (
    SELECT 
        c.city_name,
        SUM(fp.new_passengers) AS total_new_passengers,
        ROW_NUMBER() OVER (ORDER BY SUM(fp.new_passengers) DESC) AS rank_desc,
        ROW_NUMBER() OVER (ORDER BY SUM(fp.new_passengers) ASC) AS rank_asc
    FROM 
        fact_passenger_summary fp
    JOIN 
        dim_city c ON fp.city_id = c.city_id
    GROUP BY 
        c.city_name
)
SELECT 
    city_name,
    total_new_passengers,
    CASE
        WHEN rank_desc <= 3 THEN 'Top 3'
        WHEN rank_asc <= 3 THEN 'Bottom 3'
        ELSE NULL
    END AS city_category
FROM 
    ranked_data
WHERE 
    rank_desc <= 3 OR rank_asc <= 3;
    
## Business Request-5: Identify Month with Highest Revenue for Each City

WITH revenue_per_month AS (
    SELECT 
        c.city_name,
        DATE_FORMAT(dt.start_of_month, '%M') AS month_name,
        dt.start_of_month,
        SUM(ft.fare_amount) AS total_revenue
    FROM 
        fact_trips ft
    JOIN 
        dim_city c ON ft.city_id = c.city_id
    JOIN 
        dim_date dt ON ft.date = dt.date
    GROUP BY 
        c.city_name, dt.start_of_month
),
highest_revenue_month AS (
    SELECT 
        city_name,
        month_name,
        total_revenue,
        RANK() OVER (PARTITION BY city_name ORDER BY total_revenue DESC) AS revenue_rank
    FROM 
        revenue_per_month
)
SELECT 
    city_name,
    month_name AS highest_revenue_month,
    total_revenue AS revenue,
    ROUND((total_revenue / SUM(total_revenue) OVER (PARTITION BY city_name)) * 100, 2) AS percentage_contribution
FROM 
    highest_revenue_month
WHERE 
    revenue_rank = 1;
    
## Business Request-6: Repeat Passenger Rate Analysis

WITH city_repeat_data AS (
    SELECT 
        city_id,
        SUM(repeat_passengers) AS total_repeat_passengers
    FROM 
        fact_passenger_summary
    GROUP BY 
        city_id
)
SELECT 
    c.city_name,
    DATE_FORMAT(fp.month, '%M') AS month,
    SUM(fp.total_passengers) AS total_passengers,
    SUM(fp.repeat_passengers) AS repeat_passengers,
    (SUM(fp.repeat_passengers) / SUM(fp.total_passengers)) * 100 AS monthly_repeat_passenger_rate,
    (SUM(fp.repeat_passengers) / crd.total_repeat_passengers) * 100 AS city_repeat_passenger_rate
FROM 
    fact_passenger_summary fp
JOIN 
    dim_city c ON fp.city_id = c.city_id
JOIN 
    city_repeat_data crd ON fp.city_id = crd.city_id
GROUP BY 
    c.city_name, fp.month, crd.total_repeat_passengers
ORDER BY 
    c.city_name, fp.month;


