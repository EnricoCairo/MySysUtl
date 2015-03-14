-- -----------------------------------------------------------------------------
--
-- Debug
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

DROP TABLE IF EXISTS `sysaux`.`log`$$

CREATE TABLE `sysaux`.`log` (
	`log_time`	TIMESTAMP(6)	DEFAULT CURRENT_TIMESTAMP(6),
	`conn_id`	INT(11)			NOT NULL DEFAULT '0',
	`msg`		VARCHAR(512)	DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Debug log'$$

DROP PROCEDURE IF EXISTS `sysaux`.`log_setup`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sysaux`.`log_setup` ()
DETERMINISTIC CONTAINS SQL
BEGIN
	DECLARE log_chk INT DEFAULT 0;

    SELECT	COUNT(*) INTO log_chk
    FROM	information_schema.tables
    WHERE	table_schema = database()
    AND		table_name   = 'log';

	IF log_chk = 0 THEN
		CREATE TABLE IF NOT EXISTS `log` (
				`log_time`	TIMESTAMP(6)	NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
				`conn_id`	INT(11)			NOT NULL DEFAULT '0',
				`msg`		VARCHAR(512)	DEFAULT NULL);
	END IF;

	CREATE TEMPORARY TABLE IF NOT EXISTS `tmp_log` (
			`log_time`	TIMESTAMP(6)	NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
			`conn_id`	INT(11)			NOT NULL DEFAULT '0',
			`msg`		VARCHAR(512)	DEFAULT NULL) ENGINE=memory;
	
END$$

DROP PROCEDURE IF EXISTS `sysaux`.`logger`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sysaux`.`logger` (
	IN logMsg VARCHAR(512)
) DETERMINISTIC MODIFIES SQL DATA
BEGIN
	DECLARE CONTINUE HANDLER FOR 1146 -- Table not found
	BEGIN
		CALL `sysaux`.`log_setup`();

		INSERT INTO `tmp_log` (conn_id, msg) VALUES (CONNECTION_ID(), logMsg);
	END;

	INSERT INTO `tmp_proclog` (conn_id, msg) VALUES (CONNECTION_ID(), logMsg);
END$$

DROP PROCEDURE IF EXISTS `sysaux`.`log_cleanup`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sysaux`.`log_cleanup` (
	IN logMsg VARCHAR(512)
) DETERMINISTIC MODIFIES SQL DATA
BEGIN
	CALL `sysaux`.`logger`(CONCAT("cleanup() ", IFNULL(logMsg, '')));
    
	INSERT INTO `sysaux`.`log` SELECT * FROM `tmp_log`;
	DROP TABLE `tmp_log`;
END$$

DROP EVENT IF EXISTS `sysaux`.`log_purge`$$

CREATE DEFINER=`root`@`localhost` EVENT `log_purge`
ON SCHEDULE EVERY 1 DAY STARTS TIMESTAMP(DATE_ADD(CURRENT_DATE, INTERVAL 1 DAY), '00:05:00') + INTERVAL 1 DAY
COMMENT 'log cleanup'
DO BEGIN
	DELETE FROM `sysaux`.`log` WHERE DATEDIFF(DATE_FORMAT(NOW(), '%Y-%m-%d'), DATE_FORMAT(`log_time`, '%Y-%m-%d')) > 30;
END$$

DELIMITER ;