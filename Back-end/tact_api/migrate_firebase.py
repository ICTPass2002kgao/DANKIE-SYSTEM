import psycopg2
from psycopg2 import sql
from psycopg2.extras import Json

# Replace these with your actual Railway PostgreSQL connection URLs
SOURCE_DB_URL = ""
TARGET_DB_URL = ""

def migrate_database():
    print("Connecting to databases...")
    conn_src = psycopg2.connect(SOURCE_DB_URL)
    conn_tgt = psycopg2.connect(TARGET_DB_URL)

    cursor_src = conn_src.cursor()
    cursor_tgt = conn_tgt.cursor()

    # 1. Get a list of all tables in the public schema
    cursor_src.execute("""
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
    """)
    tables = [row[0] for row in cursor_src.fetchall()]

    print(f"Found {len(tables)} tables to migrate.")

    for table in tables:
        print(f"\n--- Processing table: {table} ---")
        
        # Force immediate constraint checking at the start of EVERY table's transaction block.
        # This prevents Django's deferred FKs from crashing the script at conn_tgt.commit().
        cursor_tgt.execute("SET CONSTRAINTS ALL IMMEDIATE;")
        
        # 2. Dynamically find the primary key for the table
        cursor_src.execute(f"""
            SELECT a.attname
            FROM   pg_index i
            JOIN   pg_attribute a ON a.attrelid = i.indrelid
                                 AND a.attnum = ANY(i.indkey)
            WHERE  i.indrelid = '{table}'::regclass
            AND    i.indisprimary;
        """)
        pk_result = cursor_src.fetchone()
        
        if not pk_result:
            print(f"Skipping '{table}': No primary key found.")
            continue
            
        pk_col = pk_result[0]

        # 3. Fetch all rows from the source table
        cursor_src.execute(sql.SQL("SELECT * FROM {}").format(sql.Identifier(table)))
        rows = cursor_src.fetchall()

        if not rows:
            print(f"Table '{table}' is empty. Skipping.")
            continue

        # 4. Get column names to build the dynamic INSERT query
        col_names = [desc[0] for desc in cursor_src.description]
        
        # Format the SQL safely
        cols_format = sql.SQL(', ').join(map(sql.Identifier, col_names))
        vals_format = sql.SQL(', ').join(sql.Placeholder() * len(col_names))
        
        insert_query = sql.SQL("""
            INSERT INTO {table} ({cols}) 
            VALUES ({vals}) 
            ON CONFLICT ({pk}) DO NOTHING
        """).format(
            table=sql.Identifier(table),
            cols=cols_format,
            vals=vals_format,
            pk=sql.Identifier(pk_col)
        )

        # 5. Insert rows into the target database
        inserted_count = 0
        skipped_count = 0
        
        for row in rows:
            try:
                # Use psycopg2.extras.Json to properly adapt dicts/lists for Postgres JSON/JSONB fields
                processed_row = tuple(
                    Json(val) if isinstance(val, (dict, list)) else val 
                    for val in row
                )

                # We use a savepoint so that if an error occurs (like a missing foreign key), 
                # we don't crash the entire transaction block.
                cursor_tgt.execute("SAVEPOINT batch_savepoint")
                cursor_tgt.execute(insert_query, processed_row)
                
                # If rowcount is 1, it was inserted. If 0, it was skipped due to conflict.
                if cursor_tgt.rowcount == 1:
                    inserted_count += 1
                else:
                    skipped_count += 1
                    
                cursor_tgt.execute("RELEASE SAVEPOINT batch_savepoint")
            except Exception as e:
                cursor_tgt.execute("ROLLBACK TO SAVEPOINT batch_savepoint")
                print(f"Error inserting row into {table}: {e}")

        conn_tgt.commit()
        print(f"Done with '{table}'. Inserted: {inserted_count}, Skipped (Duplicates/Errors): {skipped_count}")

    # Clean up
    cursor_src.close()
    cursor_tgt.close()
    conn_src.close()
    conn_tgt.close()
    print("\nMigration complete!")

if __name__ == "__main__":
    migrate_database()