-- -----------------------------------------------------------------------------
--
-- Audit
--
-- -----------------------------------------------------------------------------
--
-- check the existance of following rows in your my.cnf (or my.ini)
--
-- [mysqld]
-- general-log
-- slow-query-log
-- log-output=TABLE
--
-- -----------------------------------------------------------------------------

DELIMITER $$

USE `sysaux`$$

SELECT DATABASE(), VERSION(), NOW(), USER()$$

-- Audit log

DROP TABLE IF EXISTS `sysaux`.`audit_log`$$

CREATE TABLE `sysaux`.`audit_log` (
	`thread_id`			BIGINT(21)		UNSIGNED NOT NULL DEFAULT 0,
    `user_host`			MEDIUMTEXT		NOT NULL,
    `login_ts`			TIMESTAMP		NULL,
	`logout_ts`			TIMESTAMP		NULL,
    `com_select`		INT UNSIGNED 	NOT NULL DEFAULT 0,
    `bytes_received`	BIGINT UNSIGNED	NOT NULL DEFAULT 0,
    `bytes_sent`		BIGINT UNSIGNED	NOT NULL DEFAULT 0
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Audit log'
PARTITION BY RANGE( unix_timestamp(`login_ts`) ) (
	PARTITION P_MAX  VALUES LESS THAN MAXVALUE
)$$

-- General log

DROP TABLE IF EXISTS `sysaux`.`general_log`$$

CREATE TABLE `sysaux`.`general_log` LIKE `mysql`.`general_log`$$

ALTER TABLE `sysaux`.`general_log` ENGINE=MyISAM$$

ALTER TABLE `sysaux`.`general_log` PARTITION BY RANGE( unix_timestamp(`event_time`) ) (
	PARTITION P_MAX  VALUES LESS THAN MAXVALUE
)$$

ALTER TABLE `sysaux`.`general_log` ADD INDEX (`event_time`)$$

-- Slow log

DROP TABLE IF EXISTS `sysaux`.`slow_log`$$

CREATE TABLE `sysaux`.`slow_log` like `mysql`.`slow_log`$$

ALTER TABLE `sysaux`.`slow_log` ENGINE=MyISAM$$

ALTER TABLE `sysaux`.`slow_log` PARTITION BY RANGE( UNIX_TIMESTAMP(`start_time`) ) (
	PARTITION P_MAX  VALUES LESS THAN MAXVALUE
)$$

ALTER TABLE `sysaux`.`slow_log` ADD INDEX (`start_time`)$$

DROP PROCEDURE IF EXISTS `sysaux`.`partition_management`$$

CREATE DEFINER='root'@'localhost' PROCEDURE `sysaux`.`partition_management` (
	IN	tab_array	VARCHAR(512),
    IN	nextMonth	BOOLEAN
) DETERMINISTIC CONTAINS SQL
BEGIN

	SET @my_array = tab_array;

	SELECT	CONCAT('P_', DATE_FORMAT(DATE_ADD(NOW(), INTERVAL nextMonth MONTH), '%Y%m')),
			CONCAT(DATE_FORMAT(DATE_ADD(NOW(), INTERVAL (nextMonth + 1) MONTH), '%Y-%m'), '-01 00:00:00')
	INTO	@new_part_name,
			@new_part_limit;

	SET @sqlstr = 'ALTER TABLE ? REORGANIZE PARTITION P_MAX INTO (PARTITION ? VALUES LESS THAN ( UNIX_TIMESTAMP(''?'') ), PARTITION P_MAX VALUES LESS THAN MAXVALUE)';
	PREPARE sqlexe FROM @sqlstr;

	l_array: REPEAT

			SELECT SUBSTRING(@my_array, 1, LOCATE(',', my_array) - 1) INTO @tbl_name;
			SELECT SUBSTRING(@my_array,    LOCATE(',', my_array) + 1) INTO @my_array;

			IF LENGTH(@tbl_name) = 0 THEN
				SET @tbl_name  = @my_array;
				SET @my_array = '';
			END IF;

			EXECUTE sqlexe USING @tbl_name, @new_part_name, @new_part_limit;

	UNTIL LENGTH(my_array) = 0
	END REPEAT l_array;

	DEALLOCATE PREPARE sqlexe;

END$$

CALL `sysaux`.`partition_managment` ('`sysaux`.`audit_log`,`sysaux`.`general_log`,`sysaux`.`slow_log`', FALSE)$$

-- Audit views

DROP VIEW IF EXISTS `sysaux`.`v$audit_general`$$

CREATE VIEW `sysaux`.`v$audit_general` AS
	SELECT	ses.*,
			gen.`command_type`,
            gen.`argument`
    FROM	`sysaux`.`audit_log`	ses,
			`sysaux`.`general_log`	gen
	WHERE	ses.`thread_id` = gen.`thread_id`
    AND		gen.`event_time` BETWEEN ses.`login_ts` AND ses.`logout_ts`$$

DROP VIEW IF EXISTS `sysaux`.`v$audit_slow`$$

CREATE VIEW `sysaux`.`v$audit_slow` AS
   	SELECT	ses.*,
			slo.`sql_text`
	FROM	`sysaux`.`audit_log`	ses,
			`sysaux`.`slow_log`		slo
	WHERE	ses.`thread_id` = slo.`thread_id`
	AND		slo.`start_time` BETWEEN ses.`login_ts` AND ses.`logout_ts`$$

DROP EVENT IF EXISTS `sysaux`.`audit_populate`$$

CREATE DEFINER='root'@'localhost' EVENT `audit_populate`
ON SCHEDULE EVERY 1 HOUR STARTS TIMESTAMP(DATE_FORMAT(DATE_ADD(CURRENT_TIME, INTERVAL 1 HOUR),'%Y-%m-%d %H:00:00')) + INTERVAL 1 HOUR
COMMENT 'Audit populate'
DO BEGIN

	INSERT INTO `sysaux`.`general_log`
		SELECT	*
		FROM	`mysql`.`general_log`
        WHERE	`general_log`.`event_time` > (SELECT MAX(`event_time`) FROM `sysaux`.`general_log`);

	INSERT INTO `sysaux`.`slow_log`
		SELECT	*
		FROM	`mysql`.`slow_log`
        WHERE	`slow_log`.`start_time` > (SELECT MAX(`start_time`) FROM `sysaux`.`slow_log`);

END$$

DROP EVENT IF EXISTS `mysql`.`audit_purge`$$

CREATE DEFINER='root'@'localhost' EVENT `audit_purge`
ON SCHEDULE EVERY 1 MONTH STARTS LAST_DAY(NOW()) + INTERVAL 1 MONTH
COMMENT 'Audit cleanup'
DO BEGIN

	CALL `sysaux`.`partition_managment`('`sysaux`.`audit_log`,`sysaux`.`general_log`,`sysaux`.`slow_log`', TRUE);

-- 	SET global general_log = OFF;

	SET @tbl_Array   = 'general_log,slow_log';
	SET @sqlcreate   = 'CREATE TABLE `sysaux`.`dummy_log` LIKE mysql.?';
	SET @sqltruncate = 'TRUNCATE TABLE mysql.?';

	PREPARE sqlcreate FROM @sqlcre;
	PREPARE sqlrename FROM @sqlren;

	l_tbl: REPEAT

		SELECT SUBSTRING(@tbl_Array, 1, LOCATE(',', @tbl_Array) - 1) INTO @tbl_name;
		SELECT SUBSTRING(@tbl_Array,    LOCATE(',', @tbl_Array) + 1) INTO @tbl_Array;

		IF LENGTH(@tbl_name) = 0 THEN
			SET @tbl_name  = @tbl_Array;
			SET @tbl_Array = '';
		END IF;

		DROP TABLE IF EXISTS `mysql`.`dummy_log`;

		EXECUTE sqlcreate   USING @tbl_name;
		EXECUTE sqltruncate USING @tbl_name;

	UNTIL LENGTH(@tbl_Array) = 0
	END REPEAT l_tbl;

	DEALLOCATE PREPARE sqlcreate;
	DEALLOCATE PREPARE sqlrename;

	INSERT INTO `sysaux`.`general_log`
        SELECT	*
		FROM	`sysaux`.`dummy_general_log`
        WHERE	`dummy_general_log`.`event_time` > (SELECT MAX(`event_time`) FROM `sysaux`.`general_log`);

	INSERT INTO `sysaux`.`slow_log`
        SELECT	*
		FROM	`sysaux`.`dummy_slow_log`
        WHERE	`dummy_slow_log`.`start_time` > (SELECT MAX(`start_time`) FROM `sysaux`.`slow_log`);

		DROP TABLE `mysql`.`dummy_general_log`;
		DROP TABLE `mysql`.`dummy_slow_log`;

-- 	SET global general_log = ON;

END$$

DELIMITER ;
