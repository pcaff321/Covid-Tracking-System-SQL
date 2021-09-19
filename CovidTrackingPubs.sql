use cs2208_cs2208_4;

DROP TABLE IF EXISTS NeighbourCounty;
DROP TABLE IF EXISTS Visit;
DROP TABLE IF EXISTS Covid_Diagnosis;
DROP TABLE IF EXISTS Pub;
DROP TABLE IF EXISTS Person;


CREATE TABLE Pub (
PLN VARCHAR(20) UNIQUE, PubName VARCHAR(20), PCounty VARCHAR(20),
PRIMARY KEY (PLN)
);

CREATE TABLE NeighbourCounty (
County1 VARCHAR(20), County2 VARCHAR(20)
);

CREATE TABLE Person (
PPSN INT UNIQUE, Pname VARCHAR(20), PCounty VARCHAR(20), Age INT, DailyPubLimit INT,
PRIMARY KEY (PPSN));

CREATE TABLE Visit (
PLN VARCHAR(20), PPSN INT, StartDateOfVisit DATETIME, EndDateOfVisit DATETIME,
FOREIGN KEY(PLN) REFERENCES Pub(PLN),
FOREIGN KEY(PPSN) REFERENCES Person(PPSN)
);

CREATE TABLE Covid_Diagnosis (
PPSN INT, DiagnosisDate DATE, IsolationEndDate DATE,
FOREIGN KEY(PPSN) REFERENCES Person(PPSN)
);

DELIMITER // 
CREATE TRIGGER NoVisitQUESTION3
BEFORE INSERT ON Visit FOR EACH ROW
BEGIN
	DECLARE beforeEnd INT;
	SELECT COUNT(*) INTO beforeEnd FROM Covid_Diagnosis cd WHERE
	cd.PPSN = new.PPSN AND (new.StartDateOfVisit < (SELECT cd.IsolationEndDate FROM Covid_Diagnosis cd2 
	WHERE cd2.PPSN = new.PPSN));
	IF (beforeEnd > 0) THEN 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Cannot visit before end of isolation date';
	END IF;
END; //
DELIMITER ;

DELIMITER // 
CREATE TRIGGER NeighboursOnlyQUESTION4
BEFORE INSERT ON Visit FOR EACH ROW
BEGIN
	DECLARE IsNeighbour INT;
	DECLARE InCounty INT;

	SELECT COUNT(*) INTO IsNeighbour FROM 
	(SELECT nc.County2 AS NeighbourC, p.PCounty AS HomeC FROM Person p, NeighbourCounty nc
	WHERE p.PPSN = new.PPSN AND nc.County1 = p.PCounty) t, Pub
	WHERE 
	Pub.PLN = new.PLN AND
	NeighbourC = Pub.PCounty;

	SELECT COUNT(*) INTO InCounty FROM Person p,Pub
	WHERE p.PPSN = new.PPSN AND Pub.PCounty = p.PCounty AND Pub.PLN = new.PLN;

	IF (IsNeighbour = 0) AND (InCounty = 0) THEN 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Can only visit neighbouring counties or own county';
	END IF;
END; //
DELIMITER ;


DELIMITER // 
CREATE TRIGGER LimitPubsQUESTION5
BEFORE INSERT ON Visit FOR EACH ROW
BEGIN
	DECLARE pubCount INT;
	DECLARE personLimit INT;
	DECLARE sameTime INT;
	
	SELECT COUNT(*) INTO pubCount FROM Visit V, Person P WHERE V.PPSN = P.PPSN AND DATE_SUB(new.StartDateOfVisit, INTERVAL 1 DAY) < V.EndDateOfVisit; 
	SELECT DailyPubLimit INTO personLimit FROM Person WHERE PPSN = new.PPSN;
	IF (pubCount > personLimit) THEN 
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Cannot exceed pub limit';
	END IF;

	SELECT COUNT(*) INTO SameTime FROM Visit v WHERE v.PPSN = new.PPSN AND ((new.StartDateOfVisit < v.EndDateOfVisit) OR (new.EndDateOfVisit < v.EndDateOfVisit));
	IF (SameTime > 0) THEN
		SIGNAL SQLSTATE '45000'
		SET MESSAGE_TEXT = 'Cannot attend 2 pubs at the same time';
	END IF;
END; //
DELIMITER ;

INSERT INTO Pub VALUES ("L1234", "Murphy's", "Cork");
INSERT INTO Pub VALUES ("L2345", "Joe's", "Limerick");
INSERT INTO Pub VALUES ("L3456", "BatBar", "Kerry");

INSERT INTO NeighbourCounty VALUES ("Cork", "Limerick");
INSERT INTO NeighbourCounty VALUES ("Limerick", "Cork");
INSERT INTO NeighbourCounty VALUES ("Cork", "Kerry");
INSERT INTO NeighbourCounty VALUES ("Kerry", "Cork");

INSERT INTO Person VALUES (1, "Liza", "Cork", 22, 5);
INSERT INTO Person VALUES (2, "Alex", "Limerick", 19, 7);
INSERT INTO Person VALUES (3, "Tom", "Kerry", 23, 10);
INSERT INTO Person VALUES (4, "Peter", "Cork", 39, 8);

INSERT INTO Visit VALUES("L1234", 1, STR_TO_DATE('20/10/02 10:00', '%y/%e/%m %h:%i'), STR_TO_DATE('20/10/02 11:00', '%y/%e/%m %h:%i'));
INSERT INTO Visit VALUES("L1234", 1, STR_TO_DATE('20/08/12 11:00', '%y/%e/%m %h:%i'), STR_TO_DATE('20/08/12 11:35', '%y/%e/%m %h:%i'));
INSERT INTO Visit VALUES("L2345", 3, STR_TO_DATE('20/03/12 11:00', '%y/%e/%m %h:%i'), STR_TO_DATE('20/03/12 11:50', '%y/%e/%m %h:%i'));

INSERT INTO Covid_Diagnosis VALUES (2, STR_TO_DATE('20/11/02', '%y/%e/%m'), STR_TO_DATE('20/21/02', '%y/%e/%m'));

CREATE OR REPLACE VIEW COVID_NUMBERS AS SELECT P.PCounty AS County, COUNT(*) AS Cases
FROM Person P, Covid_Diagnosis CD WHERE P.PPSN = CD.PPSN 
GROUP BY P.PCounty;




