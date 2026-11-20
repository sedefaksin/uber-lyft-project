import pyodbc
print(pyodbc.drivers())

import pyarrow.parquet as pq

pf = pq.ParquetFile(r"C:\data\fhvhv_tripdata_2026-09.parquet")
print(pf.metadata.num_rows)
print(pf.schema_arrow)