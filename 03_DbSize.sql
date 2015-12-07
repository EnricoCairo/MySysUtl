-- -----------------------------------------------------------------------------
--
-- Databases grown size
--
-- -----------------------------------------------------------------------------
--
-- check the existance of following rows in your my.cnf (or my.ini)
--
-- [mysqld]
-- event_scheduler=on
--
-- -----------------------------------------------------------------------------

DELIMITER $$

USE `sysaux`$$

SELECT DATABASE(), VERSION(), NOW(), USER()$$

DROP TABLE IF EXISTS `mysysutl`.`db_size`$$

CREATE TABLE `mysysutl`.`db_size` (
	`log_time`		DATE		NOT NULL,
	`table_schema`	VARCHAR(64)	NOT NULL,
	`schema_size`	FLOAT		NOT NULL,
	`schema_free`	FLOAT		NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Database Grown Size Collection in MB'$$

DROP EVENT IF EXISTS `mysysutl`.`tbl_analyze`$$

CREATE DEFINER='root'@'localhost' EVENT `tbl_analyze`
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(DATE_FORMAT(DATE_ADD(CURRENT_DATE, INTERVAL 1 DAY),'%Y-%m-%d 00:05:00')) + INTERVAL 1 DAY
COMMENT 'Analyze all MyISAM and InnoDB tables to renew their statistics'
DO BEGIN

	DECLARE my_schema	VARCHAR(64);
	DECLARE my_table	VARCHAR(64);
	DECLARE end_cur		BOOLEAN DEFAULT FALSE;

	DECLARE c_table CURSOR FOR
		SELECT	`table_schema`, `table_name`
        FROM	`information_schema`.`tables`
        WHERE	`table_schema` != 'information_schema'
        AND		`engine` IN ('InnoDB', 'MyISAM');

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET end_cur = TRUE;

	SET @sqlstr = 'ANALYZE TABLE ?';
	PREPARE sqlexe FROM @sqlstr;

	OPEN c_table;

	get_table: LOOP

		FETCH c_table INTO my_schema, my_table;

		IF end_cur = TRUE THEN
			LEAVE get_table;
		END IF;

		SET @tbl_name = CONCAT('`', my_schema, '`.`', my_table, '`');

		EXECUTE sqlexe USING @tbl_name;

	END LOOP get_table;

	DEALLOCATE PREPARE sqlexe;

	CLOSE c_table;

END$$

DROP EVENT IF EXISTS `mysysutl`.`grown_monitor`$$

CREATE DEFINER='root'@'localhost' EVENT `grown_monitor`
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(DATE_FORMAT(DATE_ADD(CURRENT_DATE, INTERVAL 1 DAY),'%Y-%m-%d 00:15:00')) + INTERVAL 1 DAY
COMMENT 'Databases grown monitoring'
DO INSERT INTO `mysysutl`.`db_size` (`table_schema`, `schema_size`, `schema_free`)
		SELECT	DATE(NOW()),
				`table_schema`,
				ROUND(SUM(`data_length` + `index_length`) / 1024 / 1024, 1)	schema_size,
				ROUND(SUM(`data_free`) / 1024 / 1024, 1)					schema_free
		FROM	`information_schema`.`tables`
		WHERE	`table_schema` NOT IN ('mysql', 'information_schema', 'performance_schema')
		GROUP  BY `table_schema`$$

DELIMITER ;
