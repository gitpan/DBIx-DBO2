=head1 NAME

DBIx::DBO2::ColumnSet - Array of DBIx::DBO2::Column objects

=head1 SYNOPSIS

  my $colset = DBIx::DBO2::ColumnSet->new( $column1, $column2 );
  
  print $colset->count;
  
  foreach my $column ( $colset->contents ) {
    print $column->name;
  }
  my $name_col = $column

=head1 DESCRIPTION

DBIx::DBO2::ColumnSet objects contain an ordered set of DBIx::DBO2::Column objects

=cut

package DBIx::DBO2::ColumnSet;
use strict;
use Carp;

########################################################################

=head1 PUBLIC INTERFACE

=head2 Constructor

Multiple subclasses based on type.

=over 4

=item new ( @columns ) : $columnset

=back

=cut

sub new {
  my $package = shift;
  my @cols = map {
    my $col = DBIx::DBO2::Column->new( type => $_->{type}, );
    foreach my $k ( grep { $_ ne 'type' and $col->can($_) } keys %$_ ) {
      $col->$k($_->{$k});
    }
    $col;
  } @_;
  bless [ @cols ], $package;
}

sub as_hashes {
  my $colset = shift;
  my @columns;
  foreach my $column ( @$colset ) {
    push @columns, {
      map( { $_ => $column->$_() } qw( name type required ) ),
      map( { $_ => $column->$_() } grep { $column->can($_) } qw( length ) ),
    };
  }
  \@columns;
}

########################################################################

=head2 Column Access

=over 4

=item columns () : @columns

Returns a list of column objects. 

=item column_names () : @column_names

Returns the result of calling name() on each column.

=item column_named ( $name ) : $column

Finds the column with that name, or dies trying.

=item column_primary () : $primary_key

KLUDGE - set to find 'id'.

=back

=cut

sub columns {
  my $colset = shift;
  @$colset
}

# @colnames = $colset->column_names;
sub column_names {
  my $colset = shift;
  return map { $_->name } @$colset;
}

# $column = $colset->column_named( $column_name );
# $column = $colset->column_named( $column_name );
sub column_named {
  my $colset = shift;
  my $column_name = shift;
  foreach ( @$colset ) {
    return $_ if ( $_->name eq $column_name );
  }
  croak(
    "No column named $column_name in $colset->{name} table\n" . 
    "  (Perhaps you meant one of these: " . 
	join(', ', map { $_->name() . " (". $_->type() .")" } @$colset) . ")"
  );
}

sub column_primary {
  (shift)->column_named( 'id' );
}

1;
