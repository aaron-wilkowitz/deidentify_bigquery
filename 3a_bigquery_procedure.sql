CREATE OR REPLACE PROCEDURE `deid_demo_input.deidentify_table` (table_input_variables string)
BEGIN

/**************
Variables Table: Confirm it Exists & Data Types are Correct
**************/

# Confirm variables table has correct # of periods to be a real table
    CREATE OR REPLACE TEMP TABLE table_input_variables_detail AS 
    SELECT 
        split(table_input_variables,'.') as table_input_variables_array
      , array_length(split(table_input_variables,'.')) as table_input_variables_array_length
    ;

    SELECT 
      case 
        when table_input_variables_array_length < 2 then ERROR('error: table_input_variables needs dataset')
        when table_input_variables_array_length > 3 then ERROR('error: table_input_variables has too many parts') 
      end as error1
    FROM table_input_variables_detail
    ; 

# Create a table of information_schema_columns 
    CREATE OR REPLACE TEMP TABLE schema_value AS 
    SELECT       
      case 
        when table_input_variables_array_length = 3 then table_input_variables_array[OFFSET(1)] 
        when table_input_variables_array_length = 2 then table_input_variables_array[OFFSET(0)]
      end as dataset_name
    FROM table_input_variables_detail
    ; 

    EXECUTE IMMEDIATE 'CREATE OR REPLACE TEMP TABLE information_schema_columns AS SELECT * FROM `' || (SELECT dataset_name FROM schema_value) || '.INFORMATION_SCHEMA.COLUMNS`' 
    ;

# Confirm variables table exists
    CREATE OR REPLACE TEMP TABLE table_input_variables_column_names AS 
    SELECT a.*
    FROM information_schema_columns a 
    JOIN table_input_variables_detail b 
      ON  
        case 
          when b.table_input_variables_array_length = 3 then table_catalog = table_input_variables_array[OFFSET(0)] 
          when b.table_input_variables_array_length = 2 then 1 = 1 
        end
      AND  
        case 
          when b.table_input_variables_array_length = 3 then table_schema = table_input_variables_array[OFFSET(1)] 
          when b.table_input_variables_array_length = 2 then table_schema = table_input_variables_array[OFFSET(0)]
        end 
      AND 
        case 
          when b.table_input_variables_array_length = 3 then table_name = table_input_variables_array[OFFSET(2)] 
          when b.table_input_variables_array_length = 2 then table_name = table_input_variables_array[OFFSET(1)]
        end 
    ; 

# Confirm column names are correct 
  with dataset1 as (
              SELECT 'table_name_input' as column_name
    UNION ALL SELECT 'table_name_output' as column_name
    UNION ALL SELECT 'table_name_output_mapping' as column_name
    UNION ALL SELECT 'columns_masked_but_relative' as column_name
    UNION ALL SELECT 'columns_dates_moved_in_tandem' as column_name
    UNION ALL SELECT 'scale_date_movement' as column_name
    UNION ALL SELECT 'columns_removed' as column_name
    UNION ALL SELECT 'columns_bucketed' as column_name
  ) 
  SELECT 
    case 
      when sum(case when b.column_name is null then 1 else 0 end) > 0 then ERROR('error: columns are in variable table that are not in approved list; only allowed column names are: table_name_input, table_name_output, table_name_output_mapping, columns_masked_but_relative, columns_dates_moved_in_tandem, scale_date_movement, columns_removed, columns_bucketed')
      else 'ok'
    end 
  FROM table_input_variables_column_names a 
  LEFT JOIN dataset1 b 
    ON a.column_name = b.column_name 
  ;

