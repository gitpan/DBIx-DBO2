#!/usr/bin/perl

use Test;
BEGIN { plan tests => 17 }

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
  
  MyCDs->init();
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
  
  MyCDs::Disc->new( 
    'name' => "Everything Everything", 
    'artist' => MyCDs::Artist->new( 'name' => 'Underworld' )->save_record,
  )->save_record();
}

########################################################################

my $rs = MyCDs::Disc->fetch_records( order => 'name' );
ok( $rs->count and scalar ( $rs->records ) );
foreach my $r ( $rs->records ) {
  # "CD " . $r->id . ": " . $r->name . " (" . ( $r->year || 'unknown' ) . ")"
}

my $disc = MyCDs::Disc->fetch_one( criteria => { 'name' => "Everything Everything" } );
ok( $disc->name eq "Everything Everything" );

# warn "Added to DB: " . $disc->added_to_db_readable() . "\n";
ok( $disc->added_to_db_readable =~ /200\d/ );

########################################################################

RESTRICT_DELETE: {

  my $artist = MyCDs::Artist->fetch_one(criteria => {'name'=>"Underworld"} );
  ok( $artist );

  ok( ! $artist->delete_record );
  ok( $artist = MyCDs::Artist->fetch_one(criteria => { 'name' => "Underworld" } ) );

  ok( $artist->count_discs );
  $artist->delete_discs;

  ok( ! $artist->count_discs );
  
  ok( $artist->delete_record );
  ok( ! MyCDs::Artist->fetch_one(criteria => { 'name' => "Underworld" } ) );
  
}

########################################################################

CLEANUP: {
  MyCDs->drop_tables;

  ok( 1 );
}

########################################################################

1;
