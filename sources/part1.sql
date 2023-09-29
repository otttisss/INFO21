-- Установка путей для импорта и экспорта
set glb.import_path to '/Users/developer02/Documents/school21/SQL2_Info21_v1.0-1/src/csv/';
set glb.export_path to '/Users/developer02/Documents/school21/SQL2_Info21_v1.0-1/src/out/';
-- Проверка что пути установились корректно
-- SELECT glb('import_path'), glb('export_path');


-- Таблица Peers
CREATE TABLE IF NOT EXISTS Peers (
	Nickname varchar PRIMARY KEY NOT NULL,
	Birthday date
);


-- Таблица Tasks
-- Чтобы получить доступ к заданию, нужно выполнить задание, являющееся его условием входа.
-- Для упрощения будем считать, что у каждого задания всего одно условие входа.
-- В таблице должно быть одно задание, у которого нет условия входа (т.е. поле ParentTask равно null).
CREATE TABLE IF NOT EXISTS Tasks (
	Title varchar PRIMARY KEY NOT NULL,
	ParentTask varchar,
	MaxXP integer,
	CONSTRAINT fk_tasks_parent FOREIGN KEY (ParentTask) REFERENCES Tasks(Title)
);
CREATE INDEX IF NOT EXISTS index_parent_task ON Tasks ((1)) WHERE ParentTask IS NULL;


-- Статус проверки
DROP TYPE IF EXISTS CheckStatus;
CREATE TYPE CheckStatus AS ENUM ('Start', 'Success', 'Failure');


-- Таблица Checks
-- Описывает проверку задания в целом. Проверка обязательно включает в себя один этап P2P и, возможно, этап Verter.
-- Для упрощения будем считать, что пир ту пир и автотесты, относящиеся к одной проверке, всегда происходят в один день.
-- Проверка считается успешной, если соответствующий P2P этап успешен, а этап Verter успешен, либо отсутствует.
-- Проверка считается неуспешной, хоть один из этапов неуспешен.
-- То есть проверки, в которых ещё не завершился этап P2P, или этап P2P успешен, но ещё не завершился этап Verter, 
-- не относятся ни к успешным, ни к неуспешным.
CREATE TABLE IF NOT EXISTS Checks (
	ID bigint PRIMARY KEY NOT NULL,
	Peer varchar,
	Task varchar,
	Date date,
	CONSTRAINT fk_checks_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_checks_task FOREIGN KEY (Task) REFERENCES Tasks(Title)
);
CREATE SEQUENCE IF NOT EXISTS seq_checks AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE Checks ALTER COLUMN ID SET DEFAULT nextval('seq_checks');


-- Таблица P2P
-- Каждая P2P проверка состоит из 2-х записей в таблице: первая имеет статус начало, вторая - успех или неуспех. 
-- В таблице не может быть больше одной незавершенной P2P проверки, относящейся к конкретному заданию, пиру и проверяющему. 
-- Каждая P2P проверка (т.е. обе записи, из которых она состоит) ссылается на проверку в таблице Checks, к которой она относится.
CREATE TABLE IF NOT EXISTS P2P (
	ID bigint PRIMARY KEY NOT NULL,
	Check_ID bigint,
	CheckingPeer varchar,
	P2P_check_status CheckStatus,
	Time time,
 	CONSTRAINT fk_p2p_check FOREIGN KEY (Check_ID) REFERENCES Checks(ID),
	CONSTRAINT fk_p2p_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname)
);
ALTER TABLE P2P ADD CONSTRAINT ch_p2p_status CHECK (P2P_check_status IN ('Start', 'Success', 'Failure'));
CREATE SEQUENCE IF NOT EXISTS seq_p2p AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE P2P ALTER COLUMN ID SET DEFAULT nextval('seq_p2p');


-- Таблица Verter
-- Каждая проверка Verter'ом состоит из 2-х записей в таблице: первая имеет статус начало, вторая - успех или неуспех. 
-- Каждая проверка Verter'ом (т.е. обе записи, из которых она состоит) ссылается на проверку в таблице Checks, к которой она относится. 
-- Проверка Verter'ом может ссылаться только на те проверки в таблице Checks, которые уже включают в себя успешную P2P проверку.
CREATE TABLE IF NOT EXISTS Verter (
	ID bigint PRIMARY KEY NOT NULL,
	Check_ID bigint,
	Check_status_by_Verter CheckStatus,
	Time time,
	CONSTRAINT fk_verter_check FOREIGN KEY (Check_ID) REFERENCES Checks(ID)
);
ALTER TABLE Verter ADD CONSTRAINT ch_verter_status CHECK (Check_status_by_Verter IN ('Start', 'Success', 'Failure'));
CREATE SEQUENCE IF NOT EXISTS seq_verter AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE Verter ALTER COLUMN ID SET DEFAULT nextval('seq_verter');


-- Таблица TransferredPoints
-- При каждой P2P проверке проверяемый пир передаёт один пир поинт проверяющему.
-- Эта таблица содержит все пары проверяемый-проверяющий и кол-во переданных пир поинтов, то есть,
-- другими словами, количество P2P проверок указанного проверяемого пира, данным проверяющим.
CREATE TABLE IF NOT EXISTS TransferredPoints (
	ID bigint PRIMARY KEY NOT NULL,
	CheckingPeer varchar,
	CheckedPeer varchar,
	PointsAmount integer,
	CONSTRAINT fk_transferred_points_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_transferred_points_checked_peer FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname)
);
ALTER TABLE TransferredPoints ADD CONSTRAINT ch_not_same_peer CHECK (CheckingPeer NOT LIKE CheckedPeer);
CREATE SEQUENCE IF NOT EXISTS seq_transferredpoints AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE TransferredPoints ALTER COLUMN ID SET DEFAULT nextval('seq_transferredpoints');
CREATE UNIQUE INDEX IF NOT EXISTS idx_transferred_points_unique ON TransferredPoints(CheckingPeer, CheckedPeer);