# Confirm datatypes are correct 
    SELECT 
        case 
          when count(*) = 0 then ERROR('error: no data in table_input_variables') 
          when sum(case when column_name = 'table_name_input' then 1 else 0 end) < 1 then ERROR('error: in table_input_variables table, table_name_input column required')
          when sum(case when column_name = 'table_name_input' then 1 else 0 end) <> sum(case when column_name = 'table_name_input' and data_type = 'STRING' then 1 else 0 end) then ERROR('error: in table_input_variables table, table_name_input is not string')
          when sum(case when column_name = 'table_name_output' then 1 else 0 end) <> sum(case when column_name = 'table_name_output' and data_type = 'STRING' then 1 else 0 end) then ERROR('error: in table_input_variables table, table_name_output is not string')
          when sum(case when column_name = 'table_name_output_mapping' then 1 else 0 end) <> sum(case when column_name = 'table_name_output_mapping' and data_type = 'STRING' then 1 else 0 end) then ERROR('error: in table_input_variables table, table_name_output_mapping is not string')
          when sum(case when column_name = 'columns_masked_but_relative' then 1 else 0 end) <> sum(case when column_name = 'columns_masked_but_relative' and data_type = 'ARRAY<STRING>' then 1 else 0 end) then ERROR('error: in table_input_variables table, columns_masked_but_relative is not string')
          when sum(case when column_name = 'columns_dates_moved_in_tandem' then 1 else 0 end) <> sum(case when column_name = 'columns_dates_moved_in_tandem' and data_type = 'ARRAY<STRING>' then 1 else 0 end) then ERROR('error: in table_input_variables table, columns_dates_moved_in_tandem is not string')
          when sum(case when column_name = 'scale_date_movement' then 1 else 0 end) <> sum(case when column_name = 'scale_date_movement' and data_type = 'ARRAY<INT64>' then 1 else 0 end) then ERROR('error: in table_input_variables table, scale_date_movement is not string')
          when sum(case when column_name = 'columns_removed' then 1 else 0 end) <> sum(case when column_name = 'columns_removed' and data_type = 'ARRAY<STRING>' then 1 else 0 end) then ERROR('error: in table_input_variables table, columns_removed is not string')
          when sum(case when column_name = 'columns_bucketed' then 1 else 0 end) <> sum(case when column_name = 'columns_bucketed' and data_type = 'ARRAY<STRING>' then 1 else 0 end) then ERROR('error: in table_input_variables table, columns_bucketed is not string')
          else 'ok' 
        end as error_check
    FROM table_input_variables_column_names 
    ; 

/**************
Variables Table: Look at the values in the table and confirm they're correct
**************/

# Create a temp table of the values in the variables table 
    EXECUTE IMMEDIATE 
      'CREATE OR REPLACE TEMP TABLE table_input_variables_data AS SELECT * FROM ' || table_input_variables || ';' 
    ; 

# Check values in variables table
    CREATE OR REPLACE TEMP TABLE table_input_variables_data_metadata AS 
    SELECT  
        case 
          when (SELECT count(*) FROM table_input_variables_data) = 0 then ERROR('error: there is no data in the input variables table')
          when (SELECT count(*) FROM table_input_variables_data) > 1 then ERROR('error: there is more than 1 row in the input variables table')
          else 'ok'
        end as datachecks
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'table_name_input') > 0 then split(a.table_name_input,'.') else [] end as table_name_input_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'table_name_input') > 0 then array_length(split(a.table_name_input,'.')) else 0 end as table_name_input_array_length
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'table_name_output') > 0 then split(a.table_name_output,'.') else [] end as table_name_output_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'table_name_output') > 0 then array_length(split(a.table_name_output,'.')) else 0 end as table_name_output_array_length
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'table_name_output_mapping') > 0 then split(a.table_name_output_mapping,'.') else [] end as table_name_output_mapping_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'table_name_output_mapping') > 0 then array_length(split(a.table_name_output_mapping,'.')) else 0 end as table_name_output_mapping_array_length
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'columns_masked_but_relative') > 0 then a.columns_masked_but_relative else [] end as columns_masked_but_relative_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'columns_dates_moved_in_tandem') > 0 then a.columns_dates_moved_in_tandem else [] end as columns_dates_moved_in_tandem_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'scale_date_movement') > 0 then a.scale_date_movement else [] end as scale_date_movement_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'scale_date_movement') > 0 then array_length(a.scale_date_movement) else 0 end as scale_date_movement_array_length
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'columns_removed') > 0 then a.columns_removed else [] end as columns_removed_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'columns_bucketed') > 0 then a.columns_bucketed else [] end as columns_bucketed_array
      , case when (SELECT count(*) FROM table_input_variables_column_names WHERE column_name = 'columns_bucketed') > 0 then array_length(a.columns_bucketed) else 0 end as columns_bucketed_array_length
    FROM table_input_variables_data a 
    ;

# Confirm columns have correct structure
    SELECT 
        case 
          when table_name_input_array_length < 2 then ERROR('error: table_name_input needs dataset')
          when table_name_input_array_length > 3 then ERROR('error: table_name_input has too many parts') 
          when table_name_output_array_length < 2 then ERROR('error: table_name_output needs dataset')
          when table_name_output_array_length > 3 then ERROR('error: table_name_output has too many parts') 
          when table_name_output_mapping_array_length < 2 then ERROR('error: table_name_output_mapping needs dataset')
          when table_name_output_mapping_array_length > 3 then ERROR('error: table_name_output_mapping has too many parts') 
          when scale_date_movement_array_length = 1 then ERROR('error: scale_date_movement needs 2 values, not 1') 
          when scale_date_movement_array_length > 2 then ERROR('error: scale_date_movement can only have 2 values - a min and a max') 
          when MOD(columns_bucketed_array_length, 2) <> 0 then ERROR('error: columns_bucketed should have an even number of array elements - a bunch of key-value pairs') 
          else 'ok'
        end 
    FROM table_input_variables_data_metadata
    ;

