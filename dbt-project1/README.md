# Sales Analytics with dbt and Databricks

A learning project that transforms synthetic retail sales data into reporting tables using dbt and Databricks.

The pipeline follows a bronze, silver, and gold architecture, with SQL models for source ingestion, data cleaning, joins, incremental upserts, and aggregation.

## Architecture

```text
Uploaded CSVs → Source tables → Bronze → Silver → Gold
                  default     bronze_layer  silver_layer  gold_layer
```

All layers are stored in the Databricks catalog `dbt_source_1`.

| Layer | Purpose |
|---|---|
| Source — `default` | Tables created from uploaded CSV files |
| Bronze — `bronze_layer` | Copies the source tables into dbt-managed models |
| Silver — `silver_layer` | Cleans and joins sales, customers, products, and locations |
| Gold — `gold_layer` | Summarizes sales by date, location, sales channel, and currency |

## Sample Data

The initial dataset contains fictional US retail transactions from 2025. All monetary amounts are in USD.

| Source table | Initial rows |
|---|---:|
| `fact_sales` | 1,000 sales lines across 500 orders |
| `dim_customers` | 100 |
| `dim_products` | 30 |
| `dim_location` | 10 |

The data is synthetic and contains no real customer records.

## Transformations

### Bronze

Four models read the uploaded source tables:

- `dim_customers`
- `dim_products`
- `dim_location`
- `dim_sales`

Despite its name, `dim_sales` contains sales transaction lines sourced from `fact_sales`.

### Silver

`flat_schema` combines the four bronze models into one table with one row per `sale_id`.

Transformations include:

- Trimming whitespace and standardizing identifier casing.
- Converting email addresses to lowercase.
- Converting blank descriptive fields to null.
- Casting dates, quantities, and monetary values.
- Joining customer, product, and location attributes to sales.
- Calculating gross sales, net sales, cost of goods sold, and gross profit.

The model uses an incremental `merge` strategy keyed by `sale_id`. New sales are inserted, and matching rows are updated with current values.

This provides Type 1-style overwrite behavior. Historical versions are not retained.

### Gold

`gold_dataset` aggregates the silver data by date, location, sales channel, and currency.

Metrics include:

- Sales line count
- Distinct orders and customers
- Units sold
- Gross sales and discounts
- Net sales
- Cost of goods sold
- Gross profit
- Average order value
- Gross margin percentage

The gold table is rebuilt on each run to reflect the current silver data.

## Project Structure

```text
dbtproject/
├── .gitignore
└── dbt-project1/
    ├── dbt_project.yml
    ├── packages.yml
    ├── package-lock.yml
    ├── README.md
    ├── macros/
    │   └── generate_schema_name.sql
    └── models/
        ├── source/
        │   └── source.yml
        ├── bronze/
        │   ├── dim_customers.sql
        │   ├── dim_products.sql
        │   ├── dim_location.sql
        │   └── dim_sales.sql
        ├── silver/
        │   └── flat_schema.sql
        └── gold/
            └── gold_dataset.sql
```

## Setup

This project was developed using dbt Fusion `2.0.0-preview.218` and a Databricks SQL warehouse.

To run it:

1. Set up a Databricks workspace, SQL warehouse, and the required catalog.
2. Load compatible source data into the four tables in `dbt_source_1.default`.
3. Configure a local dbt connection profile named `dbt_project1` in `~/.dbt/profiles.yml`.
4. Set the profile’s target catalog/database to `dbt_source_1` and target schema to `bronze_layer`.
5. Authenticate and ensure your account can read the source tables and create the output schemas, tables, and views.

Connection credentials are configured locally and should not be committed to Git.

The CSV files are not currently included in this repository. The SQL models show the source columns required to reproduce the pipeline.

## Running the Pipeline

From the repository root:

```bash
cd dbt-project1
dbt deps
dbt debug
dbt run --select +gold_dataset
```

The leading `+` includes the upstream bronze and silver models.

To inspect the final result in Databricks:

```sql
SELECT *
FROM dbt_source_1.gold_layer.gold_dataset
ORDER BY sale_date DESC, net_sales_amount DESC;
```

## Current Limitations

- CSV ingestion is manual.
- Runs are triggered manually; scheduling and CI/CD are not configured.
- Silver reads all current bronze rows on each run because the sample data has no reliable update timestamp.
- Source deletions are not automatically removed from the incremental silver table.
- Dimension changes update existing sales rows with current attributes; attributes as they existed at the original sale date are not preserved.
- Sales IDs must be unique and non-null, and dimension join keys must be unique. Automated data tests are not yet implemented.
- Schema naming uses fixed `silver_layer` and `gold_layer` destinations for this learning environment.

Distinct customer counts should not be summed across reporting groups. Overall average order value and margin should be recalculated from their underlying totals.

## Planned Improvements

- Add dbt tests for keys, relationships, and revenue reconciliation.
- Automate pipeline execution with GitHub Actions or Databricks Jobs.
- Configure authentication for unattended runs.
- Explore SCD Type 2 snapshots to retain changes over time.
- Build dashboards from the gold layer.