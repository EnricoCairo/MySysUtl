-- -----------------------------------------------------------------------------
--
-- General purpose
--
-- -----------------------------------------------------------------------------

DELIMITER $$

DROP TABLE IF EXISTS `sysaux`.`errors`$$

CREATE TABLE `sysaux`.`errors` (
	`errno`		SMALLINT UNSIGNED	NOT NULL,
	`errtxt`	VARCHAR(256)		NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Error messages'$$

INSERT INTO `sysaux`.`errors` (errno, errtxt) VALUES
		( 0, 'Ok'),
        ( 1, 'Value not found.'),
        ( 2, 'Account profile not found.'),
        ( 3, 'Account profile not set.'),
        ( 4, 'Username not set.'),
        ( 5, 'Action undefined or unknown.'),
        ( 6, 'Account profile allready exists.'),
        ( 7, 'Username not found.'),
        ( 8, 'The system tables must always be of the MyISAM type.'),
        ( 9, 'Input argument not set.')$$

DROP FUNCTION IF EXISTS `sysaux`.`release`$$

CREATE DEFINER=`root`@`localhost` FUNCTION  `sysaux`.`release` (
) RETURNS TEXT DETERMINISTIC NO SQL
BEGIN

	RETURN 'sysaux rel. 1.0  Alpha - 03-14-2015';

END$$

DROP FUNCTION IF EXISTS `sysaux`.`mem_usage`$$

CREATE DEFINER=`root`@`localhost` FUNCTION  `sysaux`.`mem_usage` (
) RETURNS FLOAT DETERMINISTIC READS SQL DATA
BEGIN

	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @key_buffer_size                 FROM information_schema.global_variables WHERE variable_name = 'key_buffer_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @query_cache_size                FROM information_schema.global_variables WHERE variable_name = 'query_cache_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @innodb_buffer_pool_size         FROM information_schema.global_variables WHERE variable_name = 'innodb_buffer_pool_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @innodb_additional_mem_pool_size FROM information_schema.global_variables WHERE variable_name = 'innodb_additional_mem_pool_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @innodb_log_buffer_size          FROM information_schema.global_variables WHERE variable_name = 'innodb_log_buffer_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @max_connections                 FROM information_schema.global_variables WHERE variable_name = 'max_connections';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @tmp_table_size                  FROM information_schema.global_variables WHERE variable_name = 'tmp_table_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @sort_buffer_size                FROM information_schema.global_variables WHERE variable_name = 'sort_buffer_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @read_buffer_size                FROM information_schema.global_variables WHERE variable_name = 'read_buffer_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @join_buffer_size                FROM information_schema.global_variables WHERE variable_name = 'join_buffer_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @read_rnd_buffer_size            FROM information_schema.global_variables WHERE variable_name = 'read_rnd_buffer_size';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @thread_stack                    FROM information_schema.global_variables WHERE variable_name = 'thread_stack';
	SELECT CAST(IFNULL(variable_value, '0') AS UNSIGNED)/1024/1024 INTO @binlog_cache_size               FROM information_schema.global_variables WHERE variable_name = 'binlog_cache_size';

	SELECT (@key_buffer_size + @query_cache_size + @innodb_buffer_pool_size + @innodb_additional_mem_pool_size + @innodb_log_buffer_size + @max_connections + @tmp_table_size) * (@sort_buffer_size + @read_buffer_size + @join_buffer_size + @read_rnd_buffer_size + @thread_stack + @binlog_cache_size) INTO @mysql_memory;

	RETURN ROUND(@mysql_memory/1024, 3);

END$$

DROP FUNCTION IF EXISTS `sysaux`.`regex_replace`$$

CREATE DEFINER=`root`@`localhost` FUNCTION  `sysaux`.`regex_replace` (
	pattern		VARCHAR(1024),
    str_repl	TEXT,
    str_src		TEXT
) RETURNS TEXT DETERMINISTIC NO SQL
BEGIN
	DECLARE str_tmp	TEXT;
	DECLARE ch		CHAR(1);
	DECLARE i		INT;

	SET i       = 1;
	SET str_tmp = '';

	IF str_src REGEXP pattern THEN

		loop_label: LOOP
			IF i > CHAR_LENGTH(str_src) THEN
				LEAVE loop_label;  
			END IF;

			SET ch = SUBSTRING(str_src, i, 1);

			IF ch REGEXP pattern THEN
				SET str_tmp = CONCAT(str_tmp, str_repl);
			ELSE
				SET str_tmp = CONCAT(str_tmp, ch);
			END IF;

			SET i  = i + 1;
		END LOOP;

	ELSE

		SET str_tmp = str_src;

	END IF;

	RETURN str_tmp;
END$$

DROP FUNCTION IF EXISTS `sysaux`.`get_str`$$

CREATE DEFINER=`root`@`localhost` FUNCTION `sysaux`.`get_str` (
	iStr		VARCHAR(1024),
	iVarName	VARCHAR(64),
	iDefault	VARCHAR(256)
) RETURNS VARCHAR(256) DETERMINISTIC NO SQL
BEGIN
	DECLARE i INT;
	DECLARE j INT;
	DECLARE k INT;
 	DECLARE s VARCHAR(256);

	SET i = INSTR(iStr, iVarName);

	IF i > 0 THEN
		SELECT INSTR(SUBSTR(iStr, i), ',') INTO j;

		IF j > 0 THEN
			SET s = SUBSTR(iStr, i, j-1);
		ELSE
			SET s = SUBSTR(iStr, i);
		END IF;

		SET k = INSTR(SUBSTR(s, i), '=>');

		IF k > 0 THEN
			RETURN SUBSTR(s, k+2);
		ELSE
			RETURN null;
		END IF;
	ELSE
		RETURN iDefault;
	END IF;
END$$

DROP FUNCTION IF EXISTS `sysaux`.`get_int`$$

CREATE DEFINER=`root`@`localhost` FUNCTION `sysaux`.`get_int` (
	iStr		VARCHAR(1024),
	iVarName	VARCHAR(64),
	iDefault	VARCHAR(256)
) RETURNS INT DETERMINISTIC NO SQL
BEGIN
	RETURN CAST(`sysaux`.`get_str`(iStr, iVarName, iDefault) AS UNSIGNED);
END$$

DELIMITER ;