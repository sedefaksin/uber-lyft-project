-- 06_dashboard_views.sql
-- Small aggregated views for Power BI (sums and counts, not averages).
USE mobility;
GO

CREATE OR ALTER VIEW dbo.v_dash_hourly AS
SELECT
    CASE hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    DATEPART(HOUR, pickup_datetime) AS pickup_hour,
    COUNT(*)                        AS trips,
    SUM(base_passenger_fare)        AS total_fare,
    SUM(trip_miles)                 AS total_miles
FROM dbo.trips_clean
GROUP BY hvfhs_license_num, DATEPART(HOUR, pickup_datetime);
GO

CREATE OR ALTER VIEW dbo.v_dash_borough AS
SELECT
    z.Borough,
    CASE t.hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                                AS trips,
    SUM(t.base_passenger_fare)              AS total_fare,
    SUM(t.trip_miles)                       AS total_miles,
    COUNT(t.wait_seconds)                   AS wait_trips,
    SUM(CAST(t.wait_seconds AS bigint))     AS total_wait_seconds
FROM dbo.trips_clean t
JOIN dbo.taxi_zones z ON z.LocationID = t.PULocationID
WHERE z.Borough IS NOT NULL
GROUP BY z.Borough, t.hvfhs_license_num;
GO

CREATE OR ALTER VIEW dbo.v_dash_airport AS
SELECT
    z.Zone AS airport,
    CASE t.hvfhs_license_num WHEN 'HV0003' THEN 'Uber' WHEN 'HV0005' THEN 'Lyft' END AS company,
    COUNT(*)                                AS trips,
    SUM(t.base_passenger_fare)              AS total_fare,
    SUM(t.trip_miles)                       AS total_miles,
    COUNT(t.wait_seconds)                   AS wait_trips,
    SUM(CAST(t.wait_seconds AS bigint))     AS total_wait_seconds
FROM dbo.trips_clean t
JOIN dbo.taxi_zones z ON z.LocationID = t.PULocationID
WHERE z.Zone IN ('JFK Airport', 'LaGuardia Airport')
GROUP BY z.Zone, t.hvfhs_license_num;
GO

SELECT * FROM dbo.v_dash_borough;          -- should return 10 rows
SELECT SUM(trips) FROM dbo.v_dash_hourly;  -- 20966979 gelmeli