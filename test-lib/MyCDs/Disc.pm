package MyCDs::Disc;

use strict;
use DBIx::DBO2::Record '-isasubclass';

use DBIx::DBO2::Fields (
  { name => 'id', field_type => 'number', required => 1 },
  { name => 'name', field_type => 'string', length => 64, required => 1 },
  { name => 'year', field_type => 'number' },
  { name => 'artist', field_type => 'number' },
  { name => 'genre', field_type => 'number' },
  { name => 'recorded', field_type => 'timestamp', interface => 'created' },
  { name => 'updated', field_type => 'timestamp', interface => 'modified' },
);

1;