# Create a temp table just for columns_bucketed
    CREATE OR REPLACE TEMP TABLE columns_bucketed_values AS 
    with data1 as (
      SELECT value 
      FROM table_input_variables_data_metadata a 
      , unnest(columns_bucketed_array) as value
    )
    , data2 as (
      SELECT *, row_number() over (order by 'x') as row_number 
      FROM data1
    )
    SELECT 
        *
      , ceiling(row_number / 2) as grouping_value
      , case when MOD(row_number, 2) = 0 then 'even' else 'odd' end as even_odd
    FROM data2
    ; 

# Check that odd values are integers
    SELECT 
        case 
          when sum(case when even_odd = 'even' then 1 else 0 end) <> sum(case when even_odd = 'even' and safe_cast(value as INT64) is not null then 1 else 0 end) then ERROR('error: columns_bucketed odd elements need to be an integer')
          else 'ok'
        end 
    FROM columns_bucketed_values
    ;

/**************
Map Variables Table to Input Table & Run Checks
**************/

# Create temp table for input table
    EXECUTE IMMEDIATE 
      'CREATE OR REPLACE TEMP TABLE table_input_data AS SELECT *, row_number() over (order by 1) as row_id, rand() as rand_date_shift FROM ' || (SELECT table_name_input FROM table_input_variables_data) || ';' 
    ;  

# Create a temp table of all relevant columns that input_variables wants to update
    CREATE OR REPLACE TEMP TABLE columns_all_combined AS 
    
    with scale_date_array as (
      SELECT scale_date 
      FROM table_input_variables_data_metadata
      , unnest(scale_date_movement_array) as scale_date
    )
    , col_name_array as (
      SELECT col_name 
      FROM table_input_variables_data_metadata a 
      , unnest(columns_dates_moved_in_tandem_array) as col_name
      WHERE col_name <> ''
      AND col_name is not null 
    )
    
    SELECT 
        col_name
      , 'columns_masked_but_relative' as col_rule
      , cast(NULL as int64) as num_value1
      , cast(NULL as int64) as num_value2
    FROM table_input_variables_data_metadata a 
    , unnest(columns_masked_but_relative_array) as col_name
    WHERE col_name <> ''
    AND col_name is not null 

    UNION ALL 
   
    SELECT 
        a.col_name
      , 'columns_dates_moved_in_tandem' as col_rule
      , safe_cast((SELECT min(scale_date) FROM scale_date_array) as int64) as num_value1
      , safe_cast((SELECT max(scale_date) FROM scale_date_array) as int64) as num_value2
    FROM col_name_array a 


    UNION ALL 
   
    SELECT 
        col_name
      , 'columns_removed' as col_rule 
      , cast(NULL as int64) as num_value1
      , cast(NULL as int64) as num_value2
    FROM table_input_variables_data_metadata a 
    , unnest(columns_removed_array) as col_name    
    WHERE col_name <> ''
    AND col_name is not null 

    UNION ALL 
   
    SELECT 
        a.value as col_name
      , 'columns_bucketed' as col_rule
      , safe_cast(b.value as int64) as num_value1
      , cast(NULL as int64) as num_value2
    FROM (SELECT value, grouping_value FROM columns_bucketed_values WHERE even_odd = 'odd') a 
    LEFT JOIN (SELECT value, grouping_value FROM columns_bucketed_values WHERE even_odd = 'even') b
      ON a.grouping_value = b.grouping_value 
    
    ; 

# Check that a single column is not used twice 
    SELECT 
        case 
          when count(*) <> count(distinct col_name) then ERROR('error: a single column is used twice in the input_variables')
          else 'ok'
        end 
    FROM columns_all_combined
    ;

