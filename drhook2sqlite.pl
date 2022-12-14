#!/usr/bin/perl -w

use DBI;
use DBD::SQLite;
use Data::Dumper;
use FileHandle;
use Getopt::Long;
use warnings qw (FATAL all);
use strict;

my %opts;

=pod

Profiling information for program='/home/gmap/mrpm/marguina/pack/48t3_acvppfk/bin/MASTERODB', proc#31:
	No. of instrumented routines called : 961
	Instrumentation started : 20220928 091949
	Instrumentation   ended : 20220928 092431
	Instrumentation overhead: 0.14%
	Memory usage : 4349 MB (heap), 2610 MB (rss), 260 MB (stack), 19876 MB (vmpeak), 0 (paging)
	Wall-time is 282.98 sec on proc#31 (672 procs, 4 threads)
	Thread#1:      281.47 sec (99.46%)
	Thread#2:      180.71 sec (63.86%)
	Thread#3:      180.66 sec (63.84%)
	Thread#4:      180.61 sec (63.82%)

    #  % Time         Cumul         Self        Total     # of calls        Self       Total    Routine@<thread-id>
                                                                             (Size; Size/sec; Size/call; MinSize; MaxSize)
        (self)        (sec)        (sec)        (sec)                    ms/call     ms/call

    1     6.41       18.130       18.130       95.267           5324        3.41       17.89   *APLPAR@3

=cut


sub drHook2SQLite
{
  my ($f, $dbh) = @_;

  my @line = do { my $fh = 'FileHandle'->new ("<$f"); <$fh> };
  shift (@line) for (1 .. 6);
  my ($Wall_main, $Task, $Procs, $Threads) = (shift (@line) =~ m/Wall-time is\s+(\S+) sec on proc#(\d+) \((\d+) procs, (\d+) threads\)/o);
  
  my @Wall_threads;
  for (1 .. $Threads)
    {
      push @Wall_threads, (shift (@line) =~ m/Thread#\d+:\s+(\S+) sec/o);
    }

  while (@line)
   {
     last if ($line[0] =~ m/\(self\)\s+\(sec\)\s+\(sec\)\s+\(sec\)\s+ms\/call\s+ms\/call/o);
     shift (@line);
   }
  shift (@line) for (1 .. 2);


  my $set = $dbh->prepare ("INSERT INTO DrHookTime (Rank, Time, Cumul, Self, Total, "
                         . "Calls, SelfPerCall, TotalPerCall, Name, Thread, Task) "
                         . "VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)");

  for my $line (@line)
    {
      chomp ($line);

      $line =~ s/^\s*(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+//go;
      my ($Rank, $Time, $Cumul, $Self, $Total, $Calls, $SelfPerCall, $TotalPerCall) = ($1, $2, $3, $4, $5, $6, $7, $8);


      $line =~ s/^\*//o;
      my ($Name, $Thread);

      unless (($Name, $Thread) = ($line =~ m/^(.*)\@(\d+)$/o))
        {
          ($Name, $Thread) = ($line, 1);
        }

      if ($opts{only})
        {
          next unless (grep { $Name eq $_ } @{ $opts{only} });
        }

      $set->execute ($Rank, $Time, $Cumul, $Self, $Total, $Calls, $SelfPerCall, $TotalPerCall, $Name, $Thread, $Task);
    }

}

my @opts_s = qw (only);

&GetOptions
(
  map ({ ("$_=s", \$opts{$_}) } @opts_s),
);

if ($opts{only})
  {
    $opts{only} = [split (m/,/o, $opts{only})];
  }


my $db = shift;

die unless ($db);

my @drhook;

if ((scalar (@ARGV) == 1) && (-d $ARGV[0]))
  {
    @drhook = <$ARGV[0]/drhook.prof.*>;
  }
else
  {
    @drhook = @ARGV;
  }
  
unlink ($db);

my $dbh = 'DBI'->connect ("DBI:SQLite:$db", '', '', {RaiseError => 1})
  or die ($DBI::errstr);
$dbh->{RaiseError} = 1;

$dbh->prepare (<< "EOF")->execute (); 
CREATE TABLE DrHookTime 
   (Rank            INT           NOT NULL, 
    Time            FLOAT         NOT NULL,
    Cumul           FLOAT         NOT NULL,
    Self            FLOAT         NOT NULL,
    Total           FLOAT         NOT NULL,
    Calls           INT           NOT NULL,
    SelfPerCall     FLOAT         NOT NULL,
    TotalPerCall    FLOAT         NOT NULL,
    Name            VARCHAR (255) NOT NULL,
    Thread          INT           NOT NULL,
    Task            INT           NOT NULL,
    PRIMARY KEY (Name, Thread, Task))
EOF

$dbh->prepare ("BEGIN TRANSACTION")->execute ();

for my $f (@drhook)
  {
    &drHook2SQLite ($f, $dbh);
  }

$dbh->prepare ("COMMIT")->execute ();

$dbh->prepare ("CREATE INDEX DrHookTimeIdx ON DrHookTime (Name, Thread, Task);")->execute ();


# Per calls figures have too few digits

$dbh->do ("UPDATE DrHookTime SET SelfPerCall = 1000 * Self/Calls, TotalPerCall = 1000 * Total/Calls;");


