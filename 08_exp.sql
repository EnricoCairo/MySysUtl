-- -----------------------------------------------------------------------------
--
-- Exp api to dump grants with metadata and data
--
-- -----------------------------------------------------------------------------

DELIMITER $$

USE `mysysutl`$$

SELECT DATABASE(), VERSION(), NOW(), USER()$$

DROP TABLE IF EXISTS `mysysutl`.`datatypes`$$

CREATE TABLE `mysysutl`.`datatypes` (
	`family`	VARCHAR(32) NOT NULL,
    `name`		VARCHAR(32) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8$$

INSERT INTO `mysysutl`.`datatypes`(`family`, `name`) VALUES
	('numeric' ,'tinyint'),
	('numeric' ,'smallint'),
	('numeric' ,'mediumint'),
	('numeric' ,'int'),
	('numeric' ,'bigint'),
	('numeric' ,'decimal'),
	('numeric' ,'numeric'),
	('numeric' ,'float'),
	('numeric' ,'real'),
	('numeric' ,'double'),
	('numeric' ,'bit'),
	('datetime','date'),
 	('datetime','time'),
 	('datetime','year'),
 	('datetime','timestamp'),
 	('datetime','datetime'),
	('string'  ,'char'),
    ('string'  ,'varchar'),
    ('string'  ,'binary'),
    ('string'  ,'varbinary'),
    ('string'  ,'blob'),
    ('string'  ,'text'),
    ('string'  ,'enum'),
    ('string'  ,'set')$$

DROP PROCEDURE IF EXISTS `mysysutl`.`exp`$$

CREATE DEFINER='root'@'localhost' PROCEDURE `mysysutl`.`exp` (
	iStr		VARCHAR(1024)
) DETERMINISTIC CONTAINS SQL
BEGIN

	DECLARE myTable		VARCHAR(64);
	DECLARE myView		TEXT;
	DECLARE myRoutine	TEXT;
	DECLARE myGranted	VARCHAR(64);
	DECLARE myGrantee	VARCHAR(81);
	DECLARE myGrants	TEXT;
	DECLARE myGrantable	VARCHAR(3);

	DECLARE i			SMALLINT UNSIGNED;
    DECLARE j			BIGINT UNSIGNED;
    DECLARE k			BIGINT UNSIGNED;
    
    DECLARE varstr		VARCHAR(1024);
    DECLARE rowstr		VARCHAR(1024);

	DECLARE end_cur		BOOLEAN DEFAULT FALSE;

	DECLARE c_tables CURSOR FOR
		SELECT	`table_name`
		FROM	`information_schema`.`tables`
		WHERE	`table_schema` = @vSchema;

/*
	DECLARE c_data CURSOR FOR
select if(field_a is not null, field_a, field_b) from...

SELECT CONCAT('GROUP_CONCAT(CASE WHEN `data_type` IN (''varchar'',''char'',''mediumtext'',''text'',''timestamp'',''date'') THEN CONCAT('''', REPLACE(`', `column_name`, '`, ''\''', ''\'\'''), '''') ELSE `column_name` END ORDER BY `ordinal_position` SEPARATOR '',''), '')''') as str
FROM	`information_schema`.`columns`
WHERE	`table_schema` = @mySchema
AND		`table_name`   = @myTable;

SELECT	GROUP_CONCAT(CONCAT('`', column_name, '`') ORDER BY `ordinal_position` SEPARATOR ',') as row
INTO	@str
FROM	`information_schema`.`columns`
WHERE	`table_schema` = @mySchema
AND		`table_name`   = @myTable
GROUP BY `table_schema`, `table_name`
ORDER BY `ordinal_position`;

set @mySchema = 'mysql';
set @myTable  = 'user';

select CONCAT('select ',  @str, ' from ', @mySchema, '.', @myTable) INTO @sqlstr;
select @sqlstr;
prepare sqlexe from @sqlstr;
execute sqlexe;

create table `restore`.`prova` (aaa char(1) not null, bbb char(1));
insert into `restore`.`prova` (aaa) values ('1');
select aaa, ifnull(bbb, 'NULL') from `restore`.`prova`;


create database prova;
create table `prova`.`prova` (aaa char(1) not null, bbb char(1));
insert into `prova`.`prova` (aaa) values ('1');
select aaa, ifnull(bbb, 'NULL') from `prova`.`prova`;

set @mySchema = 'prova';
set @myTable = 'prova';
SELECT CONCAT('SELECT CONCAT(''('',', GROUP_CONCAT(CONCAT('IFNULL(', (CASE WHEN `data_type` IN ('varchar','char','mediumtext','text','timestamp','date') THEN CONCAT('CONCAT('''''''', REPLACE(', `column_name`, ','''', ''''''''), '''''''')') ELSE `column_name` END), ',''NULL'')') ORDER BY `ordinal_position` SEPARATOR ','','','),
	', '')'') as str from ', @mySchema, '.', @myTable, ';') as str
FROM	`information_schema`.`columns`
WHERE	`table_schema` = @mySchema
AND		`table_name`   = @myTable
GROUP BY `table_schema`, `table_name`
ORDER BY `ordinal_position`;

SELECT column FROM table
LIMIT 10 OFFSET 10	-- 11 to 20

# str
'select \'aaa\', \'bbb\' from prova;'

*/

	DECLARE c_grants CURSOR FOR
-- 		SELECT	DISTINCT table_schema, grantee, CONCAT(GROUP_CONCAT(DISTINCT privilege_type ORDER BY privilege_type SEPARATOR ', '), IF(IS_GRANTABLE = 'YES', ' WITH GRANT OPTION', '')) AS 'grants'
		SELECT	DISTINCT CONCAT(`table_schema`, '.*') as granted, `grantee`, GROUP_CONCAT(DISTINCT `privilege_type` ORDER BY `privilege_type` SEPARATOR ', ') AS 'grants', `is_grantable`
		FROM	`information_schema`.`schema_privileges`
		WHERE	`table_schema` = @vSchema
		UNION ALL	-- maybe split for database and tables
		SELECT	DISTINCT CONCAT(`table_schema`, '.', `table_name`) as granted, `grantee`, GROUP_CONCAT(DISTINCT `privilege_type` ORDER BY `privilege_type` SEPARATOR ', ') AS 'grants', `is_grantable`
		FROM	`information_schema`.`table_privileges`
		WHERE	`table_schema` = @vSchema
		GROUP BY granted, `grantee`
		ORDER BY granted, `grantee`;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET end_cur = TRUE;

-- http://www.percona.com/blog/2013/10/22/the-power-of-mysqls-group_concat/

 	CREATE TEMPORARY TABLE `tmp_exp` (
		`row_id`			BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
		`txt`				TEXT NOT NULL,
        PRIMARY KEY (`row_id`)
	) ENGINE=MyISAM DEFAULT CHARSET=utf8;

	SET SESSION group_concat_max_len = 3072;

	SET @vPath		= `mysysutl`.`get_str`(iStr, 'PATH'     , '.');
	SET @vSchemas	= `mysysutl`.`get_str`(iStr, 'SCHEMA'   , 'ALL');
	SET @vDataOnly	= `mysysutl`.`get_str`(iStr, 'DATA_ONLY', 'NO');
	SET @vNoData	= `mysysutl`.`get_str`(iStr, 'NO_DATA'  , 'NO');

	IF @vSchemas = 'ALL' THEN

		SELECT	GROUP_CONCAT(`schema_name` ORDER BY `schema_name` SEPARATOR ',')
        INTO	@vSchemas
		FROM	`information_schema`.`schemata`
		WHERE	`schema_name` NOT IN ('mysql', 'information_schema', 'performance_schema');

    END IF;

	l_Schemas: REPEAT

		SELECT SUBSTRING(@vSchemas, 1, LOCATE(',', @vSchemas) - 1) INTO @vSchemas;
		SELECT SUBSTRING(@vSchemas,    LOCATE(',', @vSchemas) + 1) INTO @vSchema;
		SELECT LOCATE(',', @vSchemas) INTO i;

		IF LENGTH(@vSchema) = 0 THEN
			SET @vSchema  = @vSchemas;
			SET @vSchemas = '';
		END IF;

--  database

		INSERT INTO `tmp_exp` (`txt`)
			SELECT	CONCAT(char(13),
				'CREATE DATABASE IF NOT EXISTS `', `schema_name`, '` /*!40100 DEFAULT CHARACTER SET ', `default_character_set_name`, ' */;', char(13),
				'USE `', @vSchema, '`;', char(13),
				'--', char(13),
				'-- MySQL dump file generated by ', `sysaux`.`release`(),  char(13),
				'--', char(13),
                '-- Host: ', @@HOSTNAME, '    Database: ', @vSchema, char(13),
                '-- ------------------------------------------------------', char(13),
                '-- Server version	', version(), char(13), char(13),
				'-- Dump started on ', now(), char(13), char(13),
				'/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;', char(13),
				'/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;', char(13),
				'/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;', char(13),
				'/*!40101 SET NAMES ', `default_character_set_name`, ' */;', char(13),
				'/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;', char(13),
				'/*!40103 SET TIME_ZONE=''+00:00'' */;', char(13),
				'/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;', char(13),
				'/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;', char(13),
				'/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE=''NO_AUTO_VALUE_ON_ZERO'' */;', char(13),
				'/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;')
			FROM	`information_schema`.`schemata`
			WHERE	`schema_name` = @vSchema;

--  get grants for database

		INSERT INTO `tmp_exp` (`txt`)
			SELECT	CONCAT('/*!40101 SET @OLD_PASSOWRDS=@@OLD_PASSOWRDS, OLD_PASSOWRDS=0 */;', char(13), char(13));

		INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('--', char(13), '-- Dumping grants for database `', @vSchema, '`', char(13), '--', char(13)));

		OPEN c_grants;

		get_grants: LOOP

			FETCH c_grants INTO myGranted, myGrantee, myGrants, myGrantable;

			IF end_cur = TRUE THEN
				SET end_cur = FALSE;
				LEAVE get_grants;
			END IF;

			INSERT INTO `tmp_exp` (`txt`)
				SELECT	CONCAT('GRANT USAGE ON *.* TO ', REPLACE(myGrantee, '\'', '\'\''), 'IDENTIFIED BY PASSWORD ''', `password`, ''';')
                FROM	`mysql`.`user`
                WHERE	CONCAT(`user`, '@', `host`) = myGrantee;

			INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('GRANT ', myGrants, ' ON ', myGranted, ' TO ', myGrantee, IF(`is_grantable` = 'YES', ' WITH GRANT OPTION', '')), ';');

		END LOOP get_grants;

		CLOSE c_grants;

		INSERT INTO `tmp_exp` (`txt`)
			SELECT	CONCAT('/*!40101 SET OLD_PASSOWRDS=@OLD_PASSOWRDS */;', char(13), char(13));

-- loop su c_tables

		OPEN c_tables;

		get_tables: LOOP

			FETCH c_tables INTO myTable;

			IF end_cur = TRUE THEN
				SET end_cur = FALSE;
				LEAVE get_tables;
			END IF;

--  get ddl for table

			INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('--', char(13), '-- Table structure for table `', myTable, '`', char(13), '--', char(13)));
			INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('DROP TABLE IF EXISTS `', myTable, '`;', char(13), '/*!40101 SET @saved_cs_client     = @@character_set_client */;', char(13), '/*!40101 SET character_set_client = utf8 */;', char(13)));

			INSERT INTO `tmp_exp` (`txt`) -- add comments + partitions
				SELECT DISTINCT(CONCAT('CREATE TABLE `', c.`table_name`, '` (', char(13), GROUP_CONCAT(CONCAT('  `', c.`column_name`, '` ', c.`data_type`, IF(c.`character_maximum_length` IS NULL, '', CONCAT('(', c.`character_maximum_length`, ')')), IF(c.`is_nullable` = 'NO', ' NOT NULL', '')) ORDER BY c.`ordinal_position` SEPARATOR ',\n'), char(13), ') ENGINE=', t.`engine`, ' DEFAULT CHARSET=', c.`character_set_name`, ';')) as ddl
				FROM	`information_schema`.`columns` c,
						`information_schema`.`columns` t
				WHERE	c.`table_schema`	= @vSchema
				AND		c.`table_name`		= myTable
				AND		c.`table_schema`	= t.`table_schema`
				AND		c.`table_name`		= t.`table_name`;

			INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('/*!40101 SET character_set_client = @saved_cs_client */;', char(13)));
/*
CREATE TEMPORARY TABLE `PARTITIONS` (
  `TABLE_CATALOG` varchar(512) NOT NULL DEFAULT '',
  `TABLE_SCHEMA` varchar(64) NOT NULL DEFAULT '',
  `TABLE_NAME` varchar(64) NOT NULL DEFAULT '',
  `PARTITION_NAME` varchar(64) DEFAULT NULL,
  `SUBPARTITION_NAME` varchar(64) DEFAULT NULL,
  `PARTITION_ORDINAL_POSITION` bigint(21) unsigned DEFAULT NULL,
  `SUBPARTITION_ORDINAL_POSITION` bigint(21) unsigned DEFAULT NULL,
  `PARTITION_METHOD` varchar(18) DEFAULT NULL,
  `SUBPARTITION_METHOD` varchar(12) DEFAULT NULL,
  `PARTITION_EXPRESSION` longtext,
  `SUBPARTITION_EXPRESSION` longtext,
  `PARTITION_DESCRIPTION` longtext,
  `TABLE_ROWS` bigint(21) unsigned NOT NULL DEFAULT '0',
  `AVG_ROW_LENGTH` bigint(21) unsigned NOT NULL DEFAULT '0',
  `DATA_LENGTH` bigint(21) unsigned NOT NULL DEFAULT '0',
  `MAX_DATA_LENGTH` bigint(21) unsigned DEFAULT NULL,
  `INDEX_LENGTH` bigint(21) unsigned NOT NULL DEFAULT '0',
  `DATA_FREE` bigint(21) unsigned NOT NULL DEFAULT '0',
  `CREATE_TIME` datetime DEFAULT NULL,
  `UPDATE_TIME` datetime DEFAULT NULL,
  `CHECK_TIME` datetime DEFAULT NULL,
  `CHECKSUM` bigint(21) unsigned DEFAULT NULL,
  `PARTITION_COMMENT` varchar(80) NOT NULL DEFAULT '',
  `NODEGROUP` varchar(12) NOT NULL DEFAULT '',
  `TABLESPACE_NAME` varchar(64) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8
*/
--  insert data

			SELECT	`table_rows`
            INTO	@num_rows
            FROM	`information_schema`.`tables`
            WHERE	`table_schema` = @mySchema
			AND		`table_name`   = @myTable;

			IF (@num_rows > 0) THEN

				INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('--', char(13), '-- Dumping data for table `', myTable, '`', char(13), '--', char(13)));

				SELECT	FLOOR((1024*1024*1024*16) / `avg_row_length`)	-- num rows in 16MB size
				INTO	@limit
				FROM	`information_schema`.`tables`
				WHERE	`table_schema` = @mySchema
				AND		`table_name`   = @myTable;

				INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('LOCK TABLE `', myTable, '` WRITE;'));
				INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('/*!40000 ALTER TABLE `', myTable, '` DISABLE KEYS */;', char(13)));

-- 				INSERT INTO `tmp_exp` (`txt`) VALUES (varstr);

				SET @offset = 0;

				get_data: LOOP

					INSERT INTO `tmp_exp` (`txt`)
						SELECT CONCAT('INSERT INTO ', myTable, ' (', GROUP_CONCAT(`column_name` ORDER BY `ordinal_position` SEPARATOR ','), ') VALUES') FROM `information_schema`.`columns` WHERE `table_schema` = @mySchema AND `table_name` = myTable;

					SELECT	CONCAT('INSERT INTO `tmp_exp` (`txt`) SELECT GROUP_CONCAT(''('',', GROUP_CONCAT(CONCAT('IFNULL(', IF(b.`family` IN ('datetime', 'string'), CONCAT('CONCAT('''''''', REPLACE(', IF(a.`data_type` = 'blob', CONCAT('CAST(', a.`column_name`, ' AS CHAR(10240) CHARACTER SET utf8)'), a.`column_name`), ','''', ''''''''), '''''''')'), a.`column_name`), ',''NULL'')') ORDER BY a.`ordinal_position` SEPARATOR ','','','),
						', '')'' SEPARATOR '', \n'') from ', @mySchema, '.', @myTable, ' LIMIT ', @limit, ' OFFSET ', @offset, ';')
					INTO	@sqlstr
					FROM	`information_schema`.`columns` a,
							`mysysutl`.`datatypes` b
					WHERE	`table_schema` = @mySchema
					AND		`table_name`   = @myTable
                    AND		a.`data_type`  = b.`name`
					GROUP BY `table_schema`, `table_name`
					ORDER BY `ordinal_position`;

					PREPARE sqlexe FROM @sqlstr;
                    EXECUTE sqlexe;
                    DEALLOCATE PREPARE sqlexe;

					SET @offset = @offset + @limit;

					IF (@offset > @num_rows) THEN
						INSERT INTO `tmp_exp` (`txt`) VALUES (';');
						LEAVE get_data;
					END IF;

				END LOOP get_data;

				INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('/*!40000 ALTER TABLE `', myTable, '` ENSABLE KEYS */;'));
				INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT(char(13), 'UNLOCK TABLES;', char(13)));

			END IF;

			CLOSE c_data;


		END LOOP get_tables;

		CLOSE c_tables;
