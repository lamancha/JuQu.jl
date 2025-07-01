module JuQu

    using SQLite
    using DBInterface
    using DataFrames
    using Dates

    # Global variable to store database connection
    const DB_CONNECTION = Ref{Union{SQLite.DB, Nothing}}(nothing)

    """
        open_database(db_path::String) -> SQLite.DB
    
    Open a SQLite database connection and store it globally.
    Returns the database connection object.
    """
    function open_database(db_path::String)
        try
            db = SQLite.DB(db_path)
            DB_CONNECTION[] = db
            println("Database opened successfully: $db_path")
            return db
        catch e
            error("Failed to open database $db_path: $e")
        end
    end

    """
        close_database()
    
    Close the current database connection.
    """
    function close_database()
        if DB_CONNECTION[] !== nothing
            DBInterface.close!(DB_CONNECTION[])
            DB_CONNECTION[] = nothing
            println("Database connection closed.")
        else
            println("No database connection to close.")
        end
    end

    """
        get_connection() -> SQLite.DB
    
    Get the current database connection. Throws an error if no connection exists.
    """
    function get_connection()
        if DB_CONNECTION[] === nothing
            error("No database connection. Please call open_database() first.")
        end
        return DB_CONNECTION[]
    end

    """
        execute_query(query::String; db=nothing) -> DataFrame
    
    Execute a SQL query and return results as a DataFrame.
    If db is not provided, uses the global connection.
    """
    function execute_query(query::String; db=nothing)
        connection = db === nothing ? get_connection() : db
        try
            result = DBInterface.execute(connection, query) |> DataFrame
            return result
        catch e
            error("Failed to execute query: $e\nQuery: $query")
        end
    end

    """
        execute_statement(statement::String; db=nothing) -> Nothing
    
    Execute a SQL statement (INSERT, UPDATE, DELETE, CREATE, etc.) that doesn't return results.
    If db is not provided, uses the global connection.
    """
    function execute_statement(statement::String; db=nothing)
        connection = db === nothing ? get_connection() : db
        try
            DBInterface.execute(connection, statement)
            println("Statement executed successfully.")
        catch e
            error("Failed to execute statement: $e\nStatement: $statement")
        end
    end

    # =============================================================================
    # GENERIC SQL QUERY TEMPLATES
    # =============================================================================

    """
        get_all_experiments() -> DataFrame
    
    Retrieve all experiments from the database.
    """
    function get_all_experiments()
        query = "SELECT * FROM experiments ORDER BY exp_id;"
        return execute_query(query)
    end

    """
        get_experiment_by_id(exp_id::Int) -> DataFrame
    
    Retrieve a specific experiment by its ID.
    """
    function get_experiment_by_id(exp_id::Int)
        query = "SELECT * FROM experiments WHERE exp_id = $exp_id;"
        return execute_query(query)
    end

    """
        get_experiments_by_name(name_pattern::String) -> DataFrame
    
    Retrieve experiments matching a name pattern (uses LIKE operator).
    """
    function get_experiments_by_name(name_pattern::String)
        query = "SELECT * FROM experiments WHERE name LIKE '%$name_pattern%' ORDER BY exp_id;"
        return execute_query(query)
    end

    """
        get_all_runs(limit::Int=100) -> DataFrame
    
    Retrieve all runs from the database with optional limit.
    """
    function get_all_runs(limit::Int=100)
        query = "SELECT * FROM runs ORDER BY run_id DESC LIMIT $limit;"
        return execute_query(query)
    end

    """
        get_runs_by_experiment(exp_id::Int) -> DataFrame
    
    Retrieve all runs for a specific experiment.
    """
    function get_runs_by_experiment(exp_id::Int)
        query = "SELECT * FROM runs WHERE exp_id = $exp_id ORDER BY run_id;"
        return execute_query(query)
    end

    """
        get_run_by_id(run_id::Int) -> DataFrame
    
    Retrieve a specific run by its ID.
    """
    function get_run_by_id(run_id::Int)
        query = "SELECT * FROM runs WHERE run_id = $run_id;"
        return execute_query(query)
    end

    """
        get_completed_runs(exp_id::Union{Int, Nothing}=nothing) -> DataFrame
    
    Retrieve all completed runs, optionally filtered by experiment ID.
    """
    function get_completed_runs(exp_id::Union{Int, Nothing}=nothing)
        if exp_id === nothing
            query = "SELECT * FROM runs WHERE is_completed = 1 ORDER BY completed_timestamp DESC;"
        else
            query = "SELECT * FROM runs WHERE exp_id = $exp_id AND is_completed = 1 ORDER BY completed_timestamp DESC;"
        end
        return execute_query(query)
    end

    """
        get_recent_runs(hours::Int=24) -> DataFrame
    
    Retrieve runs from the last N hours.
    """
    function get_recent_runs(hours::Int=24)
        # Assuming timestamps are Unix timestamps
        cutoff_time = Int(floor(datetime2unix(now()))) - (hours * 3600)
        query = "SELECT * FROM runs WHERE run_timestamp > $cutoff_time ORDER BY run_timestamp DESC;"
        return execute_query(query)
    end

    """
        get_layouts_for_run(run_id::Int) -> DataFrame
    
    Retrieve layout information for a specific run.
    """
    function get_layouts_for_run(run_id::Int)
        query = "SELECT * FROM layouts WHERE run_id = $run_id ORDER BY layout_id;"
        return execute_query(query)
    end

    """
        get_result_data(table_name::String, limit::Int=1000) -> DataFrame
    
    Retrieve data from a specific results table.
    """
    function get_result_data(table_name::String, limit::Int=1000)
        # Sanitize table name to prevent SQL injection
        if !occursin(r"^[a-zA-Z0-9_-]+$", table_name)
            error("Invalid table name: $table_name")
        end
        query = "SELECT * FROM \"$table_name\" ORDER BY id LIMIT $limit;"
        return execute_query(query)
    end

    """
        get_result_data_by_run_id(run_id::Int, limit::Int=1000) -> DataFrame
    
    Retrieve result data for a specific run by looking up its result table name.
    """
    function get_result_data_by_run_id(run_id::Int, limit::Int=1000)
        # First get the result table name
        run_info = get_run_by_id(run_id)
        if nrow(run_info) == 0
            error("Run with ID $run_id not found")
        end
        
        table_name = run_info.result_table_name[1]
        if ismissing(table_name) || table_name == ""
            error("No result table specified for run $run_id")
        end
        
        return get_result_data(table_name, limit)
    end

    """
        list_all_tables() -> Vector{String}
    
    List all tables in the database.
    """
    function list_all_tables()
        query = "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;"
        result = execute_query(query)
        return nrow(result) > 0 ? String.(result.name) : String[]
    end

    """
        list_result_tables() -> Vector{String}
    
    List all result tables (tables starting with 'results-').
    """
    function list_result_tables()
        query = "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE 'results-%' ORDER BY name;"
        result = execute_query(query)
        return nrow(result) > 0 ? String.(result.name) : String[]
    end

    """
        get_table_info(table_name::String) -> DataFrame
    
    Get column information for a specific table.
    """
    function get_table_info(table_name::String)
        # Sanitize table name
        if !occursin(r"^[a-zA-Z0-9_-]+$", table_name)
            error("Invalid table name: $table_name")
        end
        query = "PRAGMA table_info(\"$table_name\");"
        return execute_query(query)
    end

    """
        search_runs_by_guid(guid_pattern::String) -> DataFrame
    
    Search for runs by GUID pattern.
    """
    function search_runs_by_guid(guid_pattern::String)
        query = "SELECT * FROM runs WHERE guid LIKE '%$guid_pattern%' ORDER BY run_timestamp DESC;"
        return execute_query(query)
    end

    """
        get_experiment_summary() -> DataFrame
    
    Get a summary of all experiments with their run counts.
    """
    function get_experiment_summary()
        query = """
        SELECT 
            e.exp_id,
            e.name,
            e.sample_name,
            e.run_counter,
            COUNT(r.run_id) as actual_run_count,
            MIN(r.run_timestamp) as first_run,
            MAX(r.run_timestamp) as last_run,
            SUM(CASE WHEN r.is_completed = 1 THEN 1 ELSE 0 END) as completed_runs
        FROM experiments e
        LEFT JOIN runs r ON e.exp_id = r.exp_id
        GROUP BY e.exp_id, e.name, e.sample_name, e.run_counter
        ORDER BY e.exp_id;
        """
        return execute_query(query)
    end

    # Export all public functions
    export open_database, close_database, get_connection, execute_query, execute_statement
    export get_all_experiments, get_experiment_by_id, get_experiments_by_name
    export get_all_runs, get_runs_by_experiment, get_run_by_id, get_completed_runs, get_recent_runs
    export get_layouts_for_run, get_result_data, get_result_data_by_run_id
    export list_all_tables, list_result_tables, get_table_info
    export search_runs_by_guid, get_experiment_summary
    export openDB

end
