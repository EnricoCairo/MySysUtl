-- -----------------------------------------------------------------------------
--
-- Quota management
--
-- -----------------------------------------------------------------------------

DELIMITER $$

DROP TABLE IF EXISTS `sysaux`.`quota`$$

CREATE TABLE `sysaux`.`quota` (
	`table_schema`	VARCHAR(64)	NOT NULL,
	`limit_in_mb`	INT			NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Disk quota allowed per schema'$$

DROP TABLE IF EXISTS `sysaux`.`quota_exceed`$$

CREATE TABLE `sysaux`.`quota_exceed` (
	`table_schema`	VARCHAR(64)	NOT NULL,
	`grantee`		VARCHAR(81)	NOT NULL
) ENGINE=MyISAM DEFAULT CHARSET=utf8 COMMENT='Disk quota exceeded'$$

DROP FUNCTION IF EXISTS `sysaux`.`chk_quota`$$
-- DA FARE !!!
CREATE DEFINER=`root`@`localhost` FUNCTION  `sysaux`.`chk_quota` (
) RETURNS FLOAT DETERMINISTIC READS SQL DATA
BEGIN

	DECLARE end_cur				BOOLEAN DEFAULT FALSE;
    
    DECLARE my_table_schema		VARCHAR(64);
    DECLARE my_limit_in_mb		FLOAT;
    DECLARE my_grantee			VARCHAR(81);
    DECLARE my_size_in_mb		FLOAT;

	DECLARE c_unlock CURSOR FOR
		SELECT	a.`table_schema`,
				b.`limit_in_mb`,
                c.`grantee`,
				round (SUM(((a.`table_rows` * a.`avg_row_length`) / 1024 / 1024)), 2) as size_in_mb
		FROM	`information_schema`.`tables` a,
				`sysaux`.`quota` b,
				`sysaux`.`quota_execed` c
		WHERE	a.`table_schema` = b.`table_schema`
        AND		a.`table_schema` = c.`table_schema`
		GROUP BY a.`table_schema`
		HAVING  b.`limit_in_mb` > size_in_mb;

	DECLARE c_lock CURSOR FOR
		SELECT	a.`table_schema`,
				b.`limit_in_mb`,
				round (SUM(((a.`table_rows` * a.`avg_row_length`) / 1024 / 1024)), 2) as size_in_mb
		FROM	`information_schema`.`tables` a,
				`sysaux`.`quota` b
		WHERE	a.`table_schema` = b.`table_schema`
		GROUP BY a.`table_schema`
		HAVING  b.`limit_in_mb` <= size_in_mb;

	DECLARE c_revoke CURSOR FOR
		SELECT	a.`table_schema`,
				a.`grantee`
		FROM	`information_schema`.`tables` a,
				`sysaux`.`quota_exceed` b
		WHERE	a.`table_schema` = b.`table_schema`;

	DECLARE CONTINUE HANDLER FOR NOT FOUND SET end_cur = TRUE;

	OPEN c_unlock;

	get_unlock: LOOP

		FETCH c_unlock INTO my_table_schema, my_limit_in_mb, my_grantee;

		IF end_cur = TRUE THEN
			LEAVE get_unlock;
		END IF;

	END LOOP get_unlock;

	CLOSE c_unlock;

	SET end_cur = FALSE;

	OPEN c_lock;

	get_lock: LOOP

		FETCH c_lock INTO my_table_schema, my_limit_in_mb, my_size_in_mb;

		IF end_cur = TRUE THEN
			LEAVE get_lock;
		END IF;

	END LOOP get_lock;

	CLOSE c_lock;

	SET end_cur = FALSE;
    
    RETURN 0;

END$$

DELIMITER ;