/*
CREATE TEMPORARY TABLE `TABLE_CONSTRAINTS` (
  `CONSTRAINT_CATALOG` varchar(512) NOT NULL DEFAULT '',
  `CONSTRAINT_SCHEMA` varchar(64) NOT NULL DEFAULT '',
  `CONSTRAINT_NAME` varchar(64) NOT NULL DEFAULT '',
  `TABLE_SCHEMA` varchar(64) NOT NULL DEFAULT '',
  `TABLE_NAME` varchar(64) NOT NULL DEFAULT '',
  `CONSTRAINT_TYPE` varchar(64) NOT NULL DEFAULT ''
) ENGINE=MEMORY DEFAULT CHARSET=utf8
*/
--  get ddl for views

		INSERT INTO `tmp_exp` (`txt`)
			SELECT	CONCAT('CREATE VIEW ', `table_name`, ' AS ', char(13), `view_definition`, '$$', char(13), char(13)) as DDL
			FROM	`information_schema`.`views`
			WHERE	`table_schema` = @vSchema;

--  get ddl for procedures / functions

		INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('DELIMITER $$',char(13), char(13)));

		INSERT INTO `tmp_exp` (`txt`)
			SELECT	CONCAT('CREATE DEFINER=', r.`definer`, ' PROCEDURE ', r.`routine_schema`, '.', r.`specific_name`, ' ( ', char(13), IFNULL(GROUP_CONCAT(CONCAT(p.`parameter_mode`, ' ', p.`parameter_name`, ' ', p.`dtd_identifier` ) ORDER BY p.`ordinal_position` SEPARATOR ', '), ''), ' )', IF (IS_DETERMINISTIC = 'YES', ' DETERMINISTIC', ''), char(13), r.`routine_definition`, '$$', char(13), char(13)) as DDL
			FROM	`information_schema`.`routines`   r LEFT OUTER JOIN `information_schema`.`parameters` p
            ON		r.`routine_schema` = p.`specific_schema` AND r.`specific_name` = p.`specific_name`
			WHERE	r.`routine_schema` = @vSchema
			GROUP BY r.`routine_schema`, r.`specific_name`;

		INSERT INTO `tmp_exp` (`txt`) VALUES (CONCAT('DELIMITER ;',char(13), char(13)));

