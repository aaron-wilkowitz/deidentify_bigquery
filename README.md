# Function to De-identify Tables in BQ

Read [this post](https://docs.google.com/document/d/1RsWfvL0XCMpLdZVEzWOs9pqXN0l_SN-7ylfDDnOwiLA/edit?usp=sharing&resourcekey=0-3obKIa42m0AAHUvVlTFREw) first to understand how this function works. 

Follow each script in order: 
- Script 1: create a sample table in BQ 
- Script 2: create a metadata table in BQ - be careful to follow the instructions, the column names & datatypes of this table must stay the same for the procedure to work 
- Script 3a: Run the de-identify procedure in BQ one time on your project 
- Script 3b: Call the procedure with the input table from Script 1 & the metadata table from script 2

Quesitons? Comments? Code improvements? Ping me at aaronwilkowitz@google.com (or aaron.wilkowitz@gmail.com) 

-Aaron 
