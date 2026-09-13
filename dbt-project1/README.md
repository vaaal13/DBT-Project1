# Sales Analytics with dbt and Databricks

I built this project to practice turning raw sales data into useful reporting tables with dbt and Databricks. It covers data cleaning, joins, incremental updates, aggregations, testing, and scheduled execution through GitHub Actions.

The data is synthetic. There are no real customer records.

## Data flow

```text
Uploaded CSVs → Source tables → Bronze → Silver → Gold
```

All tables are stored in the Databricks catalog `dbt_source_1`.

| Schema | Purpose |
|---|---|
| `default` | Raw tables uploaded from CSV files |
| `bronze_layer` | Copies of the source tables managed by dbt |
| `silver_layer` | Cleaned sales records joined with customer, product, and location details |
| `gold_layer` | Sales summaries by date, location, sales channel, and currency |

## Sample data

The starting dataset contains fictional US retail transactions from 2025. All monetary amounts are in USD.

| Source table | Initial rows |
|---|---:|
| `fact_sales` | 1,000 sales lines across 500 orders |
| `dim_customers` | 100 |
| `dim_products` | 30 |
| `dim_location` | 10 |

The CSV files are not currently included in this repository. Running the project requires compatible source tables in Databricks.

## Models

### Bronze

Four models read the source tables:

- `dim_customers`
- `dim_products`
- `dim_location`
- `dim_sales`

Despite its name, `dim_sales` contains sales transaction lines from the `fact_sales` source table.

### Silver

`flat_schema` joins the four bronze models into one table, with one row per `sale_id`.

It handles:

- Trimming whitespace and standardizing IDs.
- Converting email addresses to lowercase.
- Converting blank descriptive fields to null.
- Casting dates, quantities, and monetary values.
- Joining customer, product, and location details to each sale.
- Calculating gross sales, net sales, cost of goods sold, and gross profit.

The model uses an incremental `merge` on `sale_id`. New sales are inserted, and existing sales are updated with current values.

This is Type 1-style overwrite behavior. Historical versions are not retained.

### Gold

`gold_dataset` groups silver records by date, location, sales channel, and currency.

The output includes:

- Sales line count
- Distinct order and customer counts
- Units sold
- Gross sales and discounts
- Net sales
- Cost of goods sold
- Gross profit
- Average order value
- Gross margin percentage

The gold table is rebuilt on each run.

## Project structure

```text
.
├── .github/
│   └── workflows/
│       └── dbt.yml
├── .gitignore
└── dbt-project1/
    ├── README.md
    ├── dbt_project.yml
    ├── packages.yml
    ├── package-lock.yml
    ├── macros/
    │   ├── cents_to_dollars.sql
    │   └── generate_schema_name.sql
    ├── models/
    │   ├── source/
    │   │   └── source.yml
    │   ├── bronze/
    │   │   ├── dim_customers.sql
    │   │   ├── dim_products.sql
    │   │   ├── dim_location.sql
    │   │   ├── dim_sales.sql
    │   │   └── schema.yml
    │   ├── silver/
    │   │   ├── flat_schema.sql
    │   │   └── schema.yml
    │   └── gold/
    │       └── gold_dataset.sql
    └── tests/
        └── reconcile_net_sales.sql
```

## Local setup

The project uses dbt Fusion `2.0.0-preview.218` and a Databricks SQL warehouse.

Before running:

1. Create the Databricks catalog `dbt_source_1`.
2. Load the four source tables into its `default` schema.
3. Configure a profile named `dbt_project1` in `~/.dbt/profiles.yml`.
4. Set the profile’s database to `dbt_source_1` and schema to `bronze_layer`.
5. Authenticate with an account that can use the SQL warehouse, read the source tables, and create or update the output tables.

Connection credentials are kept outside the repository.

From the repository root:

```bash
cd dbt-project1
dbt --version
dbt deps
dbt debug
dbt build
```

Check that `dbt --version` reports Fusion. `dbt build` runs models and tests in dependency order.

To run the models without tests:

```bash
dbt run --select +gold_dataset
```

The leading `+` includes the upstream bronze and silver models.

To inspect the gold output in Databricks:

```sql
SELECT *
FROM dbt_source_1.gold_layer.gold_dataset
ORDER BY sale_date DESC, net_sales_amount DESC;
```

## Data tests

There are 15 data tests in the project.

| Check | Tests |
|---|---:|
| Bronze customer, product, and location IDs are unique and non-null | 6 |
| Silver sales IDs are unique and non-null | 2 |
| Silver customer, product, and location IDs are non-null | 3 |
| Silver customer, product, and location IDs exist in their bronze dimensions | 3 |
| Net sales totals match across bronze, silver, and gold by currency | 1 |

The reconciliation test compares revenue across all three layers. It also checks for missing revenue inputs and currencies missing from a layer.

All 15 tests have passed locally, and the GitHub Actions build has completed successfully.

To test existing tables:

```bash
dbt test
```

To run only the revenue check:

```bash
dbt test --select reconcile_net_sales
```

Matching totals do not prove that every individual transaction is correct. These checks cover specific assumptions about the data.

## GitHub Actions

The workflow is defined in `.github/workflows/dbt.yml`.

It:

1. Checks out the repository.
2. Installs Fusion `2.0.0-preview.218`.
3. Creates a connection profile on the GitHub runner.
4. Installs dbt package dependencies.
5. Runs `dbt build`.

The daily schedule is 8:00 AM Philippine time, equivalent to 00:00 UTC:

```yaml
on:
  workflow_dispatch:
  schedule:
    - cron: '0 0 * * *'
```

The schedule takes effect when this configuration is pushed to the default branch. GitHub may delay scheduled runs during busy periods.

The workflow can also be started manually from:

**Actions → Build dbt pipeline → Run workflow**

### Repository settings

Configure these under **Settings → Secrets and variables → Actions**:

| Name | Type | Value |
|---|---|---|
| `DATABRICKS_TOKEN` | Secret | Databricks personal access token |
| `DATABRICKS_HOST` | Variable | Workspace hostname without `https://` |
| `DATABRICKS_HTTP_PATH` | Variable | SQL warehouse HTTP path |

The token is supplied at runtime and is not stored in the workflow file. It must remain valid for scheduled runs to connect.

The workflow updates the same Databricks tables used locally. It runs on GitHub’s infrastructure, so the local computer does not need to stay on.

Raw CSV ingestion is still manual. The workflow processes the data already available in the source tables.

## Current limitations

- The sample data has no reliable update timestamp, so silver reads all bronze rows on each run.
- Source deletions are not automatically removed from the incremental silver table.
- Changes to customer, product, or location details overwrite those attributes on existing silver sales rows.
- SCD Type 2 history is not implemented.
- Output schemas are fixed for this learning environment.
- Scheduled GitHub workflows in public repositories can be disabled after 60 days without repository activity.

Distinct customer and order counts should not be summed across groups where the same customer or order may appear more than once. Overall average order value and gross margin should be recalculated from their underlying totals.

## Next steps

- Explore SCD Type 2 snapshots.
- Add checks for individual sales calculations and invalid values.
- Automate raw data ingestion.
- Build a dashboard from the gold tables.