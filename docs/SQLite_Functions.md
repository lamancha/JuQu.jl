# JuQu SQLite Database Functions

This document describes the SQLite database functions added to the JuQu.jl package for working with experiment tracking databases.

## Overview

The JuQu module now provides comprehensive functions for:
- Opening and closing SQLite database connections
- Executing SQL queries and statements
- Accessing experiment and run data
- Retrieving result data from dynamically created tables
- Performing common database operations

## Database Schema

The functions are designed to work with databases having this structure:

### Core Tables
- **experiments**: Contains experiment metadata (exp_id, name, sample_name, timestamps, etc.)
- **runs**: Contains run information linked to experiments (run_id, exp_id, result_table_name, etc.)
- **layouts**: Contains parameter layout information for runs
- **dependencies**: Contains dependency relationships between parameters

### Result Tables
- **results-X-Y**: Dynamically created tables storing actual measurement data
  - X corresponds to experiment ID
  - Y corresponds to run counter
  - Contains measurement columns specific to each experiment

## Core Functions

### Database Connection Management

```julia
# Open a database connection
db = open_database("path/to/database.db")

# Close the current connection
close_database()

# Get the current connection (for advanced usage)
conn = get_connection()
```

### Query Execution

```julia
# Execute a SELECT query and get DataFrame results
results = execute_query("SELECT * FROM experiments LIMIT 5")

# Execute statements that don't return data (INSERT, UPDATE, etc.)
execute_statement("UPDATE runs SET is_completed = 1 WHERE run_id = 42")
```

## High-Level Query Functions

### Experiment Queries

```julia
# Get all experiments
experiments = get_all_experiments()

# Get specific experiment by ID
exp = get_experiment_by_id(1)

# Search experiments by name pattern
results = get_experiments_by_name("test")

# Get experiment summary with statistics
summary = get_experiment_summary()
```

### Run Queries

```julia
# Get recent runs (last 100 by default)
runs = get_all_runs(100)

# Get runs for specific experiment
exp_runs = get_runs_by_experiment(1)

# Get specific run by ID
run = get_run_by_id(42)

# Get only completed runs
completed = get_completed_runs()

# Get runs from last N hours
recent = get_recent_runs(24)
```

### Result Data Access

```julia
# Get data from specific result table
data = get_result_data("results-1-5", 1000)

# Get result data for specific run (automatically finds table)
run_data = get_result_data_by_run_id(42, 500)

# Get layout information for a run
layouts = get_layouts_for_run(42)
```

### Utility Functions

```julia
# List all tables in database
all_tables = list_all_tables()

# List only result tables
result_tables = list_result_tables()

# Get table structure information
table_info = get_table_info("experiments")

# Search runs by GUID pattern
guid_results = search_runs_by_guid("abc123")
```

## Usage Examples

### Basic Usage Pattern

```julia
using JuQu

# Open database
open_database("test/test.db")

# Get experiment overview
experiments = get_all_experiments()
println("Found $(nrow(experiments)) experiments")

# Get runs for first experiment
if nrow(experiments) > 0
    exp_id = experiments.exp_id[1]
    runs = get_runs_by_experiment(exp_id)
    println("Experiment $(exp_id) has $(nrow(runs)) runs")
    
    # Get result data for first completed run
    completed_runs = filter(row -> row.is_completed == 1, runs)
    if nrow(completed_runs) > 0
        run_id = completed_runs.run_id[1]
        results = get_result_data_by_run_id(run_id)
        println("Retrieved $(nrow(results)) data points")
    end
end

# Close database when done
close_database()
```

### Custom Query Example

```julia
using JuQu

open_database("test/test.db")

# Custom query to find experiments with most runs
query = """
SELECT 
    e.name as experiment_name,
    COUNT(r.run_id) as total_runs,
    SUM(CASE WHEN r.is_completed = 1 THEN 1 ELSE 0 END) as completed_runs
FROM experiments e
LEFT JOIN runs r ON e.exp_id = r.exp_id
GROUP BY e.exp_id, e.name
ORDER BY total_runs DESC
LIMIT 10;
"""

results = execute_query(query)
println(results)

close_database()
```

### Data Analysis Example

```julia
using JuQu
using Statistics

open_database("test/test.db")

# Get result tables and analyze data
result_tables = list_result_tables()

for table_name in result_tables[1:5]  # Analyze first 5 tables
    data = get_result_data(table_name, 1000)
    
    # Analyze numeric columns
    for col in names(data)
        if col != "id" && eltype(data[!, col]) <: Number
            values = filter(x -> !ismissing(x), data[!, col])
            if length(values) > 0
                println("$table_name.$col: μ=$(round(mean(values), digits=3)), σ=$(round(std(values), digits=3))")
            end
        end
    end
end

close_database()
```

## Generic SQL Query Templates

Here are some useful SQL patterns that can be adapted for your specific needs:

### 1. Count Records by Category
```sql
SELECT category_column, COUNT(*) as count
FROM table_name
GROUP BY category_column
ORDER BY count DESC;
```

### 2. Find Records in Date Range
```sql
SELECT *
FROM table_name
WHERE timestamp_column BETWEEN start_timestamp AND end_timestamp
ORDER BY timestamp_column;
```

### 3. Join Tables for Related Data
```sql
SELECT t1.*, t2.related_column
FROM table1 t1
INNER JOIN table2 t2 ON t1.id = t2.foreign_key_id
WHERE some_condition;
```

### 4. Aggregate Statistics
```sql
SELECT 
    MIN(numeric_column) as minimum,
    MAX(numeric_column) as maximum,
    AVG(numeric_column) as average,
    COUNT(*) as total_count
FROM table_name
WHERE some_condition;
```

### 5. Conditional Aggregation
```sql
SELECT 
    category,
    SUM(CASE WHEN condition = 'value1' THEN 1 ELSE 0 END) as count_value1,
    SUM(CASE WHEN condition = 'value2' THEN 1 ELSE 0 END) as count_value2
FROM table_name
GROUP BY category;
```

## Error Handling

The functions include basic error handling and will throw descriptive errors for:
- Database connection failures
- Invalid SQL queries
- Missing tables or data
- Invalid table names (to prevent SQL injection)

Always wrap database operations in try-catch blocks for production code:

```julia
try
    open_database("mydata.db")
    results = get_all_experiments()
    # Process results...
catch e
    println("Database error: $e")
finally
    close_database()  # Ensure connection is closed
end
```

## Dependencies

The SQLite functions require:
- SQLite.jl
- DBInterface.jl  
- DataFrames.jl

These should be added to your Project.toml:

```toml
[deps]
SQLite = "0aa819cd-b072-5ff4-a722-6bc24af294d9"
DBInterface = "a10d1c49-ce27-4219-8d33-6db1a4562965"
DataFrames = "a93c6f00-e57d-5684-b7b6-d8193f3e46c0"
```

## Performance Notes

- Use `LIMIT` clauses for large result tables to avoid memory issues
- The `get_result_data` function defaults to 1000 rows limit
- Close database connections when done to free resources
- Consider using prepared statements for repeated queries (advanced usage)

## Running the Examples

Run the comprehensive examples with:

```bash
julia examples/sqlite_usage_examples.jl
```

This will demonstrate all major functionality using the test database.
