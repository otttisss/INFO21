# INFO21

This repository contains a database schema and associated scripts to manage a peer-to-peer (P2P) evaluation system. The system tracks tasks, checks, XP points, and more for a community of peers.

## Database Schema

### Peers table

- `Peer’s nickname`
- `Birthday`

### Tasks table

- `Name of the task`
- `Name of the task, which is the entry condition`
- `Maximum number of XP`

### Check status (Enumeration)

- `Start` - the check starts
- `Success` - successful completion of the check
- `Failure` - unsuccessful completion of the check

### P2P Table

- `ID`
- `Check ID`
- `Nickname of the checking peer`
- `P2P check status`
- `Time`

### Verter Table

- `ID`
- `Check ID`
- `Check status by Verter`
- `Time`

### Checks table

- `ID`
- `Peer’s nickname`
- `Name of the task`
- `Check date`

### TransferredPoints table

- `ID`
- `Nickname of the checking peer`
- `Nickname of the peer being checked`
- `Number of transferred peer points for all time`

### Friends table

- `ID`
- `Nickname of the first peer`
- `Nickname of the second peer`

### Recommendations table

- `ID`
- `Nickname of the peer`
- `Nickname of the peer to whom it is recommended to go for the check`

### XP Table

- `ID`
- `Check ID`
- `Number of XP received`

### TimeTracking table

- `ID`
- `Peer's nickname`
- `Date`
- `Time`
- `State (1 - in, 2 - out)`

## Part 1: Creating the Database

The `part1.sql` script creates the database and all associated tables. It also includes procedures to import and export data from/to CSV files. CSV file separators can be specified as parameters.

## Part 2: Changing Data

The `part2.sql` script handles the following tasks:

1. Adds a P2P check with parameters: `nickname of the person being checked`, `checker's nickname`, `task name`, `P2P check status`, `time`.
2. Adds a Verter check with parameters: `nickname of the person being checked`, `task name`, `Verter check status`, `time`.
3. Trigger: after adding a record with the "start" status to the P2P table, it changes the corresponding record in the TransferredPoints table.
4. Trigger: before adding a record to the XP table, it checks if it is correct.

## Part 3: Getting Data

The `part3.sql` script includes the following procedures and functions:

1. Function: Returns the TransferredPoints table in a human-readable form.
2. Function: Returns a table with user names, checked task names, and XP received for successfully passed checks.
3. Function: Finds peers who have not left campus for the whole day.
4. Calculates the change in the number of peer points for each peer using the TransferredPoints table.
5. Calculates the change in the number of peer points using the table returned by the first function.
6. etc ...
   
## Bonus: Part 4: Metadata

This section involves creating a separate database to test procedures:

1. Procedure: Destroys all tables in the current database whose names begin with 'TableName'.
2. Procedure: Outputs names and parameters of all scalar user's SQL functions.
3. Procedure: Destroys all SQL DML triggers in the current database.
4. Procedure: Outputs names and descriptions of object types (stored procedures and scalar functions) with a specified string.

### Note

Please ensure to add new data to the `part1.sql` script for testing purposes, and upload any CSV files used for data population to the repository. Task names should follow the format specified in the task description.

If you have any questions or need further assistance, feel free to reach out!
