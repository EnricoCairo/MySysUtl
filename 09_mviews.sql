-- -----------------------------------------------------------------------------
--
-- Materialized views implementation
--
-- -----------------------------------------------------------------------------

DELIMITER $$

USE `mysysutl`$$

SELECT DATABASE(), VERSION(), NOW(), USER()$$

DROP TABLE IF EXISTS `mysysutl`.`mviews`$$

CREATE TABLE `mysysutl`.`mviews` (
	`schema_name`	VARCHAR(64)	NOT NULL,
	`name`			VARCHAR(64)	NOT NULL,
    `creation_date`	DATE		NOT NULL,
    `interval`		INT			NOT NULL,
--     `type`			ENUM ('FAST', 'COMPLETE')	NOT NULL,
    `definition`	TEXT		NOT NULL
) ENGINE=MyISAM$$

DROP FUNCTION IF EXISTS `mysysutl`.`mviews_man`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`mviews_man` (
	iStr		TEXT
) RETURNS INT DETERMINISTIC MODIFIES SQL DATA 
BEGIN

	SET @vAction	= `mysysutl`.`get_str`(iStr, 'ACTION', '');
    SET @vSchema	= `mysysutl`.`get_str`(iStr, 'SCHEMA', '');
    SET @vName		= `mysysutl`.`get_str`(iStr, 'MVIEW' , '');
    SET @vQuery		= `mysysutl`.`get_str`(iStr, 'QUERY' , '');

	IF	@vAction = '' OR @vSchema = '' OR @vName = '' THEN
		SET ErrNo = 3;
	ELSE
		CASE LOWER(@vAction)
		WHEN 'create' THEN	-- chk allready exists
			IF  @vQuery = '' THEN
				SET ErrNo = 3;
            ELSE
				BEGIN
					INSERT INTO `mysysutl`.`mviews` (`schema_name`, `name`, `creation_date`, `definition`) VALUES (@vSchema, @vName, NOW(), @vQuery);

-- can't run
-- substitute with event that scan table looking for interval                    
					set @sqlstr = CONCAT(' CREATE TABLE ', @vName, ' ', @vQuery);
					PREPARE sqlexe from @sqlstr;
					EXECUTE sqlexe;
					DEALLOCATE PREPARE sqlexe;

					SET @sqlstr = CONCAT(	'DELIMITER $$ ',
											'CREATE DEFINER=''root''@''localhost'' EVENT `refresh_', @vSchema, '_', @vName, '` ',
                                            'ON SCHEDULE EVERY 1 DAY STARTS LAST_DAY(NOW()) + INTERVAL 1 DAY ',
                                            'DO BEGIN ',
                                            'CALL `mysysutl`.`mviews_refresh`(', @vSchema, ',', @vName ,'); ',
                                            'END $$ ',
                                            'DELIMITER ;');
					SET ErrNo = 0;
				END;
			END IF;
		WHEN 'drop' THEN
			BEGIN
				DELETE FROM `mysysutl`.`mviews` WHERE `schema_name` = @vSchema AND `name` = @vName;

				SET @sqlstr = CONCAT('DROP EVENT IF EXISTS `refresh_', @vSchema, '_', @vName);
				PREPARE sqlexe from @sqlstr;
				EXECUTE sqlexe;
				DEALLOCATE PREPARE sqlexe;

				SET ErrNo = 0;
			END;
		ELSE
			SET ErrNo = 5;
		END CASE;
	END IF;

END $$

DROP FUNCTION IF EXISTS `mysysutl`.`mviews_refresh`$$

CREATE DEFINER='root'@'localhost' FUNCTION `mysysutl`.`mviews_refresh` (
) RETURNS INT DETERMINISTIC MODIFIES SQL DATA 
BEGIN

	SET @sqlstr = CONCAT('TRUNCATE TABLE ', schema_name, '.', name);

	PREPARE sqlexe from @sqlstr;
	EXECUTE sqlexe;
	DEALLOCATE PREPARE sqlexe;

	SELECT	CONCAT('INSERT INTO `', schema_name, '`.`', name, '` ', `definition`)
    INTO	@sqlstr
    FROM	`mysysutl`.`mviews`
    WHERE	`schema_name` = schema_name
    AND		`name`        = name;

	PREPARE sqlexe from @sqlstr;
	EXECUTE sqlexe;
	DEALLOCATE PREPARE sqlexe;

END $$

DELIMITER ;
