#!/usr/bin/perl

use Test;
BEGIN { plan tests => 10 }

use Carp;
$SIG{__DIE__} = \&Carp::confess;

########################################################################

use DBIx::DBO2;
BEGIN { ok( 1 ) }

eval "use DBIx::DBO2 0.001;";
ok( ! $@ );

eval "use DBIx::DBO2 2.0;";
ok( $@ );

########################################################################

unless ( $ENV{DBI_DSN} and exists $ENV{DBI_USER} and exists $ENV{DBI_PASS} ) {
  warn "A working DBI connection is required for the remaining tests.\n";
  warn "Please enter or accept the following parameters (or pre-set in your ENV):\n";
}

sub get_line {
  print "  $_[0] (or accept default '$_[1]'): ";
  my $input = <STDIN>;
  chomp $input;
  ( length $input ) ? $input : $_[1]
}

my $dsn = $ENV{DBI_DSN} || get_line( 'DBI_DSN' => 'dbi:AnyData:' );
my $user = exists $ENV{DBI_USER} ? $ENV{DBI_USER} : get_line( 'DBI_USER' =>'' );
my $pass = exists $ENV{DBI_PASS} ? $ENV{DBI_PASS} : get_line( 'DBI_PASS' =>'' );

########################################################################

eval 'use lib "./test-lib"; use MyCDs;';
ok( 1 );

########################################################################

CONNECT: { 
  
  MyCDs->tableset( DBIx::DBO2::TableSet->new(
    packages => { 
      'MyCDs::Disc' => 'disc',
      'MyCDs::Track' => 'track',
      'MyCDs::Artist' => 'artist',
      'MyCDs::Genre' => 'genre',
    }, 
    require_packages => 1,
  ) );

  MyCDs->connect_datasource( $dsn, $user, $pass );
  
  my $ds;
  ok( $ds = MyCDs->datasource );
  ok( ref($ds) =~ /DBIx::SQLEngine::/ );
}

########################################################################

INIT: {
  # Turn this on for verbose logging...
  # MyCDs->datasource->DBILogging(1);
  
  MyCDs->declare_tables;
  MyCDs->create_tables;
  
  MyCDs::Disc->new( 'name' => "Everything Everything" )->save_record;
}

########################################################################

my $rs = MyCDs::Disc->fetch_records( order => 'name' );
ok( $rs->count and scalar ( $rs->records ) );
foreach my $r ( $rs->records ) {
  # "CD " . $r->id . ": " . $r->name . " (" . ( $r->year || 'unknown' ) . ")"
}

my $disc = MyCDs::Disc->fetch_one( criteria => { 'name' => "Everything Everything" } );
ok( $disc->name eq "Everything Everything" );

ok( $disc->recorded_readable =~ /200\d/ );

########################################################################

CLEANUP: {
  MyCDs->drop_tables;

  ok( 1 );
}

########################################################################

1;
