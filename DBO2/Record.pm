=head1 NAME

DBIx::DBO2::Record - A row in a table in a datasource

=head1 SYNOPSIS

  package MyRecord;
  use DBIx::DBO2::Record '-isasubclass';
  MyRecord->table( DBIx::DBO2::Table->new( name=>'foo', datasource=>$ds ) );

  package main;
  my $results = MyRecord->fetch_all;
  foreach ( $results->records ) {
    
  }

=head1 DESCRIPTION

The DBIx::DBO2::Record class represents database records in tables accessible via DBIx::SQLEngine.

By subclassing this package, you can easily create a class whose instances represent each of the rows in a SQL database table.

=cut

package DBIx::DBO2::Record;

use strict;
use Carp;

########################################################################

=head1 REFERENCE

=cut

use Class::MakeMethods;
use DBIx::DBO2::Table;
use DBIx::SQLEngine::Criteria;

########################################################################

=head2 Subclass Factory

=over 4

=item import

  package My::Record;
  use DBIx::DBO2::Record '-isasubclass';

Allows for a simple declaration of inheritance.

=back

=cut

sub import {
  my $class = shift;
  
  if ( scalar @_ == 1 and $_[0] eq '-isasubclass' ) {
    shift;
    my $target_class = ( caller )[0];
    no strict;
    push @{"$target_class\::ISA"}, $class;
  }
  
  $class->SUPER::import( @_ );
}

########################################################################

# =item type - Template::ClassName:subclass_name
#
# Access subclasses by name.

# Class::MakeMethods->make(
#   'Template::ClassName:subclass_name' => 'type',
# );

########################################################################

=head2 Table and SQLEngine

Each Record class stores a reference to the table its instances are stored in.

=over 4

=item table

  RecordClass->table ( $table )
  RecordClass->table () : $table

Establishes the table a specific class of record will be stored in.

=item count_rows

  RecordClass->count_rows () : $integer

Delegated to table.

=item datasource

  RecordClass->datasource () : $datasource

Delegated to table. Returns the table's SQLEngine.

=item do_sql

  RecordClass->do_sql ( $sql_statement ) 

Delegated to datasource.

=back

=cut

Class::MakeMethods->make(
  'Template::ClassInherit:object' => [ table => { class => 'DBIx::DBO2::Table' } ],
  'Standard::Universal:delegate' => [ 
    [ qw/ count_rows / ] => { target=>'table' },
    [ qw/ datasource / ] => { target=>'table' },
    [ qw/ do_sql / ] => { target=>'datasource' },
  ],
);

sub demand_table {
  my $self = shift;
  my $class = ref( $self ) || $self;
  $self->table() or croak("No table set for $class");
}

########################################################################

=head2 Constructor

Record objects are constructed when they are fetched from their table as described in the next section, or you may create your own for new instances.

=over 4

=item new 

  my $obj = MyRecord->new( method1 => value1, ... ); 

  my $shallow_copy = $record->new;

Create a new instance.
(Class::MakeMethods::Standard::Hash:new).

=item clone

  my $similar_record = $record->clone;

Makes a copy of a record and then clears its id so that it will be recognized as a distinct, new row in the database rather than overwriting the original when you save it.

=item post_new

Inheritable Hook. Subclasses should override this with any functions they wish performed immediately after each record is created and initialized.

=back

=cut

use Class::MakeMethods::Composite::Hash (
  'new' => [ 'new' => { post_rules => [ sub { map $_->post_new, Class::MakeMethods::Composite->CurrentResults } ] } ],
);

use Class::MakeMethods::Composite::Inheritable(hook=>'post_new' ); 

sub clone { (shift)->new( 'id' => '', @_ ) }

########################################################################

=head2 Selecting Records

=over 4

=item fetch_records

  $recordset = My::Students->fetch_records( criteria => {status=>'active'} );

Fetch all matching records and return them in a RecordSet.

=item fetch_one

  $dave = My::Students->fetch_one( criteria => { name => 'Dave' } );

Fetch a single matching record.

=item fetch_id

  $prisoner = My::Students->fetch_id( 6 );

Fetch a single record based on its primary key.

=item refetch_record

  $record->refetch_record();

Re-retrieve the values for this record from the database based on its primary key. 

=item post_fetch

Inheritable Hook. Subclasses should override this with any functions they wish performed immediately after each record is retrieved from the database.

=back

=cut

use Class::MakeMethods::Composite::Inheritable( hook=>'post_fetch' ); 

sub fetch_records {
  my $row_or_class = shift;
  my $class = ref( $row_or_class ) || $row_or_class;
  my $table = $row_or_class->table() or croak("No table set for $class");  
  my $rows = $table->fetch_select( @_ );
  bless [ map { bless $_, $class; $_->post_fetch; $_ } @$rows ], 'DBIx::DBO2::RecordSet';
}

sub fetch_one {
  my $row_or_class = shift;
  my $class = ref( $row_or_class ) || $row_or_class;
  my $table = $row_or_class->table() or croak("No table set for $class");  
  my $rows = $table->fetch_select( @_ );
  my $row = $rows->[0] or return;
  warn "fetch_one found multiple matches" if ( scalar @$rows > 1 );
  bless $row, $class;
  $row->post_fetch;
  $row;
}

