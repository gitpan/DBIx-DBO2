package MyCDs::Genre;

use strict;
use DBIx::DBO2::Record '-isasubclass';

use DBIx::DBO2::Fields (
  { name => 'id', field_type => 'number', required => 1 },
  { name => 'name', field_type => 'string', length => 64, required => 1 },
);

1;

