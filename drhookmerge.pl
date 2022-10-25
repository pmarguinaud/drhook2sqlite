#!/usr/bin/perl -w

use DBI;
use DBD::SQLite;
use Data::Dumper;
use FileHandle;
use FindBin qw ($Bin);

use warnings qw (FATAL all);
use strict;

my $db = shift;

die unless ($db);

my $dbh = 'DBI'->connect ("DBI:SQLite:$db", '', '',  {RaiseError => 1})
  or die ($DBI::errstr);
$dbh->{RaiseError} = 1;


$dbh->sqlite_enable_load_extension (1);
$dbh->prepare ("SELECT LOAD_EXTENSION ('$Bin/libsqlitefunctions.so')")->execute ();

$dbh->prepare ("BEGIN TRANSACTION")->execute ();

for my $Kind (qw (Self Total TotalPerCall SelfPerCall))
  {
    for my $stmt 
    (
      "CREATE TABLE DrHookTime_Merge$Kind (Name VARCHAR (255) NOT NULL, Avg FLOAT NOT NULL, Std FLOAT NOT NULL, 
        Min FLOAT NOT NULL, Max FLOAT NOT NULL, PRIMARY KEY (Name));",
      
      "INSERT INTO DrHookTime_Merge$Kind (Name, Avg, Std, Min, Max)  
        SELECT Name, AVG ($Kind), -1, -1, -1 FROM DrHookTime GROUP BY Name;",
      
      "CREATE TABLE DrHookTime_Std$Kind (Name VARCHAR (255) NOT NULL, Std FLOAT NOT NULL, PRIMARY KEY (Name));",
      
      "INSERT INTO DrHookTime_Std$Kind (Name, Std) SELECT DrHookTime.Name, 
        SQRT (AVG ((DrHookTime.$Kind - DrHookTime_Merge$Kind.Avg)*(DrHookTime.$Kind - DrHookTime_Merge$Kind.Avg))) 
        FROM DrHookTime, DrHookTime_Merge$Kind WHERE DrHookTime.Name = DrHookTime_Merge$Kind.Name GROUP BY DrHookTime_Merge$Kind.Name;",
      
      "UPDATE DrHookTime_Merge$Kind SET Std = (SELECT Std FROM DrHookTime_Std$Kind 
        WHERE DrHookTime_Merge$Kind.Name = DrHookTime_Std$Kind.Name);",
      
      "CREATE TABLE DrHookTime_MinMax$Kind (Name VARCHAR (255) NOT NULL, Min FLOAT NOT NULL, 
        Max FLOAT NOT NULL, PRIMARY KEY (Name));",
      
      "INSERT INTO DrHookTime_MinMax$Kind (Name, Min, Max) 
        SELECT Name, MIN (MaxTime.Max), MAX (Maxtime.Max) 
        FROM (SELECT Name, MAX ($Kind) AS Max FROM DrHookTime GROUP BY Name, Task) 
        AS MaxTime GROUP BY Name;",
      
      "UPDATE DrHookTime_Merge$Kind SET 
        Min = (SELECT Min FROM DrHookTime_MinMax$Kind WHERE DrHookTime_Merge$Kind.Name = DrHookTime_MinMax$Kind.Name), 
        Max = (SELECT Max FROM DrHookTime_MinMax$Kind WHERE DrHookTime_Merge$Kind.Name = DrHookTime_MinMax$Kind.Name) ;",
    
      "DROP TABLE DrHookTime_Std$Kind;",

      "DROP TABLE DrHookTime_MinMax$Kind;",
    )
      {
        $dbh->prepare ($stmt)->execute ();
      }
  }

$dbh->prepare ("COMMIT")->execute ();



