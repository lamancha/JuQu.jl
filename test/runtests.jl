using JuQu
using Test
using DataFrames
using SQLite

# Test database path - use the actual test database  
const TEST_DB_PATH = joinpath(@__DIR__, "test.db")

@testset "JuQu.jl SQLite Functions" begin
    
    @testset "Database Connection Management" begin
        # Test opening database
        @test_nowarn open_database(TEST_DB_PATH)
        
        # Test that connection is established
        conn = get_connection()
        @test conn isa SQLite.DB
        
        # Test closing database
        @test_nowarn close_database()
        
        # Test error when trying to get connection after closing
        @test_throws ErrorException get_connection()
        
        # Note: SQLite doesn't throw error for nonexistent database, it creates empty one
        # So we test with an invalid path that would cause a filesystem error
        @test_throws ErrorException open_database("/invalid/path/that/does/not/exist/database.db")
        
        # Reopen for subsequent tests
        open_database(TEST_DB_PATH)
    end
    
    @testset "Query Execution Functions" begin
        # Test basic query execution
        result = execute_query("SELECT COUNT(*) as count FROM experiments")
        @test result isa DataFrame
        @test nrow(result) == 1
        @test "count" in names(result)
        
        # Test query with results
        experiments = execute_query("SELECT * FROM experiments LIMIT 1")
        @test experiments isa DataFrame
        @test nrow(experiments) >= 0
        
        # Test invalid query
        @test_throws ErrorException execute_query("SELECT * FROM nonexistent_table")
        
        # Test statement execution (this should work without errors)
        # Using a safe operation that doesn't modify data
        @test_nowarn execute_statement("CREATE TEMP TABLE IF NOT EXISTS test_temp (id INTEGER)")
        
        # Test invalid statement
        @test_throws ErrorException execute_statement("INVALID SQL STATEMENT")
    end
    
    @testset "Experiment Query Functions" begin
        # Test get_all_experiments
        experiments = get_all_experiments()
        @test experiments isa DataFrame
        @test nrow(experiments) >= 0
        if nrow(experiments) > 0
            @test "exp_id" in names(experiments)
            @test "name" in names(experiments)
        end
        
        # Test get_experiment_by_id
        if nrow(experiments) > 0
            exp_id = experiments.exp_id[1]
            single_exp = get_experiment_by_id(exp_id)
            @test single_exp isa DataFrame
            @test nrow(single_exp) == 1
            @test single_exp.exp_id[1] == exp_id
        end
        
        # Test get_experiment_by_id with non-existent ID
        non_existent = get_experiment_by_id(99999)
        @test non_existent isa DataFrame
        @test nrow(non_existent) == 0
        
        # Test get_experiments_by_name
        name_search = get_experiments_by_name("test")
        @test name_search isa DataFrame
        @test nrow(name_search) >= 0
        
        # Test get_experiment_summary
        summary = get_experiment_summary()
        @test summary isa DataFrame
        @test nrow(summary) >= 0
        if nrow(summary) > 0
            expected_cols = ["exp_id", "name", "actual_run_count", "completed_runs"]
            for col in expected_cols
                @test col in names(summary)
            end
        end
    end
    
    @testset "Run Query Functions" begin
        # Test get_all_runs
        runs = get_all_runs(10)
        @test runs isa DataFrame
        @test nrow(runs) >= 0
        @test nrow(runs) <= 10  # Should respect limit
        if nrow(runs) > 0
            @test "run_id" in names(runs)
            @test "exp_id" in names(runs)
        end
        
        # Test get_all_runs with different limit
        runs_limited = get_all_runs(5)
        @test nrow(runs_limited) <= 5
        
        # Test get_runs_by_experiment
        experiments = get_all_experiments()
        if nrow(experiments) > 0
            exp_id = experiments.exp_id[1]
            exp_runs = get_runs_by_experiment(exp_id)
            @test exp_runs isa DataFrame
            @test nrow(exp_runs) >= 0
            # All runs should belong to the specified experiment
            if nrow(exp_runs) > 0
                @test all(exp_runs.exp_id .== exp_id)
            end
        end
        
        # Test get_run_by_id
        if nrow(runs) > 0
            run_id = runs.run_id[1]
            single_run = get_run_by_id(run_id)
            @test single_run isa DataFrame
            @test nrow(single_run) == 1
            @test single_run.run_id[1] == run_id
        end
        
        # Test get_run_by_id with non-existent ID
        non_existent_run = get_run_by_id(99999)
        @test non_existent_run isa DataFrame
        @test nrow(non_existent_run) == 0
        
        # Test get_completed_runs
        completed = get_completed_runs()
        @test completed isa DataFrame
        @test nrow(completed) >= 0
        if nrow(completed) > 0
            @test all(completed.is_completed .== 1)
        end
        
        # Test get_completed_runs with experiment filter
        if nrow(experiments) > 0
            exp_id = experiments.exp_id[1]
            completed_exp = get_completed_runs(exp_id)
            @test completed_exp isa DataFrame
            if nrow(completed_exp) > 0
                @test all(completed_exp.exp_id .== exp_id)
                @test all(completed_exp.is_completed .== 1)
            end
        end
        
        # Test get_recent_runs
        recent = get_recent_runs(24)  # Last 24 hours
        @test recent isa DataFrame
        @test nrow(recent) >= 0
        
        # Test get_recent_runs with different time window
        recent_week = get_recent_runs(168)  # Last week
        @test nrow(recent_week) >= nrow(recent)  # Week should have more or equal runs than day
    end
    
    @testset "Result Data Access Functions" begin
        # Test list_result_tables
        result_tables = list_result_tables()
        @test result_tables isa Vector{String}
        @test length(result_tables) >= 0
        
        # Test get_result_data if result tables exist
        if length(result_tables) > 0
            table_name = result_tables[1]
            
            # Test get_result_data
            data = get_result_data(table_name, 10)
            @test data isa DataFrame
            @test nrow(data) >= 0
            @test nrow(data) <= 10  # Should respect limit
            if nrow(data) > 0
                @test "id" in names(data)  # ID column should exist
            end
            
            # Test get_result_data with different limit
            data_limited = get_result_data(table_name, 3)
            @test nrow(data_limited) <= 3
        end
        
        # Test get_result_data with invalid table name
        @test_throws ErrorException get_result_data("invalid-table-name!@#")
        @test_throws ErrorException get_result_data("nonexistent_table")
        
        # Test get_result_data_by_run_id
        runs = get_all_runs(10)
        if nrow(runs) > 0
            # Find a run with a valid result table
            for i in 1:nrow(runs)
                run_id = runs.run_id[i]
                table_name = runs.result_table_name[i]
                
                if !ismissing(table_name) && table_name != ""
                    run_data = get_result_data_by_run_id(run_id, 5)
                    @test run_data isa DataFrame
                    @test nrow(run_data) >= 0
                    @test nrow(run_data) <= 5
                    break
                end
            end
        end
        
        # Test get_result_data_by_run_id with non-existent run
        @test_throws ErrorException get_result_data_by_run_id(99999)
        
        # Test get_layouts_for_run
        if nrow(runs) > 0
            run_id = runs.run_id[1]
            layouts = get_layouts_for_run(run_id)
            @test layouts isa DataFrame
            @test nrow(layouts) >= 0
            if nrow(layouts) > 0
                @test "layout_id" in names(layouts)
                @test "run_id" in names(layouts)
                @test all(layouts.run_id .== run_id)
            end
        end
    end
    
    @testset "Utility Functions" begin
        # Test list_all_tables
        all_tables = list_all_tables()
        @test all_tables isa Vector{String}
        @test length(all_tables) > 0
        
        # Should contain core tables
        expected_tables = ["experiments", "runs", "layouts", "dependencies"]
        for table in expected_tables
            @test table in all_tables
        end
        
        # Test list_result_tables
        result_tables = list_result_tables()
        @test result_tables isa Vector{String}
        # All result tables should start with "results-"
        for table in result_tables
            @test startswith(table, "results-")
        end
        
        # Test get_table_info
        exp_info = get_table_info("experiments")
        @test exp_info isa DataFrame
        @test nrow(exp_info) > 0
        @test "name" in names(exp_info)  # Should have column info
        @test "type" in names(exp_info)
        
        # Test get_table_info with invalid table name  
        @test_throws ErrorException get_table_info("invalid-table!@#")
        # Note: PRAGMA table_info returns empty DataFrame for nonexistent tables, not error
        nonexistent_info = get_table_info("nonexistent_table")
        @test nrow(nonexistent_info) == 0
        
        # Test search_runs_by_guid
        guid_results = search_runs_by_guid("test")
        @test guid_results isa DataFrame
        @test nrow(guid_results) >= 0
        
        # Test search with empty pattern
        empty_guid_results = search_runs_by_guid("")
        @test empty_guid_results isa DataFrame
    end
    
    @testset "Error Handling and Edge Cases" begin
        # Test query execution with empty results
        empty_result = execute_query("SELECT * FROM experiments WHERE exp_id = -1")
        @test empty_result isa DataFrame
        @test nrow(empty_result) == 0
        
        # Test functions with extreme values
        @test get_all_runs(0) isa DataFrame  # Zero limit
        @test nrow(get_all_runs(0)) == 0
        
        @test get_recent_runs(0) isa DataFrame  # Zero hours
        
        # Test with very large limits
        large_result = get_all_runs(999999)
        @test large_result isa DataFrame
        
        # Test name search with special characters
        special_search = get_experiments_by_name("%")
        @test special_search isa DataFrame
        
        # Test empty string searches
        empty_search = get_experiments_by_name("")
        @test empty_search isa DataFrame
    end
    
    @testset "Data Integrity and Consistency" begin
        # Test that experiment IDs in runs table match experiments table
        experiments = get_all_experiments()
        runs = get_all_runs(100)
        
        if nrow(experiments) > 0 && nrow(runs) > 0
            exp_ids = Set(experiments.exp_id)
            run_exp_ids = Set(runs.exp_id)
            
            # All experiment IDs in runs should exist in experiments
            @test issubset(run_exp_ids, exp_ids)
        end
        
        # Test that run counts in summary match actual runs
        summary = get_experiment_summary()
        if nrow(summary) > 0
            for row in eachrow(summary)
                exp_id = row.exp_id
                expected_count = row.actual_run_count
                actual_runs = get_runs_by_experiment(exp_id)
                @test nrow(actual_runs) == expected_count
            end
        end
        
        # Test that completed runs count is consistent
        all_runs = get_all_runs(1000)
        completed_runs = get_completed_runs()
        
        if nrow(all_runs) > 0
            completed_count_from_all = sum(all_runs.is_completed .== 1)
            @test nrow(completed_runs) <= completed_count_from_all
        end
    end
    
    @testset "Connection State Management" begin
        # Test multiple open/close cycles
        for i in 1:3
            close_database()
            @test_throws ErrorException get_connection()
            
            open_database(TEST_DB_PATH)
            @test get_connection() isa SQLite.DB
        end
        
        # Test that queries work after reconnection
        result = execute_query("SELECT COUNT(*) as count FROM experiments")
        @test result isa DataFrame
        @test nrow(result) == 1
    end
    
    # Cleanup: close database connection
    @testset "Cleanup" begin
        @test_nowarn close_database()
        
        # Verify connection is closed
        @test_throws ErrorException get_connection()
    end
end
