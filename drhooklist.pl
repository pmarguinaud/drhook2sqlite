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

my @opts_s = qw (kind limit match where format order);
my %opts = qw (kind Self limit 1000 format text order Name);

&GetOptions
(
  map ({ ("$_=s", \$opts{$_}) } @opts_s),
);

my @db = @ARGV;

my $dbh = 'DBI'->connect ("DBI:SQLite:", '', '', {RaiseError => 1})
  or die ($DBI::errstr);
$dbh->{RaiseError} = 1;


my @i = (0 .. $#db);
my @dn = map { "db$_" } @i;
my %dn;
@dn{@db} = @dn;
my @key = map { "$opts{kind}$_" } @i;

for my $db (@db) 
  {
    $dbh->do ("ATTACH \"$db\" AS $dn{$db};");
  }

my $MATCH = $opts{match} ? "AND (db1.DrHookTime_Merge$opts{kind}.Name REGEXP '$opts{match}')" : "";
my $WHERE = $opts{where} ? "AND ($opts{where})" : "";

my $query = "SELECT db0.DrHookTime_Merge$opts{kind}.Name AS Name, "
  . join (', ', map ({ "$dn[$_].DrHookTime_Merge$opts{kind}.avg AS $key[$_]" } @i))
  . " FROM " . join (', ', map ({ "$dn[$_].DrHookTime_Merge$opts{kind}" } @i))
  . " WHERE " 
  . '('. join (' OR ', map ({ my $i = $_; map ({ my $j = $_; "$dn[$i].DrHookTime_Merge$opts{kind}.Avg != "
                                                           . "$dn[$j].DrHookTime_Merge$opts{kind}.Avg" } (0 .. $i-1)) } @i)) . ')'
  . " AND "
  . '(' . join (' AND ', map ({ "$dn[$_].DrHookTime_Merge$opts{kind}.Name = "
                              . "$dn[$_+1].DrHookTime_Merge$opts{kind}.Name" } @i[0..$#i-1])) . ')'
  . " $MATCH $WHERE ORDER BY $opts{order} LIMIT $opts{limit};";


my $sth = $dbh->prepare ($query);

$sth->execute ();

my @FLD = ('Name', @key);
my (%FMT, %HDR);
@FMT{@FLD} = ('%-50s', ('%12.5f') x scalar (@key));
@HDR{@FLD} = ('%-50s', ('%12s') x scalar (@key));

if ($opts{format} eq 'text')
  {
    print "\n";
    for my $i (@i)
      {
        printf ("%-10s: %s\n", $key[$i], $db[$i]);
      }
    print "\n";
    
    for my $i (0 .. $#FLD)
      {
        my $FLD = $FLD[$i];
        my $str = sprintf ($HDR{$FLD}, $FLD);
        $str = " | $str";
        print $str;
        printf (" |\n") if ($i == $#FLD);
      }
    
    while (my $h = $sth->fetchrow_hashref ())
      {
        for my $i (0 .. $#FLD)
          {
            my $FLD = $FLD[$i];
            my $str = sprintf ($FMT{$FLD}, $h->{$FLD});
            $str = " | $str";
            print $str;
            printf (" |\n") if ($i == $#FLD);
          }
      }
  }
elsif ($opts{format} eq 'csv')
  {
    print ";\n";
    for my $i (@i)
      {
        printf ("%s;%s;\n", $key[$i], $db[$i]);
      }
    print ";\n";
    
    print ";;;";
    for my $i (0 .. $#FLD)
      {
        my $FLD = $FLD[$i];
        my $str = sprintf ($HDR{$FLD}, $FLD);
        $str =~ s/(?:^\s*|\s*$)//go;
        $str = "$str;";
        print $str;
        printf ("\n") if ($i == $#FLD);
      }
    
    while (my $h = $sth->fetchrow_hashref ())
      {
        print ";;;";
        for my $i (0 .. $#FLD)
          {
            my $FLD = $FLD[$i];
            my $str = sprintf ($FMT{$FLD}, $h->{$FLD});
            $str =~ s/(?:^\s*|\s*$)//go;
            $str = "$str;";
            print $str;
            printf ("\n") if ($i == $#FLD);
          }
      }
  }
elsif ($opts{format} eq 'gnuplot')
  {
    while (my $h = $sth->fetchrow_hashref ())
      {
        for my $i (0 .. $#FLD)
          {
            my $FLD = $FLD[$i];
            (my $fld = $h->{$FLD}) =~ s/_/\\\\_/go;
            my $str = sprintf ($FMT{$FLD}, $fld);
            print $str;
            printf ("\n") if ($i == $#FLD);
          }
      }
  }
