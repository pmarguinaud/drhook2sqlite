#!/usr/bin/perl -w

use DBI;
use DBD::SQLite;
use Data::Dumper;
use FileHandle;
use Term::ANSIColor;
use Getopt::Long;

use warnings qw (FATAL all);
use strict;

my $tty = -t STDOUT;

my @opts_s = qw (kind limit match where);
my %opts = qw (kind Self limit 1000);

&GetOptions
(
  map ({ ("$_=s", \$opts{$_}) } @opts_s),
);

my ($db1, $db2) = @ARGV;

my $dbh = 'DBI'->connect ("DBI:SQLite:", '', '', {RaiseError => 1})
  or die ($DBI::errstr);
$dbh->{RaiseError} = 1;

$dbh->do ("ATTACH \"$db1\" AS db1;");
$dbh->do ("ATTACH \"$db2\" AS db2;");

my $MATCH1 = $opts{match} ? "AND (db1.DrHookTime_Merge$opts{kind}.Name REGEXP '$opts{match}')" : "";
my $MATCH2 = $opts{match} ? "AND (db2.DrHookTime_Merge$opts{kind}.Name REGEXP '$opts{match}')" : "";
my $WHERE  = $opts{where} ? "AND ($opts{where})" : "";

my $query12 = "SELECT 
              '~'                                                                          AS Status,
              db1.DrHookTime_Merge$opts{kind}.Name                                         AS Name, 
              db1.DrHookTime_Merge$opts{kind}.Avg                                          AS Avg1, 
              db2.DrHookTime_Merge$opts{kind}.Avg                                          AS Avg2,
              db1.DrHookTime_Merge$opts{kind}.Min                                          AS Min1, 
              db2.DrHookTime_Merge$opts{kind}.Min                                          AS Min2,
              db1.DrHookTime_Merge$opts{kind}.Max                                          AS Max1, 
              db2.DrHookTime_Merge$opts{kind}.Max                                          AS Max2,
              db2.DrHookTime_Merge$opts{kind}.Avg - db1.DrHookTime_Merge$opts{kind}.Avg    AS AvgDiff,
              CASE WHEN db1.DrHookTime_Merge$opts{kind}.Avg > 0 THEN
              (db2.DrHookTime_Merge$opts{kind}.Avg - db1.DrHookTime_Merge$opts{kind}.Avg) * 100
            / db1.DrHookTime_Merge$opts{kind}.Avg ELSE 1000 END                            AS AvgIncr
            FROM 
              db1.DrHookTime_Merge$opts{kind}, db2.DrHookTime_Merge$opts{kind} 
            WHERE (db1.DrHookTime_Merge$opts{kind}.Name = db2.DrHookTime_Merge$opts{kind}.Name)
              AND (db2.DrHookTime_Merge$opts{kind}.Avg != db1.DrHookTime_Merge$opts{kind}.Avg )
              $MATCH1 $WHERE
            ORDER BY ABS (db1.DrHookTime_Merge$opts{kind}.Avg-db2.DrHookTime_Merge$opts{kind}.Avg) DESC LIMIT $opts{limit};";

my $query1  = "SELECT 
              '-'                                                                          AS Status,
              db1.DrHookTime_Merge$opts{kind}.Name                                         AS Name, 
              db1.DrHookTime_Merge$opts{kind}.Avg                                          AS Avg1, 
              0.                                                                           AS Avg2,
              db1.DrHookTime_Merge$opts{kind}.Min                                          AS Min1, 
              0.                                                                           AS Min2,
              db1.DrHookTime_Merge$opts{kind}.Max                                          AS Max1, 
              0.                                                                           AS Max2,
              0.                                  - db1.DrHookTime_Merge$opts{kind}.Avg    AS AvgDiff,
              0.                                                                           AS AvgIncr
            FROM 
              db1.DrHookTime_Merge$opts{kind}
            WHERE (db1.DrHookTime_Merge$opts{kind}.Name NOT IN (SELECT Name FROM db2.DrHookTime_Merge$opts{kind}))
              $MATCH1 $WHERE
            ORDER BY ABS (db1.DrHookTime_Merge$opts{kind}.Avg) DESC LIMIT $opts{limit};";

my $query2  = "SELECT 
              '+'                                                                          AS Status,
              db2.DrHookTime_Merge$opts{kind}.Name                                         AS Name, 
              0.                                                                           AS Avg1, 
              db2.DrHookTime_Merge$opts{kind}.Avg                                          AS Avg2,
              0.                                                                           AS Min1, 
              db2.DrHookTime_Merge$opts{kind}.Min                                          AS Min2,
              0.                                                                           AS Max1, 
              db2.DrHookTime_Merge$opts{kind}.Max                                          AS Max2,
              db2.DrHookTime_Merge$opts{kind}.Avg - 0.                                     AS AvgDiff,
              0.                                                                           AS AvgIncr
            FROM 
              db2.DrHookTime_Merge$opts{kind}
            WHERE (db2.DrHookTime_Merge$opts{kind}.Name NOT IN (SELECT Name FROM db1.DrHookTime_Merge$opts{kind}))
              $MATCH1 $WHERE
            ORDER BY ABS (db2.DrHookTime_Merge$opts{kind}.Avg) DESC LIMIT $opts{limit};";

my @FLD = qw (Status Name Avg1 Min1 Max1 Avg2 Min2 Max2 AvgDiff AvgIncr);
my (%FMT, %HDR);
@FMT{@FLD} = (qw (%-6s %-40s %12.5f %12.5f %12.5f %12.5f %12.5f %12.5f %+12.5f), '%+12.5f%%');
@HDR{@FLD} = qw (%6s %-40s %12s %12s %12s %12s %12s %12s %12s %13s);

my $cpm = sub { my ($v, $s) = @_; return &colored ($s, $v > 0. ? 'red' : 'green') };

my %COL = (AvgDiff => $cpm, AvgIncr => $cpm);

for my $i (0 .. $#FLD)
  {
    my $FLD = $FLD[$i];
    my $str = sprintf ("$HDR{$FLD}", $FLD);
    $str = " | $str";
    print $str;
    printf (" |\n") if ($i == $#FLD);
  }

for my $query ($query12, $query1, $query2)
  {
    my $sth = $dbh->prepare ($query);
    $sth->execute ();
    
    while (my $h = $sth->fetchrow_hashref ())
      {
        for my $i (0 .. $#FLD)
          {
            my $FLD = $FLD[$i];
            my $str = sprintf ("$FMT{$FLD}", $h->{$FLD});
            $str = $tty && $COL{$FLD} ? $COL{$FLD}->($h->{$FLD}, $str) : $str;
            $str = " | $str";
            print $str;
            printf (" |\n") if ($i == $#FLD);
          }
      }
  }