sub fetch_id {
  my $row_or_class = shift;
  my $class = ref( $row_or_class ) || $row_or_class;
  my $table = $row_or_class->table() or croak("No table set for $class");  
  my $row = $table->fetch_id( @_ ) or return;
  bless $row, $class;
  $row->post_fetch;
  $row;
}

sub refetch_record {
  my $self = shift();
  my $class = ref( $self ) || $self;
  my $table = $self->table() or croak("No table set for $class");  
  my $id = $self->{ $table->id_column() };
  my $db_row = $table->fetch_id( $id )
    or confess;
  %$self = %$db_row;
  $self->post_fetch;
  $self;
}

########################################################################

=head2 Row Inserts

After constructing a record, you may save any changes by calling insert_record.

=over 4

=item insert_record

  $record->insert_record () 

=item pre_insert

Inheritable Hook. Subclasses should override this with any functions they wish performed before a row is written out to the database.

=item post_insert

Inheritable Hook. Subclasses should override this with any functions they wish performed after a row is written out to the database.

=back

=cut

use Class::MakeMethods::Composite::Inheritable(hook=>'pre_insert post_insert'); 

# $row->insert_record()
sub insert_record {
  my $row = shift;
  my $class = ref( $row ) or croak("Not a class method");
  my $table = $class->demand_table();
  $row->pre_insert();
  $table->insert_row( $row );
  $row->post_insert();
  1;
}

########################################################################

=head2 Row Updates

After retrieving a record, you may save any changes by calling update_record.

=over 4

=item update_record

  $record->update_record () 

=item pre_update

Inheritable Hook. Subclasses should override this with any functions they wish performed before a row is written out to the database.

=item post_update

Inheritable Hook. Subclasses should override this with any functions they wish performed after a row is written out to the database.

=back

=cut

use Class::MakeMethods::Composite::Inheritable(hook=>'pre_update post_update'); 

# $row->update_record()
sub update_record {
  my $row = shift;
  my $class = ref( $row ) or croak("Not a class method");
  my $table = $class->demand_table();
  $row->pre_update();
  $table->update_row( $row );
  $row->post_update();
  1;
}

########################################################################

=head2 Deletion

=over 4

=item delete_record 

  $record->delete_record () : $boolean_completed

Checks to see if pre_delete returns a false value. If not, asks the table to delete the row.

=item pre_delete

  $record->pre_delete () : $boolean_is_ok

Subclasses may override this to provide validation or other behavior

=item post_delete

  $record->post_delete ()

Called after a record has been deleted from the datasource.

=back

=cut

use Class::MakeMethods::Composite::Inheritable(hook=>'pre_delete post_delete'); 

# $success = $row->delete_record();
sub delete_record {
  my $self = shift;
  my $flag = $self->pre_delete;
  if ( defined $flag and ! $flag ) {
    return 0;
  } else {
    $self->table->delete_row($self);
    $self->post_delete();
    return 1;
  }
}

########################################################################

=head2 Load and Save Wrappers

Wrappers for new/fetch and insert/update.

=over 4

=item get_record 

  RecordClass->get_record ( $id_or_undef ) : $new_or_fetched_record_or_undef

Calls new if no ID is provided, or if the ID is the special string "-new"; otherwise calls fetch_id.

=item save_record

  $record->save_record () : $boolean_completed

Determines whether the record has an id assigned to it and then calls either insert_record or update_record.

=back

=cut

# $row = $package->get_record()
# $row = $package->get_record( $id )
sub get_record {
  my $package = shift;
  my $id = shift;
  if ( ! $id or $id eq "-new" ) {
    $package->new();
  } else {
    $package->fetch_id( $id );
  }
}

# $row->save_record()
sub save_record {
  my $row = shift;
  if ( $row->{id} and $row->{id} eq 'new' ) {
    undef $row->{id};
  }
  if ( $row->{'id'} ) {
    $row->update_record( @_ );
    1;
  } else {
    $row->insert_record( @_ );
  }
}

########################################################################

=head2 Modification Wrappers

Simple interface for applying changes.

=over 4

=item call_methods 

  $record->call_methods( method1 => value1, ... ); 

Call provided method names with supplied values.
(Class::MakeMethods::Standard::Universal:call_methods).

=item change_and_save 

  RecordClass->new_and_save ( %method_argument_pairs ) : $record

Calls call_methods, and then save_record.

=item change_and_save 

  $record->change_and_save ( %method_argument_pairs ) : $record

Calls call_methods, and then save_record.

=back

=cut

use Class::MakeMethods::Standard::Universal ( 'call_methods'=>'call_methods' );

# $row->new_and_save( 'fieldname' => 'new_value', ... )
sub new_and_save {
  my $callee = shift;
  my $row = $callee->new( @_ );
  $row->save_record;
  $row;
}

# $row->change_and_save( 'fieldname' => 'new_value', ... )
sub change_and_save {
  my $row = shift;
  $row->call_methods( @_ );
  $row->save_record;
  $row;
}

########################################################################

=head1 SEE ALSO

See L<DBIx::DBO2> for an overview of this framework.

=cut

########################################################################

1;
