=head1 NAME

DBIx::DBO2::Table - A table in a datasource

=head1 SYNOPSIS

  my $sqldb = DBIx::SQLEngine->new( ... );
  
  my $table = DBIx::DBO2::Table->new( name => 'foo', datasource => $ds );
  
  my $row = $table->fetch_id(1);
  my $row_ary = $table->fetch_select( criteria => { status => 2 } );

=head1 DESCRIPTION

The DBIx::DBO2::Table class represents database tables accessible via DBIx::SQLEngine.

A B<table> acts as an interface to a particular set of data, uniquely identfied by the B<datasource> that it connects to and the b<name> of the table.

It facilitates generation of SQL queries that operate on the named table.

Each table can retrieve and cache a ColumnSet containing information about the name and type of the columns in the table. Column information is loaded from the storage as needed, but if you are creating a new table you must provide the definition.

=cut

package DBIx::DBO2::Table;
use strict;

########################################################################

=head1 REFERENCE

=cut

use Carp;
use Class::MakeMethods;
use DBIx::SQLEngine;
use DBIx::SQLEngine::Criteria;
use DBIx::DBO2::RecordSet;

########################################################################

=head2 Constructor

Create one Table for each underlying database table you will use.

=over 4

=item new

You are expected to provde the name and datasource or datasource_name arguments. (Standard::Hash:new)

=back

=cut

use Class::MakeMethods::Standard::Hash ( 'new' => 'new' );

########################################################################

=head2 Name

Required. Identifies this table in the DataSource. 

=over 4

=item name

  $table->name($string)
  $table->name() : $string

Set and get the table name. (Template::Hash:string)

=back

=cut

use Class::MakeMethods (
  'Template::Hash:string' => 'name',
);

########################################################################

=head2 DataSource

Required. The DataSource provides the DBI connection and SQL execution capabilities required to talk to the remote data storage.

=over 4

=item datasource

Refers to our current DBIx::SQLEngine. (Standard::Hash:object)

=item datasource_name

  $table->datasource_name () : $name

Get the name of the current datasource.

=item datasource_name

  $table->datasource_name ($name) : ()

Attempt to find a datasource with the given name, and store it as our datasource reference.

=back

=cut

use Class::MakeMethods (
  'Standard::Hash:object' => { name=>'datasource', class=>'DBIx::SQLEngine::Default' },
  'Standard::Universal:delegate'=>[ 
    [ qw( do_update do_insert do_delete fetch_sql do_sql ) ] 
	=> { target=>'datasource'} 
  ],
);

sub datasource_name {
  my $self = shift;
  if ( scalar @_ ) {
    my $name = shift;
    my $datasource = DBIx::SQLEngine->find_name( $name )
      or croak "Can't find DataSource named '$name'";
    $self->datasource( $datasource );
  } else { 
    my $datasource = $self->datasource
      or return;
    $datasource->name()
  }
}

########################################################################

=head2 Inserting Rows

=over 4

=item insert_row

  $table->insert_row ( $row_hash ) : ()

Adds the provided row by executing a SQL insert statement.

=item insert_rows

  $table->insert_rows ( $row_hash_ary ) : ()

Insert each of the rows from the provided array into the table.

=back

=cut

# $self->insert_row( $row );
sub insert_row {
  my ($self, $row) = @_;
  
  my $primary = $self->column_primary_name;
  my @colnames = grep { $_ eq $primary or defined $row->{$_} } $self->column_names;
  
  $self->do_insert( 
    table => $self->{name},
    sequence => $primary,	# KLUDGE
    columns => \@colnames,
    values => $row,
  );
}

# $self->insert_rows( $rows_arrayref );
sub insert_rows {
  my ($self, $rows) = @_;
  foreach ( @$rows ) { $self->insert_row( $_ ); }
}

########################################################################

=head2 Selecting Rows

=over 4

=item fetch_all

  $table->fetch_all () : $row_hash_array

Retrieve all of the rows from the datasource.

=item fetch

  $table->fetch ( CRITERIA, SORTING ) : $row_hash_array

