/*
1) Write a procedure for adding P2P check
Parameters: nickname of the person being checked, checker's nickname, task name, P2P check status, time.
If the status is "start", add a record in the Checks table (use today's date).
Add a record in the P2P table.
If the status is "start", specify the record just added as a check, otherwise specify the check with the unfinished P2P step.
*/
CREATE OR REPLACE PROCEDURE add_p2p_check(
    IN p_nickname VARCHAR,
    IN p_checker_nickname VARCHAR,
    IN p_task_name VARCHAR,
    IN p_check_status checkstatus,
    IN p_time TIME
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_check_status = 'Start' THEN
        INSERT INTO checks (id, peer, task, date)
        VALUES ((SELECT MAX(id) FROM checks) + 1, p_nickname, p_task_name, CURRENT_DATE);

        INSERT INTO p2p (id, Check_ID, checkingpeer, P2P_check_status, time)
        VALUES ((SELECT MAX(id) FROM p2p) + 1, 
                (SELECT MAX(id) FROM checks WHERE checks.peer = p_nickname AND checks.task = p_task_name AND checks.date = CURRENT_DATE),
                p_checker_nickname, p_check_status, p_time);
    ELSE
        INSERT INTO p2p (id, Check_ID, checkingpeer, P2P_check_status, time)
        VALUES ((SELECT MAX(id) FROM p2p) + 1,(
				SELECT P1.Check_ID
				FROM P2P P1
				WHERE P1.checkingpeer = p_checker_nickname
				AND P1.P2P_check_status = 'Start'
				AND NOT EXISTS (
    				SELECT *
    				FROM P2P P2
    				WHERE P2.Check_ID = P1.Check_ID
    				AND P2.P2P_check_status <> 'Start')
				),
                p_checker_nickname, p_check_status, p_time);
    END IF;
END;
$$;
/*
2) Write a procedure for adding checking by Verter
Parameters: nickname of the person being checked, task name, Verter check status, time.
Add a record to the Verter table (as a check specify the check of the corresponding task 
with the latest (by time) successful P2P step)
*/
CREATE OR REPLACE PROCEDURE add_verter_check(
    p_nickname VARCHAR,
    p_task_name VARCHAR,
    p_check_status checkstatus,
    p_time TIME
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_check_id BIGINT;
BEGIN
    SELECT c.ID INTO v_check_id
    FROM Checks c
    JOIN P2P p ON c.ID = p.Check_ID
    WHERE c.Task = p_task_name
    AND p.P2P_check_status = 'Success'
    ORDER BY
		c.Date DESC,
		p.Time DESC
    LIMIT 1;
    INSERT INTO Verter (ID, Check_ID, Check_status_by_Verter, Time)
    VALUES ((SELECT MAX(id) FROM verter) + 1, v_check_id, p_check_status, p_time);
END;
$$;
/*
3) Write a trigger: after adding a record with the "start" status to the P2P table, 
change the corresponding record in the TransferredPoints table
*/
CREATE OR REPLACE FUNCTION update_transferred_points()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.P2P_check_status = 'Start' THEN
        UPDATE transferredpoints
        SET pointsamount = pointsamount + 1
        WHERE checkingpeer = NEW.checkingpeer
        AND checkedpeer = (
            SELECT c.peer
            FROM P2P p
			JOIN checks c ON p.Check_ID = c.ID
            WHERE Check_ID = NEW.Check_ID
            AND P2P_check_status = 'Start'
        );
        IF NOT FOUND THEN
            INSERT INTO transferredpoints (ID, checkingpeer, checkedpeer, pointsamount)
            VALUES ((SELECT MAX(id) FROM transferredpoints) + 1, NEW.checkingpeer, (
                SELECT c.peer
                FROM P2P p
                JOIN checks c ON p.Check_ID = c.ID
                WHERE Check_ID = NEW.Check_ID
                AND P2P_check_status = 'Start'
            ), 1);
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_transferred_points_trigger
AFTER INSERT ON p2p
FOR EACH ROW
EXECUTE FUNCTION update_transferred_points();
/*
4) Write a trigger: before adding a record to the XP table, check if it is correct
The record is considered correct if:
The number of XP does not exceed the maximum available for the task being checked
The Check field refers to a successful check If the record does not pass the check, do not add it to the table.
*/
CREATE OR REPLACE FUNCTION check_xp_record()
RETURNS TRIGGER AS $$
BEGIN
    DECLARE
        max_xp INTEGER;
    BEGIN
        SELECT MaxXP INTO max_xp FROM Tasks t JOIN checks c ON t.title = c.task WHERE c.id = NEW.Check_ID;
        IF NEW.xpamount > max_xp THEN
            RAISE EXCEPTION 'Number of XP exceeds the maximum available for the task';
        END IF;        
        IF NOT EXISTS (SELECT 1 FROM Checks c JOIN p2p p ON p.check_id = c.id JOIN verter v ON v.check_id = c.id
					   WHERE c.id = NEW.Check_ID AND p.p2p_check_status = 'Success' AND v.Check_status_by_Verter = 'Success') THEN
            RAISE EXCEPTION 'Check field does not refer to a successful check';
        END IF;
        
        RETURN NEW;
    END;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER check_xp_record_trigger
BEFORE INSERT ON xp
FOR EACH ROW
EXECUTE FUNCTION check_xp_record();

/*
CALL add_p2p_check('peer5','peer3','C3_SimpleBashUtils', 'Start', '10:00:00');
CALL add_p2p_check('peer5','peer3','C3_SimpleBashUtils', 'Success', '10:30:00');
CALL add_verter_check('peer5','C3_SimpleBashUtils', 'Start', '11:00:00');
CALL add_verter_check('peer5','C3_SimpleBashUtils', 'Success', '11:30:00');
INSERT INTO xp VALUES (6,8,200)
*/