## Create a temp table of all input_table columns from information schema
    CREATE OR REPLACE TEMP TABLE input_table_column_names AS 
    SELECT a.*
    FROM information_schema_columns a 
    , table_input_variables_data_metadata b 
    WHERE 
      case 
        when b.table_name_input_array_length = 3 then table_catalog = table_name_input_array[OFFSET(0)] 
        when b.table_name_input_array_length = 2 then 1 = 1 
      end
    AND  
      case 
        when b.table_name_input_array_length = 3 then table_schema = table_name_input_array[OFFSET(1)] 
        when b.table_name_input_array_length = 2 then table_schema = table_name_input_array[OFFSET(0)]
      end 
    AND 
      case 
        when b.table_name_input_array_length = 3 then table_name = table_name_input_array[OFFSET(2)] 
        when b.table_name_input_array_length = 2 then table_name = table_name_input_array[OFFSET(1)]
      end 
    ; 

## Create a temp table that combines the two tables
    CREATE OR REPLACE TEMP TABLE input_table_column_names AS 
    SELECT 
        coalesce(a.col_name, b.column_name) as column_name
      , b.data_type 
      , b.ordinal_position 
      , coalesce(a.col_rule, 'no value') as col_rule
      , a.num_value1
      , a.num_value2 
    FROM columns_all_combined a 
    FULL OUTER JOIN input_table_column_names b
      ON a.col_name = b.column_name
    ORDER BY 3
    ; 

## Check that columns exist and that they're the right data format
    SELECT 
      case 
        when sum(case when ordinal_position is null then 1 else 0 end) > 0 then ERROR('error: you have columns in input varables table that do not exist in the original input table')
        when sum(case when col_rule = 'columns_dates_moved_in_tandem' and data_type in ('DATE','DATETIME','TIME','TIMESTAMP') then 1 else 0 end) <> sum(case when col_rule = 'columns_dates_moved_in_tandem' then 1 else 0 end) then ERROR('error: columns listed in columns_dates_moved_in_tandem need to be date, datetime, time, or timestamp columns')
        when sum(case when col_rule = 'columns_bucketed' and data_type in ('BIGNUMERIC','FLOAT64','INT64','NUMERIC') then 1 else 0 end) <> sum(case when col_rule = 'columns_bucketed' then 1 else 0 end) then ERROR('error: columns listed in column_bucketed need to be bignumeric, float, int, or numeric columns')
        when sum(case when col_rule in ('columns_dates_moved_in_tandem','columns_bucketed','columns_removed','columns_masked_but_relative','no value') then 1 else 0 end) <> count(*) then ERROR('error: there are columns that do not have any of the allowed rules - columns_dates_moved_in_tandem, columns_bucketed, columns_removed, columns_masked_but_relative, or no value')
        else 'ok'
      end 
    FROM input_table_column_names ; 

/**************
Create the output tables
**************/

# Create an initial table with every row with a row_id 
    CREATE OR REPLACE TEMP TABLE initial_row_id_table AS 
    SELECT row_id 
    FROM table_input_data  a 
    ;

# Create a loop that runs through every column and creates a row_id, column_value table
    # Set loop to 0
    CREATE OR REPLACE TEMP TABLE set_loop_id AS 
    SELECT 0 as loop_id
    ;

# Create a blank de_id mapping table 
    IF (SELECT count(*) FROM input_table_column_names WHERE col_rule = 'columns_masked_but_relative') = 0 THEN 
      SELECT 'ok' ; 
    ELSE 
      EXECUTE IMMEDIATE (
        SELECT 'CREATE OR REPLACE TABLE ' || table_name_output_mapping || ' (row_id INT64 , column_name string, original_value string , de_id_value string ) ; '
      FROM table_input_variables_data
      ) ; 
    END IF ;

# Start loop
    LOOP  
      # Add 1 to loop 
      UPDATE set_loop_id SET loop_id = loop_id + 1 WHERE 1 = 1 ; 
      
      # Check that there's still columns to update
      IF (SELECT loop_id FROM set_loop_id) > (SELECT max(ordinal_position) FROM input_table_column_names) THEN
        LEAVE;
      ELSE
      # Get metadata of column for that loop
        CREATE OR REPLACE TEMP TABLE column_action AS 
        SELECT *
        FROM input_table_column_names a 
        JOIN set_loop_id b 
          ON a.ordinal_position = b.loop_id
        ;   
        
        SELECT * FROM column_action ; 
      END IF; 

