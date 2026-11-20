from pathlib import Path
import pandas as pd

ROOT = Path(__file__).resolve().parent.parent

z = pd.read_csv(ROOT / "data" / "taxi_zone_lookup.csv")

def q(v):
    if pd.isna(v):
        return "NULL"
    return "N'" + str(v).replace("'", "''") + "'"

lines = [
    "DROP TABLE IF EXISTS dbo.taxi_zones;",
    "CREATE TABLE dbo.taxi_zones (LocationID INT, Borough NVARCHAR(50), Zone NVARCHAR(100), service_zone NVARCHAR(50));",
]
for r in z.itertuples(index=False):
    lines.append(
        f"INSERT INTO dbo.taxi_zones VALUES ({int(r.LocationID)}, {q(r.Borough)}, {q(r.Zone)}, {q(r.service_zone)});"
    )

with open(ROOT / "sql" / "02_load_taxi_zones.sql", "w", encoding="utf-8-sig") as f:
    f.write("\n".join(lines))

print(len(z), "rows written")