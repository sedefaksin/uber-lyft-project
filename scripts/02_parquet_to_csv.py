import pyarrow.parquet as pq

src = r"C:\data\fhvhv_tripdata_2026-09.parquet"
dst = r"C:\data\trips.csv"

pf = pq.ParquetFile(src)
first = True
done = 0

for batch in pf.iter_batches(batch_size=500_000):
    df = batch.to_pandas()
    df.to_csv(
        dst,
        mode="w" if first else "a",
        header=False,
        index=False,
        lineterminator="\n",
        date_format="%Y-%m-%d %H:%M:%S",
    )
    first = False
    done += len(df)
    print(f"{done:,} rows written")


    