# Run logic for columns masked but relative
      IF (SELECT col_rule = 'columns_masked_but_relative' FROM column_action) THEN

        # Create 4 column values 
        EXECUTE IMMEDIATE (
          SELECT 'CREATE OR REPLACE TEMP TABLE temp_3_column_format AS SELECT row_id, \'' || column_name || '\' as column_name, ' || column_name || ' as original_value, dense_rank() over (order by ' || column_name || ' ) as de_id_value FROM table_input_data ;'
          FROM column_action
        ) ; 

        # Insert 4 column values into output_mapping_table
        EXECUTE IMMEDIATE (
          SELECT 'INSERT INTO ' || table_name_output_mapping || ' SELECT row_id, column_name, cast(original_value as string) as original_value, cast(de_id_value as string) as de_id_value FROM temp_3_column_format ;' 
        FROM table_input_variables_data 
        ) ; 

        # Create a 2 column table that is similar to other formats
        EXECUTE IMMEDIATE (
          SELECT 'CREATE OR REPLACE TEMP TABLE row_id_table_loop_' || ordinal_position || ' AS SELECT row_id, de_id_value as ' || column_name || ' FROM temp_3_column_format ;'
          FROM column_action
        ) ; 
      END IF; 

# Run logic for columns dates moved in tandem
      IF (SELECT col_rule = 'columns_dates_moved_in_tandem' FROM column_action) THEN
        
        EXECUTE IMMEDIATE (
          SELECT 'CREATE OR REPLACE TEMP TABLE row_id_table_loop_' || ordinal_position || ' AS SELECT row_id, ' || data_type || '_add( ' || column_name || ' , interval safe_cast(( rand_date_shift * (' || num_value2 || ' - ' || num_value1 || ')) + ' || num_value1 || ' as int64) day) as ' || column_name || ' FROM table_input_data ;'
          FROM column_action
        ) ;  
      END IF; 

# Run logic for columns removed
      IF (SELECT col_rule = 'columns_removed' FROM column_action) THEN
        EXECUTE IMMEDIATE (
          SELECT 'CREATE OR REPLACE TEMP TABLE row_id_table_loop_' || ordinal_position || ' AS SELECT row_id, null as ' || column_name || ' FROM table_input_data ;'
          FROM column_action
        ) ; 
      END IF; 

# Run logic for columns bucketed
      IF (SELECT col_rule = 'columns_bucketed' FROM column_action) THEN
        EXECUTE IMMEDIATE (
          SELECT 'CREATE OR REPLACE TEMP TABLE row_id_table_loop_' || ordinal_position || ' AS SELECT row_id, round( ' || column_name || ' / ' || num_value1 || ' , 0 ) * ' || num_value1 || ' as ' || column_name || ' FROM table_input_data ;'
          FROM column_action
        ) ; 
      END IF; 

# Run logic for remaining columns 
      IF (SELECT col_rule = 'no value' FROM column_action) THEN
        EXECUTE IMMEDIATE (
          SELECT 'CREATE OR REPLACE TEMP TABLE row_id_table_loop_' || ordinal_position || ' AS SELECT row_id, ' || column_name || ' as ' || column_name || ' FROM table_input_data ;'
          FROM column_action
        ) ; 
      END IF; 

      EXECUTE IMMEDIATE (
        SELECT 'SELECT * FROM row_id_table_loop_' || ordinal_position || ';'
        FROM column_action
      ) ; 

    END LOOP;

# Join the initial table back to all the looped column tables into a single create new table statement

    CREATE OR REPLACE TEMP TABLE create_new_table_statement AS 
    # Write the create table line 
    with create_replace_statement as (
      SELECT 'CREATE OR REPLACE TABLE ' || table_name_output || ' AS ' as create_table_string_full
      FROM table_input_variables_data
    )
    # Write the select line 
    , each_loop_select as (
      SELECT 'loop_' || ordinal_position || '.' || column_name as select_string
      FROM input_table_column_names
      ORDER BY ordinal_position
    )
    , select_statement as (
      SELECT 'SELECT initial.row_id, ' || string_agg(select_string) || ' FROM initial_row_id_table initial' as select_string_full
      FROM each_loop_select
    ) 
    # Write the join line 
    , each_loop_join as (
      SELECT ' JOIN row_id_table_loop_' || ordinal_position || ' loop_' || ordinal_position || ' ON initial.row_id = loop_' || ordinal_position || '.row_id ' as join_string
      FROM input_table_column_names
      ORDER BY ordinal_position
    )
    , join_statement as (
      SELECT replace(string_agg(join_string),',','') as join_string_full
      FROM each_loop_join
    )
    # Combine
    SELECT a.create_table_string_full || b.select_string_full || c.join_string_full || ' ORDER BY row_id ;' as string_to_run
    FROM create_replace_statement a 
    , select_statement b 
    , join_statement c 
    ;

    # Execute statement to create table
    EXECUTE IMMEDIATE (SELECT * FROM create_new_table_statement) ; 

END 

; 
