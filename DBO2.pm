=head1 NAME

DBIx::DBO2 - Perl extension for blah blah blah

=head1 SYNOPSIS

  use DBIx::DBO2;
  blah blah blah

=head1 DESCRIPTION

DBIx::DBO2 is an object-relational mapping framework that facilitates the development of Perl classes whose objects are stored in a SQL database table.

=cut

########################################################################

package DBIx::DBO2;

use 5.006;
use strict;
use warnings;

our $VERSION = 0.001;

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

See L<DBIx::DBO2::ReadMe> for distribution and license information.

=cut

########################################################################

1;
