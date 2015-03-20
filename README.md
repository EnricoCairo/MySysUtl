# MySysUtl
Library of functions and procedures for MySQL

[ Purpose ]

At first, my idea was to write a single file ".sql", but I decided to fall back
on the solution to create a file for each area, in order to make my work easier
to understand.

I decided to develop this library of functions and procedures for all those
Oracle dba who want to approach the world of MySQL.

First of all, let me explain this concept better.
In Oracle databases, usually we talk about schemas, roles and so on; the term
"database" itself can have different meanings: in Oracle we use this term to
address all the files of an instance, while in MySQL engine it's used in the
same way as the word "schema" in Oracle.

I'm trying to use names and conventions usual in Oracle context but, please,
keep in mind it's no possible clone perfectly their meaning in MySQL.

[ Scopes ]

- File "00_Init.sql"

It just contains database creation and some parameter setting.

- File "01_General.sql"

Here you can find general purpose functions.

- File "02_Debug.sql"

Functions let you better debug your code by implementing a spartan log system.

- File "03_DbSize.sql"

You can trace the grown of your databases.

- File "04_Audit.sql"

- File "05_Quota.sql"

- File "06_Profile.sql"

- File "07_AWR.sql"



[![Bitdeli Badge](https://d2weczhvl823v0.cloudfront.net/EnricoCairo/mysysutl/trend.png)](https://bitdeli.com/free "Bitdeli Badge")

