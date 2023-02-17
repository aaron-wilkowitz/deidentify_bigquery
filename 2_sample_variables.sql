CREATE OR REPLACE TABLE `deid_demo_input.deidentify_input_variables` AS 
SELECT 
    'deid_demo_input.sample_table_input' as table_name_input 
      -- STRING; required; this must reference an existing table
  , 'deid_demo_output.sample_table_output_deid' as table_name_output 
      -- STRING; optional; default: table_name + "_deid"; procedure will create a new de-id table called this
  , 'deid_demo_output.sample_table_output_deid_mapping' as table_name_output_mapping 
      -- STRING; optional; default: table_name + "_deid_mapping"; procedure will create a mapping table of "columns_masked_but_relative" to this table
  , ['patient_id', 'encounter_id'] as columns_masked_but_relative 
      -- ARRAY of STRINGS; optional; use this for columns that need to be masked but you need to know their relative information (e.g. 2 records with same SSN should have same de-id ID)
  , ['admission_date', 'discharge_date'] as columns_dates_moved_in_tandem 
      -- ARRAY of STRINGS; optional; these are date columns that must be moved in tandem by a similar # of days
  , [-15,15] as scale_date_movement 
      -- ARRAY of INTEGERS; optional; default: [0,0]; first # must be smaller than second number; move date columns between the min & max of these values (e.g. move date columns back up to 15 days or forwards up to 15 days)
  , ['race'] as columns_removed 
      -- ARRAY of STRINGS; optional; these columns will be completely removed from the procedure
  , ['age', '5', 'cost_encounter', '1000'] as columns_bucketed 
      -- ARRAY of STRINGS; optional; 1st, 3rd, 5th, etc. elements in the array must refer to columns with numeric columns; 2nd, 4th, 6th, etc. elements in the array must be integers to bucket around
; 
