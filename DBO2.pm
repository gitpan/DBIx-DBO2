=head1 NAME

DBIx::DBO2 - Objects mapping to SQL relational structures

=head1 SYNOPSIS

  package MyRecord;
  use DBIx::DBO2::Record '-isasubclass';
  my $sql_engine = DBIx::SQLEngine->new( $dsn, $user, $pass );
  
  MyRecord->table(
    DBIx::DBO2::Table->new(name=>'myrecords', datasource=>$sql_engine)
  );
  
  package main;
  my $results = MyRecord->fetch_all;
  foreach my $record ( $results->records ) {
    if ( $record->{age} > 20 ) {
      $record->{status} = 'adult';
      $record->save_row;
    }
  }

=head1 DESCRIPTION

DBIx::DBO2 is an object-relational mapping framework (or perhaps a relational-object mapping framework, if I understand the distinction correctly) that facilitates the development of Perl classes whose objects are stored in a SQL database table.

The following classes are included:

  Table		TableSet
  Column	ColumnSet
  Record	RecordSet
  Fields

Each Table object represents a single SQL table. 

Each Record object represents a single row in a SQL table.

The Fields class generates accessor methods for Record classes.

The I<name>Set classes are each simple classes for blessed arrays of class I<name>.

=cut

########################################################################

package DBIx::DBO2;

require 5.005;
use strict;

use vars qw( $VERSION );
$VERSION = 0.002;

use DBIx::SQLEngine;

use DBIx::DBO2::Table;

use DBIx::DBO2::ColumnSet;
use DBIx::DBO2::Column;

use DBIx::DBO2::RecordSet;
use DBIx::DBO2::Record;

use DBIx::DBO2::TableSet;

use DBIx::DBO2::Fields;

########################################################################

=head1 SEE ALSO

See L<DBIx::DBO2::Record>, L<DBIx::DBO2::Fields>, L<DBIx::DBO2::Table>, and L<DBIx::DBO2::TableSet> for key interfaces.

See L<DBIx::DBO2::ReadMe> for distribution and license information.

=cut

########################################################################

=head1 CREDITS AND COPYRIGHT

=head2 Developed By

  M. Simon Cavalletto, simonm@cavalletto.org
  Evolution Softworks, www.evoscript.org

=head2 Contributors

  Piglet / EJ Evans, piglet@piglet.org
  Eric Schneider, roark@evolution.com
  Chaos / Matthew Sheahan

=head2 Copyright

Copyright 2002 Matthew Simon Cavalletto. 

Portions copyright 1997, 1998, 1999, 2000, 2001 Evolution Online Systems, Inc.

=head2 License

You may use, modify, and distribute this software under the same terms as Perl.


=cut

########################################################################

1;
