USE mobility;
GO

-- 1) Total row count
SELECT COUNT(*) AS row_count FROM dbo.trips_raw;

--2) Column names and data types
SELECT c.name AS column_name, t.name AS data_type
FROM sys.columns c
JOIN sys.types t ON c.user_type_id = t.user_type_id
WHERE c.object_id = OBJECT_ID('dbo.trips_raw')
ORDER BY c.column_id;

--3) Date range of trips
SELECT
	MIN(pickup_datetime) AS first_pickup,
	MAX(pickup_datetime) AS last_pickup 
FROM dbo.trips_raw;

-- 4) Trips per company
SELECT
    hvfhs_license_num,
    COUNT(*) AS trips,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS decimal(5,2)) AS pct
FROM dbo.trips_raw
GROUP BY hvfhs_license_num
ORDER BY trips DESC;

--5) NULL counts in key columns
SELECT
    SUM(CASE WHEN request_datetime IS NULL THEN 1 ELSE 0 END) AS null_request,
    SUM(CASE WHEN on_scene_datetime IS NULL THEN 1 ELSE 0 END) AS null_on_scene,
    SUM(CASE WHEN pickup_datetime IS NULL THEN 1 ELSE 0 END) AS null_pickup,
    SUM(CASE WHEN driver_pay IS NULL THEN 1 ELSE 0 END) AS null_driver_pay
FROM dbo.trips_raw;

--6) Basic statistics for fare, sitance and duration
SELECT
    MIN(base_passenger_fare) AS min_fare,
    AVG(base_passenger_fare) AS avg_fare,
    MAX(base_passenger_fare) AS max_fare,
    MIN(trip_miles)          AS min_miles,
    AVG(trip_miles)          AS avg_miles,
    MAX(trip_miles)          AS max_miles,
    MIN(trip_time)           AS min_seconds,
    MAX(trip_time)           AS max_seconds
From dbo.trips_raw;

-- 7) Counts of suspicious rows (input for the cleaning stage)
SELECT
    SUM(CASE WHEN base_passenger_fare < 0 THEN 1 ELSE 0 END)           AS negative_fare,
    SUM(CASE WHEN base_passenger_fare = 0 THEN 1 ELSE 0 END)           AS zero_fare,
    SUM(CASE WHEN trip_miles = 0 THEN 1 ELSE 0 END)                    AS zero_miles,
    SUM(CASE WHEN trip_miles > 100 THEN 1 ELSE 0 END)                  AS over_100_miles,
    SUM(CASE WHEN trip_time = 0 THEN 1 ELSE 0 END)                     AS zero_time,
    SUM(CASE WHEN trip_time > 21600 THEN 1 ELSE 0 END)                 AS over_6_hours,
    SUM(CASE WHEN pickup_datetime < request_datetime THEN 1 ELSE 0 END) AS pickup_before_request,
    SUM(CASE WHEN dropoff_datetime < pickup_datetime THEN 1 ELSE 0 END) AS dropoff_before_pickup
FROM dbo.trips_raw;

-- 8) Diagnose rows where pickup happens before the request
SELECT
    hvfhs_license_num,
    COUNT(*) AS affected_rows,
    MIN(DATEDIFF(SECOND, request_datetime, pickup_datetime)) AS min_diff_sec,
    AVG(CAST(DATEDIFF(SECOND, request_datetime, pickup_datetime) AS float)) AS avg_diff_sec,
    MAX(DATEDIFF(SECOND, request_datetime, pickup_datetime)) AS max_diff_sec
FROM dbo.trips_raw
WHERE pickup_datetime < request_datetime
GROUP BY hvfhs_license_num;

-- 9) Size distribution of the pickup-before-request gap
SELECT gap_bucket, COUNT(*) AS rows_in_bucket
FROM (
    SELECT
        CASE
            WHEN DATEDIFF(SECOND, request_datetime, pickup_datetime) >= -10  THEN '1) up to 10 sec'
            WHEN DATEDIFF(SECOND, request_datetime, pickup_datetime) >= -60  THEN '2) 10-60 sec'
            WHEN DATEDIFF(SECOND, request_datetime, pickup_datetime) >= -300 THEN '3) 1-5 min'
            WHEN DATEDIFF(SECOND, request_datetime, pickup_datetime) >= -900 THEN '4) 5-15 min'
            ELSE '5) over 15 min'
        END AS gap_bucket
    FROM dbo.trips_raw
    WHERE pickup_datetime < request_datetime
) AS b
GROUP BY gap_bucket
ORDER BY gap_bucket;