=head1 NAME

DBIx::DBO2::TableSet - Group of tables and associated record classes

=head1 SYNOPSIS

  use DBIx::DBO2::TableSet;
  my $ts = DBIx::DBO2::TableSet->new();
  $ts->connect_datasource( $dsn, $user, $pass );
  $ts->packages( 'MyClassName' => 'mytablename' );
  $ts->require_packages;
  $ts->declare_tables;

=head1

This is an example use of the DBIx::DBO2 framework used for testing purposes.

=cut

package DBIx::DBO2::TableSet;

use strict;
use Carp;
use Class::MakeMethods;

use DBIx::DBO2::Table;

########################################################################

use Class::MakeMethods::Standard::Hash (
  'new' => 'new',
  'object' => { name=>'datasource', class=>'DBIx::SQLEngine::Default'},
  'hash' => 'packages',
);

sub connect_datasource {
  my $self = shift;
  $self->datasource( DBIx::SQLEngine->new( @_ ) );
}

########################################################################

sub require_packages {
  my $self = shift;
  my %tables = $self->packages;
  while ( my( $package, $tablename ) = each %tables  ) {
    $package =~ s{::}{/}g;
    $package .= '.pm';
    # warn "Loading $package...\n";
    require $package;
  }
}

########################################################################

sub declare_tables {
  my $self = shift;
  my $datasource = $self->datasource;
  my %tables = $self->packages;
  while ( my( $package, $tablename ) = each %tables  ) {
    $package->table( 
      DBIx::DBO2::Table->new( name => $tablename, datasource => $datasource ) 
    );
  }
}

########################################################################

sub create_tables {
  my $self = shift;
  
  my %tables = $self->packages;
  while ( my( $package, $tablename ) = each %tables  ) {
    my $table = $package->table;
    my $cols = $package->field_columns;
    $table->columnset( DBIx::DBO2::ColumnSet->new( @$cols ) );
    $table->table_create;
  }
}

sub ensure_tables_exist {
  my $self = shift;
  
  my %tables = $self->packages;
  while ( my( $package, $tablename ) = each %tables  ) {
    my $table = $package->table;
    next if $table->table_exists;
    my $cols = $package->field_columns;
    $table->columnset( DBIx::DBO2::ColumnSet->new( @$cols ) );
    $table->table_create;
  }
}

sub refresh_tables_schema {
  my $self = shift;
  
  my %tables = $self->packages;
  while ( my( $package, $tablename ) = each %tables  ) {
    my $table = $package->table;
    next if $table->table_exists;
    my $cols = $package->field_columns;
    $table->columnset( DBIx::DBO2::ColumnSet->new( @$cols ) );
    $table->table_recreate_with_rows;
  }
}

sub drop_tables {
  my $self = shift;
  
  my %tables = $self->packages;
  while ( my( $package, $tablename ) = each %tables  ) {
    my $table = $package->table	or next;
    $table->table_drop;
  }
}

########################################################################

1;
