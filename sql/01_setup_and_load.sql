GO
USE mobility;
GO
SELECT DB_NAME() AS aktif_veritabani;

-- Create tables
CREATE TABLE dbo.trips_raw (
    hvfhs_license_num     varchar(10),
    dispatching_base_num  varchar(10),
    originating_base_num  varchar(10),
    request_datetime      datetime2(0),
    on_scene_datetime     datetime2(0),
    pickup_datetime       datetime2(0),
    dropoff_datetime      datetime2(0),
    PULocationID          int,
    DOLocationID          int,
    trip_miles            float,
    trip_time             int,
    base_passenger_fare   decimal(10,2),
    tolls                 decimal(10,2),
    bcf                   decimal(10,2),
    sales_tax             decimal(10,2),
    congestion_surcharge  decimal(10,2),
    airport_fee           decimal(10,2),
    tips                  decimal(10,2),
    driver_pay            decimal(10,2),
    shared_request_flag   char(1),
    shared_match_flag     char(1),
    access_a_ride_flag    char(1),
    wav_request_flag      char(1),
    wav_match_flag        char(1),
    cbd_congestion_fee    decimal(10,2)
);

-- Load data
BULK INSERT dbo.trips_raw
FROM 'C:\data\trips.csv'
WITH (
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',
    KEEPNULLS,
    TABLOCK,
    BATCHSIZE = 1000000
);

SELECT COUNT(*) AS satir_sayisi FROM dbo.trips_raw;