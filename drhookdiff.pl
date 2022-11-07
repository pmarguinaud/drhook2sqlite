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

my $MATCH = $opts{match} ? "AND (db1.DrHookTime_Merge$opts{kind}.Name REGEXP '$opts{match}')" : "";
my $WHERE = $opts{where} ? "AND ($opts{where})" : "";

my $query = "SELECT 
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
              $MATCH $WHERE
            ORDER BY ABS (db1.DrHookTime_Merge$opts{kind}.Avg-db2.DrHookTime_Merge$opts{kind}.Avg) DESC LIMIT $opts{limit};";

my $sth = $dbh->prepare ($query);

$sth->execute ();

my @FLD = qw (Name Avg1 Min1 Max1 Avg2 Min2 Max2 AvgDiff AvgIncr);
my (%FMT, %HDR);
@FMT{@FLD} = (qw (%-40s %12.5f %12.5f %12.5f %12.5f %12.5f %12.5f %+12.5f), '%+12.5f%%');
@HDR{@FLD} = qw (%-40s %12s %12s %12s %12s %12s %12s %12s %13s);

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
