# Sales Analytics with dbt and Databricks

I built this project to practice taking raw sales data through bronze, silver, and gold layers in Databricks using dbt. It covers cleaning data, joining tables, updating existing records, and producing sales summaries.

The project uses synthetic retail data. There are no real customer records.

## How the data flows

```text
Uploaded CSVs → Bronze → Silver → Gold
```

All tables live in the `dbt_source_1` catalog:

| Schema | What it contains |
|---|---|
| `default` | Raw tables uploaded from CSV files |
| `bronze_layer` | Four dbt models that copy the raw tables |
| `silver_layer` | Cleaned sales data joined with customer, product, and location details |
| `gold_layer` | Sales summaries by date, location, sales channel, and currency |

The starting dataset contains 1,000 sales lines across 500 orders, 100 customers, 30 products, and 10 locations. Transactions cover 2025 and use USD.

## What the models do

**Bronze** reads the four source tables. The model named `dim_sales` reads `fact_sales`; despite the name, it contains sales transactions.

**Silver** combines those models into `flat_schema`, with one row per `sale_id`. It trims whitespace, standardizes IDs and email addresses, handles blank descriptive fields, and casts dates and numeric values. It also calculates gross sales, net sales, cost of goods sold, and gross profit.

Silver uses an incremental merge on `sale_id`. New IDs are inserted, and existing IDs are updated. This gives Type 1-style overwrite behavior; it does not keep historical versions.

**Gold** builds `gold_dataset` from silver. It includes sales line counts, distinct order and customer counts, units sold, revenue, discounts, costs, profit, average order value, and gross margin percentage. This table is rebuilt on each run.

## Running locally

The project uses dbt Fusion `2.0.0-preview.218` and a Databricks SQL warehouse.

Before running:

1. Load the source tables into `dbt_source_1.default`.
2. Configure a profile named `dbt_project1` in `~/.dbt/profiles.yml`.
3. Set its database to `dbt_source_1` and schema to `bronze_layer`.
4. Use an account with access to the warehouse, source tables, and output schemas.

The sample CSV files are not currently included in this repository. Connection credentials are kept outside Git.

From the repository root:

```bash
cd dbt-project1
dbt deps
dbt debug
dbt build
```

`dbt build` runs the models and their tests in dependency order.

To view the gold output:

```sql
SELECT *
FROM dbt_source_1.gold_layer.gold_dataset
ORDER BY sale_date DESC, net_sales_amount DESC;
```

## Data checks

The project now has 15 data tests:

| Checks | Tests |
|---|---:|
| Bronze customer, product, and location IDs are unique and non-null | 6 |
| Silver sales IDs are unique and non-null | 2 |
| Silver customer, product, and location IDs are non-null and exist in their bronze dimensions | 6 |
| Net sales totals match across bronze, silver, and gold by currency | 1 |

All 15 have passed locally across the test runs.

The reconciliation test also checks for missing revenue inputs and currencies missing from a layer. Matching totals are useful, but they do not prove every individual transaction is correct.

To run just the tests against existing tables:

```bash
dbt test
```

## GitHub Actions

A manual workflow is defined in `.github/workflows/dbt.yml`. It installs the same Fusion version used locally, creates a connection profile on the GitHub runner, installs project dependencies, and runs `dbt build`.

It uses these repository settings:

| Setting | Type |
|---|---|
| `DATABRICKS_TOKEN` | Secret |
| `DATABRICKS_HOST` | Variable |
| `DATABRICKS_HTTP_PATH` | Variable |

After the workflow is pushed to the default branch, it can be started from **Actions → Build dbt pipeline → Run workflow**.

The workflow updates the same Databricks tables used locally. Its first GitHub run is still pending. There is no schedule or automatic push trigger yet.

## Current limitations

- CSV uploads are manual.
- Silver reads all bronze rows on each run because the source data has no reliable update timestamp.
- Source deletions are not automatically removed from silver.
- Changes to customer, product, or location details overwrite the attributes on existing silver sales rows. SCD Type 2 history is not implemented.
- Output schemas are fixed for this learning environment.

Distinct customer and order counts should not be added across groups where the same customer or order can appear more than once. Overall averages and margins should be calculated from the underlying totals.

## Next steps

- Verify the GitHub Actions workflow and add a schedule.
- Explore SCD Type 2 snapshots.
- Automate raw data ingestion.
- Build a dashboard using the gold tables.