=head1 NAME

DBIx::DBO2::Column - Struct for database column info

=head1 SYNOPSIS

  my $col = DBIx::DBO2::Column->new( name=>$colname, type=>$typename   );
  
  print $col->name;
  
  if ( $col->type eq 'text' ) {
    print "text, length " . $col->length;
  } else {
    print $col->type;
  }

=head1 DESCRIPTION

DBIx::DBO2::Column objects hold information about columns in a database table or query result.

They are generally contained in a DBIx::DBO2::ColumnSet.

=cut

package DBIx::DBO2::Column;
use strict;

########################################################################

=head1 PUBLIC INTERFACE

=head2 Constructor

Multiple subclasses based on type.

=over 4

=item new - Template::Hash:new

=item type - Template::ClassName:subclass_name

=back

=cut

use Class::MakeMethods (
  'Template::Hash:new' => 'new',
  'Template::ClassName:subclass_name' => 'type',
);

sub DESTROY {} 

########################################################################

=head2 Attributes

These methods are available for all types of column.

=over 4

=item name - Template::Hash:string

=item required - Template::Hash:boolean

=back

=cut

use Class::MakeMethods::Template::Hash (
  string		=> 'name',
  boolean		=> 'required',
);

########################################################################

=head2 text Attributes  

These methods are only available for columns of type text.

=over 4

=item length - Template::Hash:number

=back

=cut

package DBIx::DBO2::Column::text; 
@DBIx::DBO2::Column::text::ISA = 'DBIx::DBO2::Column';

use Class::MakeMethods::Template::Hash (
  number		=> 'length',
);

########################################################################

=head1 VERSION

2001-06-27 Moved to DBIx::DBO2:: namespace. Switched to Class::MakeMethods

2001-01-29 Added boolean required to store whether column is nullable.

2000-11-29 Switched to use of Class::MethodMaker 2.0 features.

1999-07-27 Simon: Created.


=head1 AUTHORS

Developed by Evolution Online Systems:

  M. Simon Cavalletto, simonm@evolution.com


=head1 LICENSE

This module is free software. It may be used, redistributed and/or
modified under the same terms as Perl.

Copyright (c) 1999, 2000, 2001 Evolution Online Systems, Inc.

=cut

########################################################################

1;
