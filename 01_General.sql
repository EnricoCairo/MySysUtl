-- -----------------------------------------------------------------------------
--
-- General purpose
--
-- -----------------------------------------------------------------------------

DELIMITER $$

USE `sysaux`$$

SELECT DATABASE(), VERSION(), NOW(), USER()$$

DROP TABLE IF EXISTS `mysysutl`.`sequence_data`$$

CREATE TABLE `mysysutl`.`sequence_data` (
	`schema_name`			VARCHAR(64)				NOT NULL,
	`sequence_name`			VARCHAR(32)				NOT NULL,
	`sequence_increment`	INT(11)		UNSIGNED	NOT NULL,
	`sequence_min_value`	INT(11)		UNSIGNED	NOT NULL,
	`sequence_max_value`	BIGINT(20)	UNSIGNED	NOT NULL,
	`sequence_cur_value`	BIGINT(20)	UNSIGNED	NOT NULL,
	`sequence_cycle`		BOOLEAN					NOT NULL,
	PRIMARY KEY (`sequence_name`)
) ENGINE=MyISAM DEFAULT CHARSET=utf8$$

DROP TABLE IF EXISTS `mysysutl`.`errors`$$

CREATE TABLE `mysysutl`.`errors` (
	`errno`				SMALLINT	UNSIGNED	NOT NULL,
	`errtxt`			VARCHAR(256)			NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Error messages'$$

INSERT INTO `mysysutl`.`errors` (errno, errtxt) VALUES
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

DROP FUNCTION IF EXISTS `mysysutl`.`version`$$

CREATE DEFINER='root'@'localhost' FUNCTION  `mysysutl`.`version` (
) RETURNS TEXT DETERMINISTIC NO SQL
BEGIN

	RETURN 'MySysUtl rel. 1.0  Alpha - 03-14-2015';

END$$

DROP FUNCTION IF EXISTS `mysysutl`.`mem_usage`$$

CREATE DEFINER='root'@'localhost' FUNCTION  `mysysutl`.`mem_usage` (
) RETURNS DECIMAL(10,3) DETERMINISTIC READS SQL DATA
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

DROP FUNCTION IF EXISTS `mysysutl`.`regex_replace`$$

CREATE DEFINER='root'@'localhost' FUNCTION  `mysysutl`.`regex_replace` (
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

DROP FUNCTION IF EXISTS `mysysutl`.`get_str`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`get_str` (
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

		SET k = INSTR(s, '=>');

		IF k > 0 THEN
			RETURN SUBSTR(s, k+2);
		ELSE
			RETURN null;
		END IF;
	ELSE
		RETURN iDefault;
	END IF;
END$$

DROP FUNCTION IF EXISTS `mysysutl`.`get_int`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`get_int` (
	iStr		VARCHAR(1024),
	iVarName	VARCHAR(64),
	iDefault	VARCHAR(256)
) RETURNS INT DETERMINISTIC NO SQL
BEGIN
	RETURN CAST(`mysysutl`.`get_str`(iStr, iVarName, iDefault) AS UNSIGNED);
END$$

DROP FUNCTION IF EXISTS `mysysutl`.`sequence`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`sequence` (
	iStr		VARCHAR(1024)
) RETURNS INT DETERMINISTIC MODIFIES SQL DATA
BEGIN

	DECLARE ErrNo			INT			DEFAULT 0;

	DECLARE EXIT HANDLER FOR NOT FOUND SET ErrNo=2;
	DECLARE EXIT HANDLER FOR SQLSTATE '23000' SET ErrNo=6; # duplicate entry

	SET @vAction	= `mysysutl`.`get_str`(iStr, 'ACTION'       , '');
	SET @vSchema	= `mysysutl`.`get_str`(iStr, 'SCHEMA'       , '');
	SET @vName		= `mysysutl`.`get_str`(iStr, 'SEQUENCE_NAME', '');
	SET @vIncrement	= `mysysutl`.`get_int`(iStr, 'INCREMENT'    , '1');
	SET @vMinValue	= `mysysutl`.`get_int`(iStr, 'MIN_VALUE'    , '1');
	SET @vMaxValue	= `mysysutl`.`get_int`(iStr, 'MAX_VALUE'    , '18446744073709551615'); -- Max value for unsigned bigint type
	SET @vCurValue	= `mysysutl`.`get_int`(iStr, 'CUR_VALUE'    , '1');
	SET @vCycle		= `mysysutl`.`get_int`(iStr, 'CYCLE'        , '0');

	IF	@vAction = '' OR @vSchema = '' OR @vName = '' THEN
		SET ErrNo = 3;
	ELSE
		CASE LOWER(@vAction)
		WHEN 'create' THEN
			BEGIN
				INSERT INTO `mysysutl`.`sequence_data` VALUES (@vSchema, @vName, @vIncrement, @vMinValue, @vMaxValue, @vCurValue, @vCycle);

				SET ErrNo = 0;
			END;
		WHEN 'update' THEN
			BEGIN
				UPDATE	`mysysutl`.`sequence_data`
				SET		`sequence_increment`	= @vIncrement,
						`sequence_min_value`	= @vMinValue,
						`sequence_max_value`	= @vMaxValue,
						`sequence_cur_value`	= @vCurValue,
                        `sequence_cycle`		= @vCycle
				WHERE	`schema_name`			= @vSchema
                AND		`sequence_name`			= @vName;

				SET ErrNo = 0;
			END;
		WHEN 'delete' THEN
			BEGIN
				DELETE FROM `mysysutl`.`sequence_data` WHERE `schema_name` = @vSchema AND `sequence_name` = @vName;

				SET ErrNo = 0;
			END;
		ELSE
			SET ErrNo = 5;
		END CASE;
	END IF;

    RETURN ErrNo;
END$$

DROP FUNCTION IF EXISTS `mysysutl`.`curval`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`curval`(
	mySchema	VARCHAR(64),
	mySequence	VARCHAR(32)
) RETURNS BIGINT(20) DETERMINISTIC MODIFIES SQL DATA
BEGIN
	DECLARE cur_val BIGINT(20);
 
	SELECT	`sequence_cur_value`
    INTO	cur_val
	FROM	`mysysutl`.`sequence_data`
	WHERE	`schema_name`   = mySchema
    AND		`sequence_name` = mySequence;
 
    RETURN cur_val;
END$$

DROP FUNCTION IF EXISTS `mysysutl`.`nextval`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`nextval`(
	mySchema	VARCHAR(64),
	mySequence	VARCHAR(32)
) RETURNS BIGINT(20) DETERMINISTIC MODIFIES SQL DATA
BEGIN
	DECLARE cur_val BIGINT(20);
 
	SET cur_val = `mysysutl`.`curval`(mySchema, mySequence);
 
	IF cur_val IS NOT NULL THEN
		UPDATE	`mysysutl`.`sequence_data`
		SET		`sequence_cur_value` = IF ((`sequence_cur_value` + `sequence_increment`) > `sequence_max_value`,
											IF (`sequence_cycle` = TRUE, `sequence_min_value`, NULL),
											`sequence_cur_value` + `sequence_increment`)
		WHERE	`schema_name`   = mySchema
		AND		`sequence_name` = mySequence;
    END IF;
 
    RETURN cur_val;
END$$

DELIMITER ;
