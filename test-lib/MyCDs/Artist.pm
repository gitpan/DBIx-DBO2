package MyCDs::Artist;

use strict;
use DBIx::DBO2::Record '-isasubclass';
require MyCDs;

use DBIx::DBO2::Fields (
  { name => 'id', field_type => 'number', required => 1 },
  { name => 'name', field_type => 'string', length => 64, required => 1 },
);

1;
