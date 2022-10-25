#!/usr/bin/perl -w

use DBI;
use DBD::SQLite;
use Data::Dumper;
use FileHandle;
use Term::ANSIColor;

use warnings qw (FATAL all);
use strict;

my $tty = -t STDOUT;

my ($db1, $db2, $Kind, $Limit) = @ARGV;

$Kind ||= 'Self';
$Limit ||= 1000;

my $dbh = 'DBI'->connect ("DBI:SQLite:", '', '', {RaiseError => 1})
  or die ($DBI::errstr);
$dbh->{RaiseError} = 1;

$dbh->do ("ATTACH \"$db1\" AS db1;");
$dbh->do ("ATTACH \"$db2\" AS db2;");

my $query = "SELECT 
              db1.DrHookTime_Merge$Kind.Name                                         AS Name, 
              db1.DrHookTime_Merge$Kind.Avg                                          AS Avg1, 
              db2.DrHookTime_Merge$Kind.Avg                                          AS Avg2,
              db2.DrHookTime_Merge$Kind.Avg - db1.DrHookTime_Merge$Kind.Avg          AS AvgDiff,
              CASE WHEN db1.DrHookTime_Merge$Kind.Avg > 0 THEN
              (db2.DrHookTime_Merge$Kind.Avg - db1.DrHookTime_Merge$Kind.Avg) * 100
            / db1.DrHookTime_Merge$Kind.Avg ELSE 1000 END                            AS AvgIncr
            FROM 
              db1.DrHookTime_Merge$Kind, db2.DrHookTime_Merge$Kind 
            WHERE db1.DrHookTime_Merge$Kind.Name = db2.DrHookTime_Merge$Kind.Name 
              AND db2.DrHookTime_Merge$Kind.Avg != db1.DrHookTime_Merge$Kind.Avg 
            ORDER BY ABS (db1.DrHookTime_Merge$Kind.Avg-db2.DrHookTime_Merge$Kind.Avg) DESC LIMIT $Limit;";

my $sth = $dbh->prepare ($query);

$sth->execute ();

my @FLD = qw (Name Avg1 Avg2 AvgDiff AvgIncr);
my %FMT;
@FMT{@FLD} = (qw (%-40s %12.5f %12.5f %+12.5f), '%+12.5f%%');

my $cpm = sub { my ($v, $s) = @_; return &colored ($s, $v > 0. ? 'red' : 'green') };

my %COL = (AvgDiff => $cpm, AvgIncr => $cpm);


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