Return rows from the table that match the provided criteria, and in the requested order, by executing a SQL select statement.

=item fetch_id

  $table->fetch_id ( $PRIMARY_KEY ) : $row

Fetch the row with the specified ID. 

=back

=cut

# $rows = $self->fetch_select;
sub fetch_select {
  my $self = shift;
  
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->fetch_select( 
    table => $self->name,
    @_
  )
}

# $rows = $self->fetch_all;
sub fetch_all {
  my $self = shift;
  
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->fetch_select( 
    table => $self->name,
  )
}

# $row = $self->fetch_id($id);
  # Retrieve a specific row by id
sub fetch_id {
  my ($self, $id) = @_;
  my $datasource = $self->datasource() or croak("No datasource set for $self");
  $datasource->fetch_one_row( 
    tables => $self->name, 
    columns => '*', 
    criteria => DBIx::SQLEngine::Criteria->type_new(
      'StringEquality', $self->column_primary_name, $id 
    )
  );
}

########################################################################

=head2 Updating Rows

=over 4

=item update_row

  $table->update_row ( $row_hash ) : ()

Update this existing row based on its primary key.

=item update_where

  $table->update_where ( CRITERIA, $changes_hash ) : ()

Make changes as indicated in changes hash to all rows that meet criteria

=back

=cut

# $self->update_row( $row );
sub update_row {
  my($self, $row) = @_;
  
  my $primary_col = $self->column_primary_name;
  my @colnames = grep { $_ ne $primary_col } $self->column_names;
  
  $self->do_update( 
    table => $self->{name},
    columns => \@colnames,
    values => $row,
    criteria => { $primary_col => $row->{$primary_col} },
  );
}

# $self->update_where( $criteria, $change_hash );
sub update_where {
  my($self, $criteria, $changes) = @_;
  
  $self->do_update( 
    table => $self->{name},
    columns => $changes,
    values => $changes,
    criteria => $criteria,
  );
}

########################################################################

=head2 Deleting Rows

=over 4

=item delete_all

  $table->delete_all () : ()

Delete all of the rows from table.

=item delete_where

  $table->delete_where ( $criteria ) : ()

=item delete_row

  $table->delete_row ( $row_hash ) : ()

Deletes the provided row from the table.

=item delete_id

  $table->delete_id ( $PRIMARY_KEY ) : ()

Deletes the row with the provided ID.

=back

=cut

# $self->delete_all;
sub delete_all { 
  my $self = shift;
  
  $self->do_delete( 
    table => $self->name,
  );
}

# $self->delete_where( $criteria );
sub delete_where { 
  my $self = shift;
  
  $self->do_delete( 
    table => $self->name,
    criteria => shift 
  );
}

# $self->delete_row( $row );
sub delete_row { 
  my($self, $row) = @_;
  
  $self->do_delete( 
    table => $self->name,
    criteria => { $self->column_primary_name => $row->{ $self->column_primary_name } } 
  );
}

# $self->delete_id( $id );
sub delete_id {
  my($self, $id) = @_;
  
  $self->do_delete( 
    table => $self->name,
    criteria => { $self->column_primary_name => $id } 
  );
}

########################################################################

=head2 Agregate functions

=over 4

=item count_rows

  $table->count_rows ( CRITERIA ) : $number

Return the number of rows in the table. If called with criteria, returns the number of matching rows. 

=item fetch_max

  $table->count_rows ( $colname, CRITERIA ) : $number

Returns the largest value in the named column. 

=back

=cut

# $rowcount = $self->count_rows
# $rowcount = $self->count_rows( $criteria );
sub count_rows {
  my $self = shift;
  my $criteria = shift;
  
  $self->datasource->fetch_one_value( 
    columns => 'count(*)', 
    tables => $self->name, 
    criteria => $criteria,
  );
}

sub try_count_rows {
  my $table = shift;
  my $count; 
  eval { 
    $count = $table->count_rows 
  };
  return ( wantarray ? ( $count, $@ ) : $count );
}

