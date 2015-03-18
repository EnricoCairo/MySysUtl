-- -----------------------------------------------------------------------------
--
-- Account profiles management
--
-- -----------------------------------------------------------------------------

DELIMITER $$

DROP TABLE IF EXISTS `sysaux`.`profiles`$$

CREATE TABLE `sysaux`.`profiles` (
	`profile`					VARCHAR(64)	NOT NULL,
	`max_queries_per_hour`		INT			NOT NULL DEFAULT 0,
	`max_updates_per_hour`		INT			NOT NULL DEFAULT 0,
	`max_connections_per_hour`	INT			NOT NULL DEFAULT 0,
	`max_user_connections`		INT			NOT NULL DEFAULT 0
) ENGINE=MyISAM$$

CREATE FUNCTION `sysaux`.`profile_man` (
	iStr		VARCHAR(1024)
) RETURNS INT DETERMINISTIC MODIFIES SQL DATA 
BEGIN
	DECLARE vHost			VARCHAR(64);
	DECLARE ErrNo			INT			DEFAULT 0;
	DECLARE i				INT;
	DECLARE cUser 			CURSOR FOR SELECT host FROM `mysql`.`user` WHERE `user` = vUser;

	DECLARE EXIT HANDLER FOR NOT FOUND SET ErrNo=2;
	DECLARE EXIT HANDLER FOR SQLSTATE '23000' SET ErrNo=6; # duplicate entry

	SET @vAction		= `sysaux`.`get_str`(iStr, 'ACTION'                  , '');
	SET @vUser			= `sysaux`.`get_str`(iStr, 'USER'                    , '');
	SET @vProfile		= `sysaux`.`get_str`(iStr, 'PROFILE'                 , 'default');
	SET @vMaxQueries	= `sysaux`.`get_int`(iStr, 'MAX_QUERIES_PER_HOUR'    , '0');
	SET @vMaxUpdates	= `sysaux`.`get_int`(iStr, 'MAX_UPDATES_PER_HOUR'    , '0');
	SET @vMaxConnHour	= `sysaux`.`get_int`(iStr, 'MAX_CONNECTIONS_PER_HOUR', '0');
	SET @vMaxUsrConn	= `sysaux`.`get_int`(iStr, 'MAX_USER_CONNECTIONS'    , '0');

	IF	vProfile = '' THEN
		SET ErrNo = 3;
	ELSE
		CASE LOWER(vAction)
		WHEN 'create' THEN
			BEGIN
				INSERT INTO `sysaux`.`profiles` VALUES (vProfile, vMaxQueries, vMaxUpdates, vMaxConnHour, vMaxUsrConn);

				SET ErrNo = 0;
			END;
		WHEN 'modify' THEN
			BEGIN
				UPDATE	`sysaux`.`profiles`
				SET		`max_queries_per_hour`		= vMaxQueries,
						`max_updates_per_hour`		= vMaxUpdates,
						`max_connections_per_hour`	= vMaxConnHour,
						`max_user_connections`		= vMaxUsrConn
				WHERE	`profile`					= vProfile;

				SET ErrNo = 0;
			END;
		WHEN 'delete' THEN
			BEGIN
				DELETE FROM `sysaux`.`profiles` WHERE `profile` = vProfile;

				SET ErrNo = 0;
			END;
		WHEN 'set' THEN
			BEGIN
				IF vUser = '' THEN
					SET ErrNo = 4;
				ELSE
					OPEN cUser;

					SELECT found_rows() INTO i;

					IF i = 0 THEN
						SET ErrNo = 7;
					ELSE
						SET @sqlstr = CONCAT('GRANT USAGE ON *.* TO ? ',
											'WITH MAX_QUERIES_PER_HOUR ? ',
											'MAX_UPDATES_PER_HOUR ? ',
											'MAX_CONNECTIONS_PER_HOUR ? ',
                                            'MAX_USER_CONNECTIONS ?');

						PREPARE sqlexe FROM @sqlstr;

						the_loop: LOOP
							FETCH cUser INTO vHost;
                            
                            SET @account = CONCAT('''', @vUser, '''@''', vHost, '''');

							EXECUTE sqlexe USING @account, @vMaxQueries, @vMaxUpdates, @vMaxConnHour, @vMaxUsrConn;

							SET i = i -1;

							IF i = 0 THEN
								LEAVE the_loop;
							END IF;

						END LOOP the_loop;

						DEALLOCATE PREPARE sqlexe;

						CLOSE cUser;

						SET ErrNo = 0;
					END IF;
				END IF;
			END;
		ELSE
			SET ErrNo = 5;
		END CASE;
	END IF;

    RETURN ErrNo;
END $$

SELECT `sysaux`.`profile_man`('ACTION=>create,PROFILE=>default,MAX_QUERIES_PER_HOUR=>0,MAX_UPDATES_PER_HOUR=>0,MAX_CONNECTIONS_PER_HOUR=>0,MAX_USER_CONNECTIONS=>0')$$
SELECT `sysaux`.`profile_man`('ACTION=>create,PROFILE_NAME=>guest,MAX_QUERIES_PER_HOUR=>5,MAX_UPDATES_PER_HOUR=>1,MAX_CONNECTIONS_PER_HOUR=>1,MAX_USER_CONNECTIONS=>1')$$

DELIMITER ;