--  get ddl for triggers
/*
CREATE TEMPORARY TABLE `TRIGGERS` (
  `TRIGGER_CATALOG` varchar(512) NOT NULL DEFAULT '',
  `TRIGGER_SCHEMA` varchar(64) NOT NULL DEFAULT '',
  `TRIGGER_NAME` varchar(64) NOT NULL DEFAULT '',
  `EVENT_MANIPULATION` varchar(6) NOT NULL DEFAULT '',
  `EVENT_OBJECT_CATALOG` varchar(512) NOT NULL DEFAULT '',
  `EVENT_OBJECT_SCHEMA` varchar(64) NOT NULL DEFAULT '',
  `EVENT_OBJECT_TABLE` varchar(64) NOT NULL DEFAULT '',
  `ACTION_ORDER` bigint(4) NOT NULL DEFAULT '0',
  `ACTION_CONDITION` longtext,
  `ACTION_STATEMENT` longtext NOT NULL,
  `ACTION_ORIENTATION` varchar(9) NOT NULL DEFAULT '',
  `ACTION_TIMING` varchar(6) NOT NULL DEFAULT '',
  `ACTION_REFERENCE_OLD_TABLE` varchar(64) DEFAULT NULL,
  `ACTION_REFERENCE_NEW_TABLE` varchar(64) DEFAULT NULL,
  `ACTION_REFERENCE_OLD_ROW` varchar(3) NOT NULL DEFAULT '',
  `ACTION_REFERENCE_NEW_ROW` varchar(3) NOT NULL DEFAULT '',
  `CREATED` datetime DEFAULT NULL,
  `SQL_MODE` varchar(8192) NOT NULL DEFAULT '',
  `DEFINER` varchar(77) NOT NULL DEFAULT '',
  `CHARACTER_SET_CLIENT` varchar(32) NOT NULL DEFAULT '',
  `COLLATION_CONNECTION` varchar(32) NOT NULL DEFAULT '',
  `DATABASE_COLLATION` varchar(32) NOT NULL DEFAULT ''
) ENGINE=MyISAM DEFAULT CHARSET=utf8
*/


		INSERT INTO `tmp_exp` (`txt`)
			SELECT	CONCAT(char(13),
				'--', char(13),
				'-- Dumping events', char(13),
				'--', char(13), char(13),
				'/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;', char(13), char(13),
				'/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;', char(13),
				'/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;', char(13),
				'/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;', char(13),
				'/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;', char(13),
				'/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;', char(13),
				'/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;', char(13),
				'/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;', char(13), char(13),
				'-- Dump completed on ', NOW());

--  write results to file

		SET @file_name	= CONCAT(@vPath, '/dump_', DATE_FORMAT(NOW(), '%Y%m%d'), '.sql');
		SET @sqlstr		= CONCAT('SELECT txt INTO OUTFILE ''', @file_name, ''' FIELDS TERMINATED BY '''' OPTIONALLY ENCLOSED BY '''' LINES TERMINATED BY ''\\n'' FROM `tmp_exp` ORDER BY `row_id` ASC');

		PREPARE sqlexe FROM @sqlstr;

		EXECUTE sqlexe;

		DEALLOCATE PREPARE sqlexe;

		TRUNCATE TABLE `tmp_exp`;

	UNTIL LENGTH(l_Schemas) = 0
	END REPEAT l_Schemas;

	DROP TEMPORARY TABLE `tmp_exp`;

END$$

DELIMITER ;
