#!/usr/bin/perl -w

use DBI;
use DBD::SQLite;
use Data::Dumper;
use FileHandle;
use Term::ANSIColor;
use File::Basename;
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
my $n = scalar (@i);

my @dn = map { "db$_" } @i;
my %dn;
@dn{@db} = @dn;
my @key = map { "$opts{kind}$_" } @i;

for my $db (@db) 
  {
    $dbh->do ("ATTACH \"$db\" AS $dn{$db};");
  }


my $WHERE1 = @i < 2 ? "" :
    '('. join (' OR ', map ({ my $i = $_; map ({ my $j = $_; "$dn[$i].DrHookTime_Merge$opts{kind}.Avg != "
                                                           . "$dn[$j].DrHookTime_Merge$opts{kind}.Avg" } (0 .. $i-1)) } @i)) . ')'
  . ' AND '
  . '(' . join (' AND ', map ({ "$dn[$_].DrHookTime_Merge$opts{kind}.Name = "
                              . "$dn[$_+1].DrHookTime_Merge$opts{kind}.Name" } @i[0..$#i-1])) . ')';

my $WHERE2 = $opts{where} ? "($opts{where})" : "";
my $MATCH = $opts{match} ? "(db0.DrHookTime_Merge$opts{kind}.Name REGEXP '$opts{match}')" : "";

my $WHERE = join (' AND ', grep { $_ } ($WHERE1, $WHERE2, $MATCH));
$WHERE = "WHERE $WHERE" if ($WHERE);

my $query = "SELECT db0.DrHookTime_Merge$opts{kind}.Name AS Name, "
  . join (', ', map ({ "$dn[$_].DrHookTime_Merge$opts{kind}.avg AS $key[$_]" } @i))
  . " FROM " . join (', ', map ({ "$dn[$_].DrHookTime_Merge$opts{kind}" } @i))
  . " $WHERE ORDER BY $opts{order} LIMIT $opts{limit};";


print $query, "\n";

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
    print << "EOG";
set terminal postscript eps enhanced color solid font "Courrier 14 Bold" linewidth 2
set output "drhook.eps"

set grid

set ylabel "Time (s)"

set style data histogram
set style histogram cluster
set style fill solid border -1
set xtic rotate by -90 scale 0

array titles[$n]

EOG

    for my $i (@i)
      {
        (my $t = &basename ($db[$i])) =~ s/_/\\\\_/go;
        my $i1 = $i + 1;
        print "titles[$i1] = \"$t\"\n";
      }

    print << "EOG";
\$data << EOF
EOG

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

    print << "EOG";
EOF

plot \\
EOG

    my @col = qw (blue white red green pink orange purple);

    for my $i (@i)
      {
        my $i1 = $i + 1;
        my $i2 = $i + 2;
        my $col = $col[$i % scalar (@col)];
        if ($i == $i[0])
          {
            print "\"\$data\" using $i2:xtic(1) ti titles[$i1] lc \"$col\"";
          }
        else
          {
            print "\"\$data\" using $i2 ti titles[$i1] lc \"$col\"";
          }
        print ",\\" if ($i != $i[-1]);
        print "\n";
      }


  }
