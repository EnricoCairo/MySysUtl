DELIMITER $$

DROP TABLE IF EXISTS `sysaux`.`snapshot`$$

CREATE TABLE `sysaux`.`snapshot` (
	`snap_id`			BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	`date`				DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	PRIMARY KEY (`snap_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8$$

DROP TABLE IF EXISTS `sysaux`.`snapshot_values`$$

CREATE TABLE `sysaux`.`snapshot_values` (
	`snap_id`			BIGINT(20) UNSIGNED NOT NULL,
	`category`			VARCHAR(64) NOT NULL DEFAULT '',
	`variable_name`		VARCHAR(64) NOT NULL DEFAULT '',
	`variable_value`	VARCHAR(1024) DEFAULT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8$$

DROP TABLE IF EXISTS `sysaux`.`snapshot_report`$$

CREATE TABLE `sysaux`.`snapshot_report` (
	`rep_id`			BIGINT(20) UNSIGNED NOT NULL AUTO_INCREMENT,
	`snap_id_start`		BIGINT(20) UNSIGNED NOT NULL,
	`snap_id_end`		BIGINT(20) UNSIGNED NOT NULL,
	`date`				DATETIME NOT NULL DEFAULT '0000-00-00 00:00:00',
	`rep_type`			ENUM('text', 'html', 'xml'),
	`report`			TEXT,
	PRIMARY KEY (`rep_id`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8$$

DROP PROCEDURE IF EXISTS `sysaux`.`create_snapshot`$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `sysaux`.`create_snapshot` (
) DETERMINISTIC CONTAINS SQL
BEGIN
	DECLARE id	BIGINT(20);

	INSERT INTO `sysaux`.`snapshot` (`date`) VALUES (NULL, NOW());
#	SELECT LAST_INSERT_ID() INTO id;
	SELECT MAX (`snap_id`) INTO id FROM `sysaux`.`snapshot`;

	# Version, Character set

	INSERT INTO `sysaux`.`snapshot_values` (`snap_id`, `category`, `variable_name`, `variable_value`)
		SELECT	`id`, 'Settings', `variable_name`, `variable_value`
		FROM	`information_schema`.`global_variables`
		WHERE	`variable_name` IN ('VERSION', 'CHARACTER_SET_SERVER', 'COLLATION_CONNECTION');

	# Security

	INSERT INTO `sysaux`.`snapshot_values` (`snap_id`, `category`, `variable_name`, `variable_value`)
		SELECT	`id`, 'Security', 'Null_passwd', CONCAT ('\'', user, '\'@\'', '\'', `host`, '\'')
		FROM	`mysql`.`user`
		WHERE	`password` = ''
		OR		`password` IS NULL;

	# Replication status

	INSERT INTO `sysaux`.`snapshot_values` (`snap_id`, `category`, `variable_name`, `variable_value`)
		SELECT	`id`, 'Replication', `variable_name`, `variable_value`
		FROM	`information_schema`.`global_status`
		WHERE	`variable_name` IN ('SLAVE_RUNNING', 'READ_ONLY');

	# Storage Engine Statistics

	INSERT INTO `sysaux`.`snapshot_values` (`snap_id`, `category`, `variable_name`, `variable_value`)
		SELECT	`id`, 'Storage', `engine`, SUM (`data_length`), COUNT (`engine`)
		FROM	`information_schema`.`tables`
		WHERE	`table_schema` NOT IN ('performance_schema', 'information_schema', 'mysql', 'sysaux')
		AND	engine IS NOT NULL
		GROUP BY engine
		ORDER BY engine ASC;


END$$

DROP FUNCTION IF EXISTS `sysaux`.`create_snapshot_auto`$$

CREATE DEFINER=`root`@`localhost` FUNCTION `sysaux`.`create_snapshot_auto` (
	i_start		TIME,
	i_delay		INT) RETURNS INT DETERMINISTIC CONTAINS SQL
BEGIN
	DECLARE clock TIMESTAMP DEFAULT CONCAT( CURDATE(), ' ', i_start);

	CREATE EVENT `get_a_snap`
	ON SCHEDULE AT clock + INTERVAL i_delay HOUR
	COMMENT 'Scheduled Statspack Snapshot'
	DO
		CALL `sysutl`.`create_snapshot`;

END$$

DROP FUNCTION IF EXISTS `sysaux`.`modify_snapshot_settings`$$

CREATE DEFINER=`root`@`localhost` FUNCTION `sysaux`.`modify_snapshot_settings` (
	i_delay		INT) RETURNS INT DETERMINISTIC CONTAINS SQL
BEGIN 
	ALTER EVENT `get_a_snap`
	ON SCHEDULE
		EVERY i_delay HOUR
		STARTS CURRENT_TIMESTAMP + INTERVAL 4 HOUR;
END$$

DELIMITER ;