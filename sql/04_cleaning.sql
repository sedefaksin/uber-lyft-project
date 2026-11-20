
USE mobility;
GO

-- 1) One view holds all cleaning rules (single source of truth)
CREATE OR ALTER VIEW dbo.v_trips_flagged AS
SELECT
    r.*,
    CASE
        WHEN base_passenger_fare < 0  THEN 'negative_fare'
        WHEN base_passenger_fare = 0  THEN 'zero_fare'
        WHEN trip_miles <= 0          THEN 'zero_or_negative_miles'
        WHEN trip_miles > 100         THEN 'over_100_miles'
        WHEN trip_time <= 0           THEN 'zero_or_negative_duration'
        WHEN trip_time > 21600        THEN 'over_6_hours'
    END AS reject_reason
FROM dbo.trips_raw AS r;
GO

-- 2) Rejected rows, with the reason
DROP TABLE IF EXISTS dbo.trips_rejected;
GO
SELECT *
INTO dbo.trips_rejected
FROM dbo.v_trips_flagged
WHERE reject_reason IS NOT NULL;
GO

-- 3) Clean rows, plus wait_seconds
--    wait_seconds is NULL when pickup is before the request (data issue)
DROP TABLE IF EXISTS dbo.trips_clean;
GO
SELECT
    f.*,
    CASE WHEN pickup_datetime >= request_datetime
         THEN DATEDIFF(SECOND, request_datetime, pickup_datetime)
    END AS wait_seconds
INTO dbo.trips_clean
FROM dbo.v_trips_flagged AS f
WHERE reject_reason IS NULL;
GO

-- 4) Reconciliation: clean + rejected must equal raw
SELECT
    (SELECT COUNT(*) FROM dbo.trips_raw)      AS raw_rows,
    (SELECT COUNT(*) FROM dbo.trips_clean)    AS clean_rows,
    (SELECT COUNT(*) FROM dbo.trips_rejected) AS rejected_rows;
GO

-- 5) Why rows were rejected
SELECT reject_reason, COUNT(*) AS rows_rejected
FROM dbo.trips_rejected
GROUP BY reject_reason
ORDER BY rows_rejected DESC;
GO

-- Sanity check for wait_seconds
SELECT
    COUNT(*)                                          AS clean_rows,
    SUM(CASE WHEN wait_seconds IS NULL THEN 1 ELSE 0 END) AS null_wait,
    MIN(wait_seconds)                                 AS min_wait_sec,
    AVG(CAST(wait_seconds AS float))                  AS avg_wait_sec,
    MAX(wait_seconds)                                 AS max_wait_sec
FROM dbo.trips_clean;

ALTER TABLE dbo.trips_clean DROP COLUMN reject_reason;