SELECT LOAD_EXTENSION ('./libsqlitefunctions.so');

CREATE TABLE DrHookTime_MergeSelf (Name VARCHAR (255) NOT NULL, Avg FLOAT NOT NULL, Std FLOAT NOT NULL, Min FLOAT NOT NULL, Max FLOAT NOT NULL, PRIMARY KEY (Name)); 
INSERT INTO DrHookTime_MergeSelf (Name, Avg, Std, Min, Max)  SELECT Name, AVG (Self), -1, -1, -1 FROM DrHookTime GROUP BY Name;

CREATE TABLE DrHookTime_StdSelf (Name VARCHAR (255) NOT NULL, Std FLOAT NOT NULL, PRIMARY KEY (Name)); 

INSERT INTO DrHookTime_StdSelf (Name, Std) SELECT DrHookTime.Name, SQRT (AVG ((DrHookTime.Self - DrHookTime_MergeSelf.Avg)*(DrHookTime.Self - DrHookTime_MergeSelf.Avg))) 
  FROM DrHookTime, DrHookTime_MergeSelf WHERE DrHookTime.Name = DrHookTime_MergeSelf.Name GROUP BY DrHookTime_MergeSelf.Name;

UPDATE DrHookTime_MergeSelf SET Std = (SELECT Std FROM DrHookTime_StdSelf WHERE DrHookTime_MergeSelf.Name = DrHookTime_StdSelf.Name) ; 

CREATE TABLE DrHookTime_MinMaxSelf (Name VARCHAR (255) NOT NULL, Min FLOAT NOT NULL, Max FLOAT NOT NULL, PRIMARY KEY (Name));

INSERT INTO DrHookTime_MinMaxSelf (Name, Min, Max) 
  SELECT Name, MIN (MaxTime.Max), MAX (Maxtime.Max) 
  FROM (SELECT Name, MAX (Self) AS Max FROM DrHookTime GROUP BY Name, Task) 
  AS MaxTime GROUP BY Name;

UPDATE DrHookTime_MergeSelf SET 
  Min = (SELECT Min FROM DrHookTime_MinMaxSelf WHERE DrHookTime_MergeSelf.Name = DrHookTime_MinMaxSelf.Name), 
  Max = (SELECT Max FROM DrHookTime_MinMaxSelf WHERE DrHookTime_MergeSelf.Name = DrHookTime_MinMaxSelf.Name) ;


.mode column
.header on

SELECT * FROM DrHookTime_MergeSelf ORDER BY Max DESC LIMIT 10 ;



