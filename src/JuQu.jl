module JuQu

    using SQLite

    function openDB()

        db = SQLite.DB("../test/test.db")
        query = "SELECT * FROM 'runs';"
        result = SQLite.DBInterface.execute(db,query)
        print(result)
        
    end

end