# $max_value = $self->fetch_max( $colname, $criteria );
sub fetch_max {
  my $self = shift;
  my $colname = shift;
  my $criteria = shift;
  
  $self->datasource->fetch_one_value( 
    columns => "max($colname)", 
    tables => $self->name, 
    criteria => $criteria,
  );
}

########################################################################

=head2 Storage And Source Management

=over 4

=item detect_datasource

  $table->detect_datasource : $flag

Detects whether the SQL database is avaialable by attempting to connect.


=item table_exists

  $table->table_exists : $flag

Checks to see if the table exists in the SQL database by attempting to retrieve its columns.


=back

=cut

# $flag = $table->detect_datasource;
sub detect_datasource {
  my $self = shift;
  my $datasource = $self->datasource
	or return;
  $datasource->detect_any;
}

# $flag = $table->table_exists;
sub table_exists {
  my $self = shift;
  $self->datasource->detect_table( $self->name ) ? 1 : 0;
}

########################################################################

=head2 ColumnSet

=over 4

=item columnset

  $table->columnset () : $columnset

Returns the current columnset, if any.

=item get_columnset

  $table->get_columnset () : $columnset

Returns the current columnset, or runs a trivial query to detect the columns in the DataSource. If the table doesn't exist, the columnset will be empty.

=item columns

  $table->columns () : @columns

Return the column objects from the current columnset.

=item column_names

  $table->column_names () : @column_names

Return the names of the columns, in order.

=item column_named

  $table->column_named ( $name ) : $column

Return the column info object for the specicifcally named column.

=back

=cut

use Class::MakeMethods (
  'Standard::Hash:object' => { name=>'columnset', class=>'DBIx::DBO2::ColumnSet' },
  'Standard::Universal:delegate' => [
    [ qw( columns column_names column_named column_primary ) ] => { target=>'get_columnset' },
  ],
);

# KLUDGE
sub column_primary_name {
  # should croak if we've got a multiple-column primary key?
  return 'id';
}

sub get_columnset {
  my $self = shift;
  
  if ( my $columns = $self->columnset ) { return $columns }
  
  my @columns = $self->datasource->detect_table( $self->name );
  $self->columnset( DBIx::DBO2::ColumnSet->new( @columns ) );
}

########################################################################

=head2 DDL

=over 4

=item table_create

  $table->table_create () 
  $table->table_create ( $column_ary ) 

=item table_drop

  $table->table_drop () 

=item table_ensure_exists

  $table->table_ensure_exists ( $column_ary )

Create the table's remote storage if it does not already exist.

=item table_recreate

  $table->table_recreate ()

Remove and then recreate the table's remote storage.

=back

=cut

# $self->table_create();
sub table_create {
  my $self = shift;
  my $columnset = shift || $self->columnset;
  $self->datasource->do_create_table( $self->name, $columnset->as_hashes ) ;
}

# $sql_stmt = $table->table_drop();
sub table_drop {
  my $self = shift;
  $self->datasource->do_drop_table( $self->name ) ;
}

# $table->table_ensure_exists( $column_ary )
  # Create the remote data source for a table if it does not already exist
sub table_ensure_exists {
  my $self = shift;
  $self->table_create(@_) unless $self->table_exists;
}

# $table->table_recreate
# $table->table_recreate( $column_ary )
  # Delete the source, then create it again
sub table_recreate { 
  my $self = shift;
  my $column_ary = shift || $self->columns;
  $self->table_drop if ( $self->table_exists );
  $self->table_create( $column_ary );
}

# $package->table_recreate_with_rows;
# $package->table_recreate_with_rows( $column_ary );
sub table_recreate_with_rows {
  my $self = shift;
  my $column_ary = shift || $self->columns;
  my $rows = $self->fetch_select();
  $self->table_drop;
  $self->table_create( $column_ary );
  $self->insert_rows( $rows );
}

########################################################################

=head1 SEE ALSO

See L<DBIx::DBO2> for an overview of this framework.

=cut

########################################################################

1;
