USE mobility;
GO

-- Q1) Overall profile per company
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                           AS trips,
    AVG(base_passenger_fare)           AS avg_fare,
    AVG(trip_miles)                    AS avg_miles,
    AVG(trip_time / 60.0)              AS avg_minutes
FROM dbo.trips_clean
GROUP BY hvfhs_license_num;

-- Q2) Trips by hour of day, per company
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    DATEPART(HOUR, pickup_datetime) AS pickup_hour,
    COUNT(*)                        AS trips
FROM dbo.trips_clean
GROUP BY hvfhs_license_num, DATEPART(HOUR, pickup_datetime)
ORDER BY pickup_hour, company;

-- Q3) Average and median wait time per company (wait_seconds NULLs are ignored)
SELECT DISTINCT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    AVG(CAST(wait_seconds AS float)) OVER (PARTITION BY hvfhs_license_num) / 60.0  AS avg_wait_min,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY wait_seconds)
        OVER (PARTITION BY hvfhs_license_num) / 60.0                               AS median_wait_min
FROM dbo.trips_clean
WHERE wait_seconds IS NOT NULL;

-- Rejected rows by company and reason
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    reject_reason,
    COUNT(*) AS rows_rejected
FROM dbo.trips_rejected
GROUP BY hvfhs_license_num, reject_reason
ORDER BY company, rows_rejected DESC;

-- Q4) Fare per mile per company
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    SUM(base_passenger_fare) / SUM(trip_miles) AS fare_per_mile,
    AVG(base_passenger_fare / trip_miles)       AS avg_of_ratios
FROM dbo.trips_clean
GROUP BY hvfhs_license_num;

-- Q6) Top 3 busiest hours per company
WITH hourly AS (
    SELECT
        CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
        DATEPART(HOUR, pickup_datetime) AS pickup_hour,
        COUNT(*) AS trips
    FROM dbo.trips_clean
    GROUP BY hvfhs_license_num, DATEPART(HOUR, pickup_datetime)
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY company ORDER BY trips DESC) AS rnk
    FROM hourly
)
SELECT company, pickup_hour, trips, rnk
FROM ranked
WHERE rnk <= 3
ORDER BY company, rnk;

-- Do zero-fare (Lyft) and negative-fare (Uber) rows look alike?
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    reject_reason,
    COUNT(*)                   AS rows_rejected,
    AVG(trip_miles)            AS avg_miles,
    AVG(driver_pay)            AS avg_driver_pay,
    AVG(tips)                  AS avg_tips
FROM dbo.trips_rejected
WHERE reject_reason IN ('zero_fare', 'negative_fare')
GROUP BY hvfhs_license_num, reject_reason;

-- wait_seconds sanity check
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                                             AS total_rows,
    SUM(CASE WHEN wait_seconds IS NULL THEN 1 ELSE 0 END) AS null_wait,
    MIN(wait_seconds)                                    AS min_wait_sec,
    MAX(wait_seconds)                                    AS max_wait_sec,
    SUM(CASE WHEN wait_seconds > 3600 THEN 1 ELSE 0 END)  AS over_1h,
    SUM(CASE WHEN wait_seconds > 7200 THEN 1 ELSE 0 END)  AS over_2h
FROM dbo.trips_clean
GROUP BY hvfhs_license_num;

-- Q5) Top 10 pickup zones per company
WITH zone_counts AS (
    SELECT
        CASE t.hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
        z.Borough,
        z.Zone,
        COUNT(*) AS trips
    FROM dbo.trips_clean t
    JOIN dbo.taxi_zones z ON z.LocationID = t.PULocationID
    GROUP BY t.hvfhs_license_num, z.Borough, z.Zone
),
ranked AS (
    SELECT *,
           RANK() OVER (PARTITION BY company ORDER BY trips DESC) AS rnk,
           100.0 * trips / SUM(trips) OVER (PARTITION BY company) AS pct_of_company
    FROM zone_counts
)
SELECT company, rnk, Borough, Zone, trips, ROUND(pct_of_company, 2) AS pct_of_company
FROM ranked
WHERE rnk <= 10
ORDER BY company, rnk;



SELECT COUNT(*) AS unmatched
FROM dbo.trips_clean t
LEFT JOIN dbo.taxi_zones z ON z.LocationID = t.PULocationID
WHERE z.LocationID IS NULL;