-- Таблица Friends
-- Дружба взаимная, т.е. первый пир является другом второго, а второй -- другом первого.
CREATE TABLE IF NOT EXISTS Friends (
	ID bigint PRIMARY KEY NOT NULL,
	Peer1 varchar,
	Peer2 varchar,
	CONSTRAINT fk_friends_peer1 FOREIGN KEY (Peer1) REFERENCES Peers(Nickname),
	CONSTRAINT fk_friends_peer2 FOREIGN KEY (Peer2) REFERENCES Peers(Nickname)
);
ALTER TABLE Friends ADD CONSTRAINT ch_friends_not_same_peer CHECK (Peer1 NOT LIKE Peer2);
CREATE SEQUENCE IF NOT EXISTS seq_friends AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE Friends ALTER COLUMN ID SET DEFAULT nextval('seq_friends');


-- Таблица Recommendations
-- Каждому может понравиться, как проходила P2P проверка у того или иного пира.
-- Пир, указанный в поле Peer, рекомендует проходить P2P проверку у пира из поля RecommendedPeer.
-- Каждый пир может рекомендовать как ни одного, так и сразу несколько проверяющих.
CREATE TABLE IF NOT EXISTS Recommendations (
	ID bigint PRIMARY KEY NOT NULL,
	Peer varchar,
	RecommendedPeer varchar,
	CONSTRAINT fk_recommendations_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_recommendations_recommended_peer FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname)
);
ALTER TABLE Recommendations ADD CONSTRAINT ch_recommended_not_same_peer CHECK (Peer NOT LIKE RecommendedPeer);
CREATE SEQUENCE IF NOT EXISTS seq_recommendations AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE Recommendations ALTER COLUMN ID SET DEFAULT nextval('seq_recommendations');


-- Таблица XP
-- За каждую успешную проверку пир, выполнивший задание, получает какое-то количество XP, отображаемое в этой таблице.
-- Количество XP не может превышать максимальное доступное для проверяемой задачи.
-- Первое поле этой таблицы может ссылаться только на успешные проверки.
CREATE TABLE IF NOT EXISTS XP (
	ID bigint PRIMARY KEY NOT NULL,
	Check_ID bigint,
	XPAmount integer,
	CONSTRAINT fk_xp_check FOREIGN KEY (Check_ID) REFERENCES Checks(ID)
);
CREATE SEQUENCE IF NOT EXISTS seq_xp AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE XP ALTER COLUMN ID SET DEFAULT nextval('seq_xp');


-- Таблица TimeTracking
-- Данная таблица содержит информация о посещениях пирами кампуса.
-- Когда пир входит в кампус, в таблицу добавляется запись с состоянием 1, когда покидает - с состоянием 2.
-- В заданиях, относящихся к этой таблице, под действием "выходить" подразумеваются все покидания кампуса за день, кроме последнего.
-- В течение одного дня должно быть одинаковое количество записей с состоянием 1 и состоянием 2 для каждого пира.
CREATE TABLE IF NOT EXISTS TimeTracking (
	ID bigint PRIMARY KEY NOT NULL,
	Peer varchar,
	Date date,
	Time time,	
	State INT,
	CONSTRAINT fk_time_tracking_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname)
);
ALTER TABLE TimeTracking ADD CONSTRAINT ch_timetracking_status CHECK (State IN (1, 2));
CREATE SEQUENCE IF NOT EXISTS seq_timetracking AS bigint START WITH 1 INCREMENT BY 1;
ALTER TABLE TimeTracking ALTER COLUMN ID SET DEFAULT nextval('seq_timetracking');


-- Импорт данных для каждой таблицы из файлов с расширением .csv
CREATE OR REPLACE PROCEDURE import_data(separator varchar) AS $$
DECLARE
    path_name varchar := glb('import_path');
    files varchar[] := ARRAY['peers', 'friends', 'transferredpoints', 'recommendations', 'timetracking', 'tasks', 'checks', 'p2p', 'verter', 'xp'];
	file_name varchar;
BEGIN
    FOREACH file_name IN ARRAY files
    LOOP
        EXECUTE format('COPY %I FROM %L DELIMITER %L CSV HEADER;', file_name, path_name || file_name || '.csv', $1);
	END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Экспорт данных для каждой таблицы в файлы с расширением .csv
CREATE OR REPLACE PROCEDURE export_data(separator varchar) AS $$
DECLARE
    path_name varchar := glb('export_path');
    file_name varchar;
BEGIN
    FOR file_name IN SELECT table_name FROM information_schema.tables WHERE table_schema LIKE 'public'
    LOOP
        EXECUTE format(
            'COPY (SELECT * FROM %I) TO %L DELIMITER %L CSV HEADER;', file_name, path_name || file_name || '.csv', $1);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Установка глобальных переменных
create or replace function glb(code text)
returns varchar language sql as $$
    select current_setting('glb.' || code)::varchar;
$$;


-- Вызывать перед импортом для очистки таблиц
TRUNCATE Peers, Friends, TransferredPoints, Recommendations, TimeTracking, Tasks, Checks, P2P, Verter, XP;

-- Импорт
CALL import_data(',');

-- Экспорт
CALL export_data(',');