-- Q5b) Share of pickups by borough, within each company
SELECT
    CASE t.hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    z.Borough,
    COUNT(*) AS trips,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY t.hvfhs_license_num), 2) AS pct_of_company
FROM dbo.trips_clean t
JOIN dbo.taxi_zones z ON z.LocationID = t.PULocationID
GROUP BY t.hvfhs_license_num, z.Borough
ORDER BY company, trips DESC;

SELECT LocationID, Borough, Zone FROM dbo.taxi_zones WHERE Borough IS NULL;

SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                                              AS total_rows,
    SUM(CASE WHEN wait_seconds IS NULL THEN 1 ELSE 0 END) AS null_wait,
    MIN(wait_seconds)                                     AS min_wait_sec,
    MAX(wait_seconds)                                     AS max_wait_sec,
    SUM(CASE WHEN wait_seconds > 3600 THEN 1 ELSE 0 END)  AS over_1h
FROM dbo.trips_clean
GROUP BY hvfhs_license_num;

-- Q7) Trips per weekday (1 = Monday) and each company's share within that day, to see if Uber's share differs on weekdays vs weekends.
SELECT
    ((DATEPART(WEEKDAY, pickup_datetime) + @@DATEFIRST - 2) % 7) + 1 AS weekday_no,
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*) AS trips,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (
        PARTITION BY ((DATEPART(WEEKDAY, pickup_datetime) + @@DATEFIRST - 2) % 7) + 1
    ), 2) AS share_in_day
FROM dbo.trips_clean
GROUP BY
    ((DATEPART(WEEKDAY, pickup_datetime) + @@DATEFIRST - 2) % 7) + 1,
    hvfhs_license_num
ORDER BY weekday_no, company;

-- Q8) Driver pay relative to base passenger fare (a rough ratio, not the company's commission) and how often riders tip.
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    SUM(driver_pay) / SUM(base_passenger_fare)           AS driver_pay_to_fare_ratio,
    AVG(tips)                                            AS avg_tip,
    100.0 * AVG(CASE WHEN tips > 0 THEN 1.0 ELSE 0 END)  AS pct_trips_with_tip
FROM dbo.trips_clean
GROUP BY hvfhs_license_num;

-- Q9) Per pickup borough and company: trips, average wait, average trip length and fare per mile, to check whether Q1/Q3 gaps come from geography.
SELECT
    z.Borough,
    CASE t.hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                                          AS trips,
    AVG(t.wait_seconds * 1.0) / 60.0                  AS avg_wait_min,
    AVG(t.trip_miles * 1.0)                           AS avg_miles,
    SUM(t.base_passenger_fare) / SUM(t.trip_miles)    AS fare_per_mile
FROM dbo.trips_clean t
JOIN dbo.taxi_zones z ON z.LocationID = t.PULocationID
WHERE z.Borough IS NOT NULL
GROUP BY z.Borough, t.hvfhs_license_num
ORDER BY z.Borough, company;

-- Q10) Airport pickups per company: trip count, share of the company's trips, average fare, miles, fare per mile and wait.
SELECT
    z.Zone AS airport,
    CASE t.hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                                          AS trips,
    AVG(t.base_passenger_fare)                        AS avg_fare,
    AVG(t.trip_miles * 1.0)                           AS avg_miles,
    SUM(t.base_passenger_fare) / SUM(t.trip_miles)    AS fare_per_mile,
    AVG(t.wait_seconds * 1.0) / 60.0                  AS avg_wait_min
FROM dbo.trips_clean t
JOIN dbo.taxi_zones z ON z.LocationID = t.PULocationID
WHERE z.Zone IN ('JFK Airport', 'LaGuardia Airport', 'Newark Airport')
GROUP BY z.Zone, t.hvfhs_license_num
ORDER BY z.Zone, company;

-- Stage 8 input) Count, mean and standard deviation of fare, miles and wait per company, to compute a confidence interval and effect size for the Uber-Lyft differences.
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                         AS n,
    AVG(base_passenger_fare)         AS mean_fare,
    STDEV(base_passenger_fare)       AS sd_fare,
    AVG(trip_miles * 1.0)            AS mean_miles,
    STDEV(trip_miles * 1.0)          AS sd_miles,
    AVG(wait_seconds * 1.0) / 60.0   AS mean_wait_min,
    STDEV(wait_seconds * 1.0) / 60.0 AS sd_wait_min
FROM dbo.trips_clean
GROUP BY hvfhs_license_num;