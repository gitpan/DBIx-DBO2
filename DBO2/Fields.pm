=head1 NAME

DBIx::DBO2::Fields - Construct methods for database fields


=head1 SYNOPSIS

  package MyCDs::Disc;
  
  use DBIx::DBO2::Record '-isasubclass';
  
  use DBIx::DBO2::Fields (
    { name => 'id', field_type => 'number', required => 1 },
    { name => 'name', field_type => 'string', length => 64, required => 1 },
    { name => 'year', field_type => 'number' },
    { name => 'artist', field_type => 'number' },
    { name => 'genre', field_type => 'number' },
  );
  
  1;


=head1 DESCRIPTION

This package creates methods for DBIx::DBO2::Record objects.

It's based on Class::MakeMethods::Template.

=head2 Accessing Field Attributes

Calling C<-E<gt>fields()> on a class or instance returns a hash of field-name => field-attribute-hash pairs. 

  my %fields = BD::Customer::Account->fields();
  foreach my $fieldname ( sort keys %fields ) {
    my $field = $fields{ $fieldname };
    print "$fieldname is a $field->{meta_type} field\n";
    print "  $fieldname is required\n" if ( $field->{required} );
    print "  $fieldname max length $field->{length}\n" if ( $field->{length} );
  }

You can also pass in a field name to retrieve its attributes.

  print BD::Customer::Account->fields('public_id')->{'length'};

The results of C<-E<gt>fields()> includes field information inherited from superclasses. To access only those fields declared within a particular class, call C<-E<gt>class_fields()> instead.

=cut

package DBIx::DBO2::Fields;

use strict;

use Class::MakeMethods::Template;
use base qw( Class::MakeMethods::Template );

########################################################################

sub make {
  my $callee = shift;
  if ( ref( $_[0] ) eq 'HASH' ) {
    $callee->SUPER::make( map { $_->{field_type} => $_ } @_ )
  } else {
    $callee->SUPER::make( @_ )    
  }
}

########################################################################

my %ClassInfo;

sub generic {
  {
    'params' => {
      'hash_key' => '*',
      'column_autodetect' => [],
    },
    'interface' => {
      default       => { '*'=>'get_set', '*_invalid' => 'invalid' },
      read_only	    => { '*'=>'get' },
      init_and_get  => { '*'=>'get_init', -params=>{init_method=>'init_*'} },
    },
    'code_expr' => { 
      _VALUE_ => '_SELF_->{_STATIC_ATTR_{hash_key}}',
      '-import' => { 'Template::Generic:generic' => '*' },
    },
    'behavior' => {
      'get_set' => q{ 
	  if ( scalar @_ ) {
	    _BEHAVIOR_{set}
	  } else {
	    _BEHAVIOR_{get}
	  }
	},
      'get' => q{ 
	  _GET_VALUE_
	},
      'set' => q{ 
	  _SET_VALUE_{ $_[0] }
	},
      'get_init' => q{
	  my $init_method = _ATTR_{'init_method'};
	  _SET_VALUE_{ _SELF_->$init_method( @_ ) } unless ( defined _VALUE_ );
	  _GET_VALUE_;
	},
      'detect_column_attributes' => q{ 
	  DBIx::DBO2::Fields::_column_autodetect( _SELF_, $m_info, )
			  if ( $m_info->{column_autodetect} );
	},
      -register => sub {
	my $m_info = shift;
	$ClassInfo{$m_info->{target_class}} ||= {};
	my $target_info = $ClassInfo{$m_info->{target_class}};
	$target_info->{ $m_info->{name} } = $m_info;
	push @{ $target_info->{'-order'} }, $m_info;
	
	if ( my $hooks = $m_info->{'hook'} ) {
	  while ( my ( $method, $code ) = each %$hooks ) {
	    if ( ref($code) eq 'CODE' ) {
	    } elsif ( ! ref($code) ) {
	      my $mname = $code;
	      $mname =~ s/\*/$m_info->{name}/g;
	      $code = sub { (shift)->$mname() };
	    } else {
	      die "Unsurpported Field hook $method => '$code'";
	    }
	    $m_info->{target_class}->$method( 
	      Class::MakeMethods::Composite::Inheritable->Hook( $code )
	    )
	  }
	}
	
	return (
	  'class_fields' => sub { 
	    my $self = shift;
	    ( scalar(@_) == 0 ) ? map { $_->{name}, $_ } @{ $target_info->{'-order'} }: 
	    ( scalar(@_) == 1 ) ? $target_info->{$_[0]} : 
				  @{$target_info}{ @_ };
	  },
	  'fields' => sub { 
	    my $self = shift;
	    my @sources = ref($self) || $self;
	    my @results;
	    
	    # Extract field information for all superclasses
	    while ( my $class = shift @sources ) {
	      no strict;
	      push @sources, @{"$class\::ISA"};
	      unshift @results, $class->class_fields() 
					  if ( $class->can('class_fields') );
	    }
	    
	    # Re-definitions in later classes override earlier ones of same name
	    my %results = @results;
	    
	    # But names are added in order defined, from earlier to later
	    my ( @names, %names );
	    while ( scalar @results ) {
	      my ( $name, $info ) = splice( @results, 0, 2 );
	      push @names, $name unless ( $names{ $name } ++ );
	    }
	    
	    foreach my $field ( values %results ) {
	      DBIx::DBO2::Fields::_column_autodetect( $self, $field )
			  if ( $field->{column_autodetect} );
	    }
	    
	    ( scalar(@_) == 0 ) ? (wantarray ? @results{ @names } : [@results{ @names }] ) : 
	    ( scalar(@_) == 1 ) ? $results{$_[0]} : 
				  (wantarray ? @results{ @_ } : [@results{ @_ }] )
	  },
	  'field_columns' => sub { 
	    my $self = shift;
	    my @columns;
	    foreach my $info ( $self->fields ) {
	      my %colinfo = ( 
		name => $info->{name}, 
		type => $info->{column_type}, 
		( $info->{length} ? ( length => $info->{length} ) : () ),
		( $info->{required} ? ( required => $info->{required} ) : () ),
	      );
	      push @columns, \%colinfo if ( $colinfo{type} );
	    }
	    wantarray ? @columns : \@columns;
	  },
	);
      },
    }
  }
}

sub _look_for_column {
  my ($record, $colname) = @_;
  return unless ( UNIVERSAL::can($record, 'table') );
  my @columns = $record->table->columns;
  foreach my $column ( @columns ) {
    return $column if ( $column->name eq $colname );
  }
}

sub _column_autodetect {
  my ($record, $field) = @_;

  my @attribs = @{ $field->{column_autodetect} };
  my $autocol;
  while ( scalar @attribs ) {
    my($name, $default) = (shift(@attribs), shift(@attribs));
    if ( ! defined $field->{$name} ) {
      $autocol ||= _look_for_column($record, $field->{hash_key});
      if ( $autocol and $autocol->can($name) ) {
	$field->{$name} = $autocol->$name();
      } else {
	$field->{$name} = defined($default) ? $default : 0;
      }
    }
  }
  delete $field->{column_autodetect};
}

########################################################################

=head1 STRING FIELDS

=head2 Field Type string

Generates methods corresponding to a SQL varchar column.

=head3 Default Interface

The general usage for a string field is:

  use DBIx::DBO2::Fields (
    string => 'x',
  );

This declaration will generate methods to support the following interface:

=over 4

=item *

I<$record>-E<gt>x() : I<value>

Returns the value of field x for the given record.

=item *

I<$record>-E<gt>x( I<value> ) 

Sets the value of field x for the given record.

=item *

I<$record>-E<gt>x_invalid() : I<fieldname> => I<error_message>, ...

Check for any error conditions regarding the current value of field x. See Validation, below.

=back

=head3 Validation

String fields provide basic error-checking for required values or text that is too long to fit into the associated database column.

You may specify the length of the column and whether a field is required in your field declaration:

  use DBIx::DBO2::Fields (
    string => '-required 1 -length 64 x',
    string => '-required 0 -length 255 y',
  );

If you leave the required and length attributes undefined, an attempt will be made to detect them automatically, by checking the database table associated with the current object for a column whose name matches the field's.

  use DBIx::DBO2::Fields (
    string => 'x',
    string => 'y',
  );

  create table xyzzy ( 
    x varchar(64) not null,
    y varchar(255)
  );


=head3 The --init_and_get Interface

The string field also supports the following declaration for values which only need to be calculated once:

  use DBIx::DBO2::Fields (
    string => '--init_and_get x',
  );

=over 4

=item *

I<$record>-E<gt>x() : I<value>

Returns the value of field x for the given record.

If the value of field x is undefined, it first calls an initialization method and stores the result. The default it to call a method named init_x, but you can override this by providing a different value for the init_method attribute.

  use DBIx::DBO2::Fields (
    string => '--init_and_get -init_method find_spot x',
  );

Or equivalently, and perhaps more readably:

  use DBIx::DBO2::Fields (
    string => [ '--init_and_get', x, { init_method => 'find_spot' } ],
  );

=back

=cut

sub string {
  {
    '-import' => { 
      '::DBIx::DBO2::Fields:generic' => '*' 
    },
    'params' => {
      'length' => undef,
      'required' => undef,
      'column_type' => 'text',
      'column_autodetect' => [ 'required', 0, 'length', 0 ],
    },
    'behavior' => {
      'set' => q{ 
	  Carp::carp "Setting " . _ATTR_{name} . " to object value" 
							if ( ref $_[0] );
	  _SET_VALUE_{ "$_[0]" };
	},
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => "This field can not be left empty."
	    }
	    if ( my $length = _ATTR_{length} ) {
	      return _ATTR_{name} => "This field can not hold more than $length " . 
			"characters." if ( length( $_ ) > $length );
	    }
	  }
	},
    },
  }
}


########################################################################

=head2 Field Type phone_number

Identical to the string type.

=cut

sub phone_number {
  {
    '-import' => { '::DBIx::DBO2::Fields:string' => '*' },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'EBiz::Postal::Address',
    },
    'behavior' => {
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => "This field can not be left empty."
	    }
	    if ( $_ ) {
	      my $error_msg = _QUANTITY_CLASS_->invalid_phone(_GET_VALUE_);
	      return _ATTR_{name} => $error_msg if $error_msg;
	    }
	  }
	},
    },
  }
}

=head2 Field Type post_code

Identical to the string type.

=cut

sub post_code {
  {
    '-import' => { '::DBIx::DBO2::Fields:string' => '*' },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'EBiz::Postal::Address',
    },
    'behavior' => {
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => "This field can not be left empty."
	    }
	    if ( $_ ) {
	      my $error_msg = $self->invalid_postcode(_GET_VALUE_);
	      return _ATTR_{name} => $error_msg if $error_msg;
	    }
	  }
	},
    },
  }
}

=head2 Field Type state_province

Identical to the string type.

=cut

sub state_province {
  {
    '-import' => { '::DBIx::DBO2::Fields:string' => '*' },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'EBiz::Postal::Address',
    },
    'behavior' => {
      'set' => q{ 
	  Carp::carp "Setting " . _ATTR_{name} . " to canonical value";
	  if ($self->state_object( $_[0] )) {
	    _SET_VALUE_{ $self->state_object( $_[0] )->id };
	  } else {
	    _SET_VALUE_{ $_[0] };
	  }
	},
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => "This field can not be left empty."
	    }
	    if ( $_ ) {
	      my $error_msg = $self->invalid_state(_GET_VALUE_);
	      return _ATTR_{name} => $error_msg if $error_msg;
	    }
	  }
	},
    },
  }
}

=head2 Field Type email_addr

Identical to the string type.

=cut

sub email_addr {
  {
    '-import' => { '::DBIx::DBO2::Fields:string' => '*' },
    'behavior' => {
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => "This field can not be left empty."
	    }
	    if ( $_ ) {
	      my $error_msg = DBIx::DBO2::Fields::invalid_email_address(_GET_VALUE_);
	      return _ATTR_{name} => $error_msg if $error_msg;
	    }
	  }
	},
    },
  }
}

## Validation

# $boolean = invalid_email_address()
sub invalid_email_address {
  my $email = shift;
  require Net::DNS;
  return 'This does not appear to be a valid e-mail address.'
    unless $email =~ /^([\w\.-]+)\@([\w\.-]+)$/o;
  my($User, $Host) = ($1, $2);
  return 'This does not appear to be a valid e-mail domain.'
    unless ( defined(mx($Host)) or defined(gethostbyname($Host)) );
  return;
}

########################################################################

=head2 Field Type creditcardnumber

If you declare the following:

  use DBIx::DBO2::Fields (
    creditcardnumber => "ccnum",
  );

You can now use these methods:

  # Set and get raw value
  $customer->ccnum('4242424242424242');
  $customer->ccnum() eq '4242424242424242';

  # Analyze card number
  $customer->ccnum_checksum() == 1;
  $customer->ccnum_flavor() eq 'VISA card';

  # Opaque readable value for display
  $customer->ccnum_readable() eq '************4242';

  # Setting the readable value to the prior opaque value has no effect
  $customer->ccnum_readable('************4242');
  $customer->ccnum() eq '4242424242424242';

  # But setting the readable value to another value overwrites the contents
  $customer->ccnum_readable('1234-5678-9101-1213');
  $customer->ccnum() eq '1234-5678-9101-1213';

  # Recognize bogus cards by the following characteristics...
  $customer->ccnum_checksum() == 0;
  $customer->ccnum_flavor() eq 'Unrecognized';
  $customer->ccnum_readable() eq '1234-5678-9101-1213';

=cut

sub creditcardnumber {
  {
    '-import' => { '::DBIx::DBO2::Fields:number' => '*' },
    'interface' => {
      default	    => { 
	'*'=>'get_set',
	# 'clear_*'=>'clear',
	'*_readable'=>'readable',
	'*_flavor'=>'flavor',
	'*_invalid'=>'invalid',
	'*_checksum'=>'checksum',
      },
    },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'Data::Quantity::Finance::CreditCardNumber',
    },
    'behavior' => {
      '-init' => [ sub { 
	  require Data::Quantity::Finance::CreditCardNumber;
	  return;
	} ],
      'get' => q{ 
	  my $value = _GET_VALUE_;
	  length($value) ? sprintf( '%.0f', $value ) : undef;
	},
      'set' => q{ 
	  _SET_VALUE_{ _QUANTITY_CLASS_->new( shift() )->value }
	},
      'readable' => q {
	  if ( scalar @_ ) {
	    # warn "in readable, got input";
	    my $value = shift;
	    if ( ! length( $value ) ) {
	      _SET_VALUE_{ undef }
	    } elsif ( $value ne _QUANTITY_CLASS_->readable_value(_GET_VALUE_) ) {
	      # warn "in readable, setting input to '$value' for " . _QUANTITY_CLASS_->readable_value(_GET_VALUE_) . ' aka ' . (_GET_VALUE_ + 0);
	      _SET_VALUE_{ _QUANTITY_CLASS_->new( $value )->value }
	    }
	  } else {
	      # warn "in readable, didn't get input";
	    _QUANTITY_CLASS_->readable_value(_GET_VALUE_)
	  }
	},
      'flavor' => q {
	  _QUANTITY_CLASS_->flavor_value(_GET_VALUE_)
	},
      'checksum' => q {
	  _QUANTITY_CLASS_->checksum_value(_GET_VALUE_)
	},
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => "This field can not be left empty."
	    }
	    if ( my $length = _ATTR_{length} ) {
	      return _ATTR_{name} => "Number must not be longer than ".
		"$length characters." if ( length( $_ ) > $length );
	    }
	    if ( length $_ ) {
	      return _ATTR_{name} => "This does not appear to be a valid credit card number." unless ( _QUANTITY_CLASS_->checksum_value($_) );
	    }
	  }
	},
    },
  }
}

########################################################################

=head1 NUMBER FIELDS

=head2 Field Type number

Generates methods corresponding to a SQL int or float column.

The general usage for a number field is:

  use DBIx::DBO2::Fields (
    number => 'x',
  );

This declaration will generate methods to support the following interface:

=over 4

=item *

I<$record>-E<gt>x() : I<value>

Returns the value of field x for the given record.

=item *

I<$record>-E<gt>x( I<value> ) 

Sets the value of field x for the given record.

=item *

I<$record>-E<gt>x_readable() : I<value>

Returns the value of field x for the given record formatted for display, including commas for thousands separators.

=item *

I<$record>-E<gt>x_readable( I<value> ) 

Sets the value of field x for the given record from a possibly formatted value.

=item *

I<$record>-E<gt>x_invalid() : I<fieldname> => I<error_message>, ...

Check for any error conditions regarding the current value of field x. See Validation, below.

=back

=head3 Validation

Number fields provide error-checking for required values or values which are not numeric.

You may specify whether a field is required or allow this to be detected based on whether the corresponding database column allows null values.

=head3 The -init_and_get Interface

The number field also supports the -init_and_get provided by the string field type.

=cut

sub number {
  {
    '-import' => { 
      '::DBIx::DBO2::Fields:generic' => '*' 
    },
    'params' => {
      'required' => '0',
      'column_type' => 'int',
      'column_autodetect' => [ 'required', 0, ],
    },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'Data::Quantity::Number::Number',
    },
    'interface' => {
      -default	    => 'get_set',
      get_set       => { '*'=>'get_set', '*_readable' => 'readable', '*_invalid' => 'invalid' },
      read_only	    => { '*'=>'get' },
      init_and_get  => { '*'=>'get_init', -params=>{init_method=>'init_*'} },
    },
    'behavior' => {
      '-init' => [ sub { 
	  require Data::Quantity::Number::Number;
	  return;
	} ],
      'get' => q{ 
	  for ( _GET_VALUE_ ) { return ( length($_) ? $_ + 0 : $_ ) }
	},
      'set' => q{ 
	  Carp::carp "Setting " . _ATTR_{name} . " to non-numeric value" 
				if ( ref $_[0] or $_[0] =~ /[^\d\-\.]/ );
	  _SET_VALUE_{ length($_[0]) ? $_[0] + 0 : $_[0] };
	},
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( ref $_[0] or $_[0] =~ /[^\d\-\.]/ ) {
	      return _ATTR_{name} => " can only contain numeric values."
	    }
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => " is required."
	    }
	  }
	},
      'readable' => q {
	  if ( scalar @_ ) {
	    _SET_VALUE_{ _QUANTITY_CLASS_->new( @_ )->value }
	  } else {
	    _QUANTITY_CLASS_->readable_value(_GET_VALUE_ + 0)
	  }
	},
    },
  }
}

########################################################################


sub time_absolute {
  {
    '-import' => { '::DBIx::DBO2::Fields:number' => '*' },
    'interface' => {
      default	    => { 
	'*'=>'get_set', 
	'touch_*'=>'set_current', 
	'*_obj'=>'get_obj', 
	'*_readable'=>'readable' 
      },
      created	    => { 
	-base => 'default', 
	-params => {
	  hook => { post_new => 'touch_*' }
	},
      },
      modified	    => { 
	-base => 'default', 
	-params => {
	  hook => { pre_insert => 'touch_*', pre_update => 'touch_*'}
	},
      },
    },
    'params' => {
      'default_readable_format' => undef,
    },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'croak "Abstract code_expr should contain Quantity"',
    },
    'behavior' => {
      'set_current'	=> q{ 
	_SET_VALUE_{ _QUANTITY_CLASS_->current()->value }; 
      },
      'set' => q{ 
	  _SET_VALUE_{ _QUANTITY_CLASS_->new( shift() )->value }
	},
      'get_obj'	=> q{ 
	  _QUANTITY_CLASS_->new( _GET_VALUE_ ) 
	},
      'readable' => q{ 
	  _QUANTITY_CLASS_->new(_GET_VALUE_)->readable( 
	      scalar( @_ ) ? shift() : _ATTR_{default_readable_format}
	  )
	},
    },
  }
}

=head2 Field Type timestamp

Generates methods corresponding to a SQL int column storing a date and time in Unix seconds-since-1970 format.

=head3 Default Interface

The general usage for a timestamp field is:

  use DBIx::DBO2::Fields (
    timestamp => 'x',
  );

This declaration will generate methods to support the following interface:

=over 4

=item *

I<$record>-E<gt>x() : I<value>

Returns the raw numeric value of field x for the given record.

=item *

I<$record>-E<gt>x( I<value> ) 

I<$record>-E<gt>x( I<readable_value> ) 

Sets the value of field x for the given record. You may provide either a raw numeric value or a human-entered formatted value. 

=item *

I<$record>-E<gt>touch_x() 

Sets the value of field x to the current date and time.

=item *

I<$record>-E<gt>x_readable() : I<readable_value> 

Returns the value of field x formatted for display. 

=item *

I<$record>-E<gt>x_readable(I<format_string>) : I<readable_value> 

Returns the value of field x formatted in particular way. (See L<Data::Quantity::Time::Timestamp> for supported formats.)

=item *

I<$record>-E<gt>x_obj() : I<quantity_object> 

Gets the value of field x as a Data::Quantity::Time::Timestamp object.

=item *

I<$record>-E<gt>x_invalid() : I<fieldname> => I<error_message>, ...

Inherited from the number field. 

=back

=cut


sub timestamp {
  {
    '-import' => { '::DBIx::DBO2::Fields:time_absolute' => '*' },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'Data::Quantity::Time::Timestamp',
    },
    'behavior' => {
      '-init' => [ sub { 
	  require Data::Quantity::Time::Timestamp;
	  return;
	} ],
    },
  }
}


=head2 Field Type julian_day

Generates methods corresponding to a SQL int column storing a date in the Julian days-since-the-invention-of-fire format.

=head3 Default Interface

The general usage for a julian_day field is:

  use DBIx::DBO2::Fields (
    julian_day => 'x',
  );

This declaration will generate methods to support the following interface:

=over 4

=item *

I<$record>-E<gt>x() : I<value>

Returns the raw numeric value of field x for the given record.

=item *

I<$record>-E<gt>x( I<value> ) 

I<$record>-E<gt>x( I<readable_value> ) 

Sets the value of field x for the given record. You may provide either a raw numeric value or a human-entered formatted value. 

=item *

I<$record>-E<gt>touch_x() 

Sets the value of field x to the current date.

=item *

I<$record>-E<gt>x_readable() : I<readable_value> 

Returns the value of field x formatted for display. 

=item *

I<$record>-E<gt>x_readable(I<format_string>) : I<readable_value> 

Returns the value of field x formatted in particular way. (See L<Data::Quantity::Time::Date> for supported formats.)

=item *

I<$record>-E<gt>x_obj() : I<quantity_object> 

Gets the value of field x as a Data::Quantity::Time::Date object.

=item *

I<$record>-E<gt>x_invalid() : I<fieldname> => I<error_message>, ...

Inherited from the number field. 

=back

=cut

sub julian_day {
  {
    '-import' => { '::DBIx::DBO2::Fields:time_absolute' => '*' },
    'params' => {
      'default_readable_format' => 'mm/dd/yyyy',
    },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'Data::Quantity::Time::Date',
    },
    'behavior' => {
      '-init' => [ sub { 
	  require Data::Quantity::Time::Date;
	  return;
	} ],
    },
  }
}

########################################################################


=head2 Field Type currency_uspennies

Generates methods corresponding to a SQL int column storing a US currency value in pennies.

=head3 Default Interface

The general usage for a currency_uspennies field is:

  use DBIx::DBO2::Fields (
    currency_uspennies => 'x',
  );

This declaration will generate methods to support the following interface:

=over 4

=item *

I<$record>-E<gt>x() : I<value>

Returns the raw numeric value of field x for the given record.

=item *

I<$record>-E<gt>x( I<value> ) 

Sets the raw numeric value of field x for the given record.

=item *

I<$record>-E<gt>x_readable() : I<readable_value> 

Returns the value of field x formatted for display. 

=item *

I<$record>-E<gt>x_readable(I<readable_value>) 

Set the value of x based on a human-entered value

=item *

I<$record>-E<gt>x_invalid() : I<fieldname> => I<error_message>, ...

Inherited from the number field. 

=back

=cut

sub currency_uspennies {
  {
    '-import' => { '::DBIx::DBO2::Fields:number' => '*' },
    'interface' => {
      default	    => { '*'=>'get_set', '*_readable'=>'readable' },
    },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'Data::Quantity::Finance::Currency->type("USD")',
    },
    'behavior' => {
      '-init' => [ sub { 
	  require Data::Quantity::Finance::Currency;
	  return;
	} ],
      'set' => q{ 
	  _SET_VALUE_{ _QUANTITY_CLASS_->new( shift() )->value }
	},
      'readable' => q {
	  if ( scalar @_ ) {
	    my $value = shift;
	    if ( ! length( $value ) ) {
	      _SET_VALUE_{ undef }	      
	    } else {
	      # Stick $ on front if not there already, so Q::C knows it's not raw
	      # warn "INPUT VALUE $value";
	      $value = '$' . $value if ( $value =~ m/\A\-?\d/ );
	      # warn "VALUE $value CLASS VALUE " . _QUANTITY_CLASS_->new( $value )->value;
	      _SET_VALUE_{ _QUANTITY_CLASS_->new( $value )->value }
	    }
	  } else {
	    _QUANTITY_CLASS_->readable_value(_GET_VALUE_)
	  }
	},
    },
  }
}

########################################################################

=head2 Field Type saved_total

Used to store numeric values which only have to be calculated when the related records change.

A declaration of

  use DBIx::DBO2::Fields (
    saved_total => 'x',
  );

Is equivalent to the following method definitions:
  
  # Recalculate if status_is_cart; else return previously stored value
  sub x { 
    my $self = shift; 
    if ( $self->status_is_cart() ) {
      $self->{x} = $self->init_x();
    } else {
      $self->{x};
    }
  }
  
  # Recalculate and store the value.
  sub reset_x { 
    my $self = shift; 
    $self->{x} = $self->init_x();
  }
  
  # Is our stored value out of synch with current calculations?
  sub x_difference { 
    my $self = shift; 
    $self->init_x() - $self->{x};
  }

You are expected to provide an 'init_x' method which calculates and returns the value, but does not save it.

=cut

sub saved_total {
  {
    '-import' => { '::DBIx::DBO2::Fields:number' => '*' },
    'interface' => {
      default	    => { 
	'*'       => 'get_or_init', 
	'reset_*' => 'reset', 
	'*_difference' => 'difference', 
      },
    },
    'params' => {
      'hash_key' => '*',
      'reset_checker' => 'status_is_cart',
      'init_method' => 'init_*',
    },
    'code_expr' => {
    },
    'behavior' => {
      'get_or_init' => q{
	my $check_if_reset_needed_methd = _ATTR_{reset_checker};
	if ( $self->$check_if_reset_needed_methd() ) {
	  _BEHAVIOR_{reset}
	} else {
	  _GET_VALUE_;
	}
      },
      'reset' => q{
	my $init_method = _ATTR_{init_method};
	_SET_VALUE_{ $self->$init_method() };
      },
      'difference' => q{
	my $init_method = _ATTR_{init_method};
	$self->$init_method() - _GET_VALUE_;
      },
    },
  }
}

=head2 Field Type saved_total_uspennies

Like saved_total, but also has a read-only *_readable method that provides US Currency formatting.

=cut

sub saved_total_uspennies {
  {
    '-import' => { '::DBIx::DBO2::Fields:number' => '*' },
    'interface' => {
      default	    => { 
	'*'       => 'get_or_init', 
	'set_*' => 'set', 
	'reset_*' => 'reset', 
	'*_difference' => 'difference', 
	'*_readable' => 'readable',
      },
    },
    'params' => {
      'hash_key' => '*',
      'reset_checker' => 'status_is_cart',
      'init_method' => 'init_*',
    },
    'code_expr' => {
      _QUANTITY_CLASS_ => 'Data::Quantity::Finance::Currency->type("USD")',
    },
    'behavior' => {
      'get_or_init' => q{
	my $check_if_reset_needed_methd = _ATTR_{reset_checker};
	if ( $self->$check_if_reset_needed_methd() or ! _GET_VALUE_ ) {
	  _BEHAVIOR_{reset}
	} else {
	  _GET_VALUE_;
	}
      },
      'set' => q{
	_SET_VALUE_{ shift };
      },
      'reset' => q{
	my $init_method = _ATTR_{init_method};
	_SET_VALUE_{ int( $self->$init_method() ) };
      },
      'difference' => q{
	my $init_method = _ATTR_{init_method};
	$self->$init_method() - _GET_VALUE_;
      },
      'readable' => q{
	my $check_if_reset_needed_methd = _ATTR_{reset_checker};
	if ( $self->$check_if_reset_needed_methd() or ! _GET_VALUE_ ) {
	  _BEHAVIOR_{reset}
	}
	_QUANTITY_CLASS_->readable_value( _GET_VALUE_ )
      },
    },
  }
}

########################################################################

=head1 DATABASE-ORIENTED FIELDS

=head2 Field Type unique_code

Used to generate and store a unique code for this object.

The identifiers generally look like 'QX3P6N' or the like -- a mix of the digits from 0 to 9 and upper case consonants (skipping the vowels to avoid confusion between 0/O and 1/I, and to avoid constructing real words). The size is controlled by the "length" meta-method attribute.

Here's a sample declaration:

  package Acme::Order::Order;
  use DBIx::DBO2::Fields ( 
      "unique_code --length 6 => 'public_id',
  );

This field is automatically assigned and confirmed to be unique when the record is inserted.

Here's how you retrieve a specific row:

  my $pubid = 'QX3P6N';
  $order = Acme::Order::Order->fetch_public_id( $pubid );

With 41 possible characters, a length of 3 gives 68,921 choices, 4 gives 2,825,761, 6 gives 4,750,104,241, and 8 gives 7,984,925,229,121.

=cut

sub unique_code {
  {
    '-import' => { '::DBIx::DBO2::Fields:string' => '*' },
    'params' => {
      length => 6,
      chars => [ grep { 'AEIOU' !~ /$_/ } ( 'A'..'Z') ],
      # chars => [ (0 .. 9), grep { 'AEIOU' !~ /$_/ } ( 'A'..'Z') ],
      hook => { pre_insert=>'assign_*' }
    },
    'interface' => {
      default	    => { '*'=>'get', 'assign_*'=>'assign', 
			  'generate_*'=>'generate', 'fetch_*'=>'fetch' },
    },
    'behavior' => {
      assign => q{
	my $generator = 'generate_' . _STATIC_ATTR_{name};
	my $fetcher = 'fetch_' . _STATIC_ATTR_{name};
	do {
	  _SET_VALUE_{ $self->$generator() };
        } while ( scalar @{ 
	  $self->table->fetch({ _STATIC_ATTR_{hash_key} => _GET_VALUE_ }) 
	} );
      },
      generate => q{
	my $char = _STATIC_ATTR_{chars};
	my $dated = _STATIC_ATTR_{dated} || 0;
	my $code;
	do { 
	  $code = '';
	  if ( $dated ) {
	    require Time::JulianDay;
	    my $today = Time::JulianDay::local_julian_day(time);
	    my $incr = $today - $dated;
	    my $charcnt = scalar(@$char);
	    while ( $incr > 0 ) {
	      use integer;
	      my $diff = $incr % $charcnt;
	      $incr = int( $incr / $charcnt );
	      $code = $char->[ $diff ] . $code;
	    }
	    if ( my $length = length($code) and length($code) < 3 ) {
	      $code = ( $char->[0] x ( 3 - $length ) ) . $code;
	    }
	    if ( length($code) ) {
	      $code .= '-';
	    }
	  }
	  foreach  (1 .. _STATIC_ATTR_{length} ) {
	    $code .= $char->[ rand( scalar(@$char) ) ];
	  }
	  # Don't generate all-numeric codes
	} until ( $code !~ /^\\d+$/i );
	return $code;
      },
      fetch => q{
	my $value = shift() 
	  or return;
	$self->fetch_one({ _STATIC_ATTR_{hash_key} => $value });
      },
    },
  }
}

########################################################################

sub subclass_name {
  {
    '-import' => { 
      '::DBIx::DBO2::Fields:string' => '*' 
    },
    'interface' => {
      default => { '*'=>'get_set', '*_pack' => 'pack', '*_unpack' => 'unpack' },
    },
    'params' => {
      hook => { post_fetch=>'*_unpack', post_new=>'*_pack', pre_insert=>'*_pack', pre_update=>'*_pack' }
    },
    'behavior' => {
      'get' => q{ 
	  my $type = _GET_VALUE_;
	  defined( $type ) ?  $type : '';
	},
      'set' => q{ 
	  my $type = shift;
	  my $subclass = Class::MakeMethods::Template::ClassName::_unpack_subclass( 
				_ATTR_{target_class}, $type );
	  my $class = Class::MakeMethods::Template::ClassName::_provide_class( 
	      _ATTR_{target_class}, $subclass );
	  
	  if ( ref _SELF_ ) {
	    _SET_VALUE_{ $type };
	    bless $self, $class;
	  }
	  return $class;
	},
      'pack' => q{ 
	  my $type = _GET_VALUE_;
	  _SET_VALUE_{ $type };
	},
      'unpack' => q{ 
	  my $type = _GET_VALUE_;
	  my $subclass = Class::MakeMethods::Template::ClassName::_unpack_subclass( 
				_ATTR_{target_class}, $type );
	  my $class = Class::MakeMethods::Template::ClassName::_provide_class( 
	      _ATTR_{target_class}, $subclass );
	  
	  if ( ref _SELF_ ) {
	    bless $self, $class;
	  }
	  return $class;
	},
    },
  }
}

########################################################################

=head2 Field Type foreign_key

Generates methods corresponding to a SQL int or varchar column storing a value which corresponds to the primary key of a related record from another table.

=head3 Default Interface

The general usage for a foreign_key field is:

  use DBIx::DBO2::Fields (
    foreign_key => 'x',
  );

This declaration will generate methods to support the following interface:

=over 4

=item *

I<$record>-E<gt>x_id() : I<value>

Returns the raw numeric value of field x_id for the given record.

=item *

I<$record>-E<gt>x_id( I<value> ) 

Sets the raw numeric value of field x_id for the given record.

=item *

I<$record>-E<gt>x() : I<related_object>

Fetches and returns the related record. 

If the x_id value is empty, or if there is not a record with the corresponding value in the related table, returns undef.

=item *

I<$record>-E<gt>x( I<related_object> ) 

Sets the raw numeric value of field x_id based on the corresponding field in the related object.

=item *

I<$record>-E<gt>x_required() : I<related_object>

Fetches and returns the related record, in a case where your code depends on it existing, generally because it calls additional methods without checking the result. 

If the x_id value is empty, or if there is not a record with the corresponding value in the related table, croaks with a fatal exception. This makes it easier to spot the problem then Perl's generic "can't call method on undefined value" message.

=item *

I<$record>-E<gt>x_invalid() : I<fieldname> => I<error_message>, ...

If the field is marked required (or the underlying column is defined as not null), reports an error for missing values. 

If a value is provided, attempts to fetch the associated record and reports an error if can not be found.

=back

=head3 Attributes

=over 4

=item *

hash_key - defaults to *_id

=item *

related_class

=item *

related_id_method

=back

=head3 Example

  package EBiz::Order::Order;
  use DBIx::DBO2::Fields ( 
      foreign_key => { name=>'account',  related_class => 'Account' },
  );
  ...
  $order->account_id( 27 );
  print $order->required_account->email();

=cut

sub foreign_key {
  {
    '-import' => { '::DBIx::DBO2::Fields:generic' => '*' },
    'params' => {
      'hash_key' => '*_id',
      'related_class' => undef,
      'related_id_method' => 'id',
      'column_type' => 'int',
      'column_autodetect' => [ 'required', 0, ],
    },
    'interface' => {
      default	    => { '*_id'=>'id', '*'=>'obj', 
			'required_*'=>'req_obj', '*_invalid' => 'invalid' },
    },
    'code_expr' => {
      '_FIND_R_CLASS_' => q{
	  my $related = _ATTR_REQUIRED_{related_class};
	},
    },
    'behavior' => {
      'id' => q{ 
	  if ( scalar @_ ) {
	    _SET_VALUE_{ shift() }
	  } else {
	    _GET_VALUE_
	  }
	},
      'req_obj' => q{
	  _FIND_R_CLASS_
	    my $value = _GET_VALUE_
	      or croak "No _STATIC_ATTR_{name} foreign key ID for " . ref($self) . " ID '$self->{id}'";
	    my $id_method = _ATTR_REQUIRED_{related_id_method};
	    if ( $id_method eq 'id' ) {
	      $related->fetch_id( $value )
		or croak "Couldn't find related _STATIC_ATTR_{name} record based on $id_method '$value'";
	    } else {
	    $related->fetch_one({ $id_method => $value })
	      or croak "Couldn't find related _STATIC_ATTR_{name} record based on $id_method '$value'";
	    }
	},
      'obj' => q{ 
	  _FIND_R_CLASS_
	  
	  if ( scalar @_ ) {
	    my $obj = shift();
	    UNIVERSAL::isa($obj, $related ) 
		or Carp::croak "Inappropriate object type!";
	    my $id_method = _ATTR_REQUIRED_{related_id_method};
	    my $id = $obj->$id_method()
		or Carp::croak "Can't store reference to unsaved record";
	    _SET_VALUE_{ $id }
	  } else {
	    my $value = _GET_VALUE_
	      or return undef;
	    my $id_method = _ATTR_REQUIRED_{related_id_method};
	    if ( $id_method eq 'id' ) {
	      $related->fetch_id( $value );
	    } else {
	      $related->fetch_one({ $id_method => $value });
	    }
	  }
	},
      'invalid' => q{ 
	  _BEHAVIOR_{detect_column_attributes}
	  for ( _GET_VALUE_ ) {
	    if ( _ATTR_{required} and ! length( $_ ) ) {
	      return _ATTR_{name} => " is required."
	    }
	    if ( length( $_ ) ) {
	      _FIND_R_CLASS_
	      $related->fetch_id( $_ ) or
		      return _ATTR_{name} => " is invalid."
	    }
	  }
	},
      '-subs' => sub {
	  my $m_info = shift();
	  my $name = $m_info->{'name'};
	  
	  my $forward = $m_info->{'delegate'}; 
	  my @forward = ! defined $forward ? ()
					: ref($forward) eq 'ARRAY' ? @$forward 
						  : split ' ', $forward;
	  
	  my $access = $m_info->{'accessors'}; 
	  my @access = ! defined $access ? ()
					: ref($access) eq 'ARRAY' ? @$access 
						    : split ' ', $access;
	  
	  map({ 
	    my $fwd = $_; 
	    $fwd, sub { 
	      my $obj = (shift)->$name() 
		or Carp::croak("Can't forward $fwd because $name is empty");
	      $obj->$fwd(@_) 
	    } 
	  } @forward ),
	  map({ 
	    my $acc = $_; 
	    "$name\_$acc", sub { 
	      my $obj = (shift)->$name() 
		or return;
	      $obj->$acc(@_) 
	    }
	  } @access ),
	},
    },
  }
}

########################################################################

=head2 Field Type line_items

Generates methods to retrieve records from another table which have a foreign_key relationship to the current record. Depends on there being a primary key column, but does not require a separate database column of its own.

=head3 Default Interface

The general usage for a line_items field is:

  package Y;
  use DBIx::DBO2::Fields (
    line_items => { name=>'x', 'related_field'=>'y_id', related_class=>'X' },
  );

This declaration will generate methods to support the following interface:

=over 4

=item *

I<$record>-E<gt>x() : I<related_objects>

Fetches the related records. Returns a RecordSet.

=item *

I<$record>-E<gt>x( I<rel_col> => I<rel_value>, ...) : I<related_objects>

Fetches a subset of the related records which also meet the indicated criteria. Returns a RecordSet.

=item *

I<$record>-E<gt>count_x() 

Returns the number or related records.

=item *

I<$record>-E<gt>new_x() : I<related_object>

Creates and returns a new related record, setting its foreign key field to refer to our record's ID. 

(Note that the record is created but not inserted; you need to call -E<gt>save() yourself.)

=item *

I<$record>-E<gt>delete_x()

Deletes B<all> of the related records. 

=back

You can also specify an array-ref value for the default_criteria attribute; if present, it is treated as a list of fieldname/value pairs to be passed to the fetch and new methods of the related class.

=cut

sub line_items {
  {
    '-import' => {  'Template::Generic:generic' => '*' },
    'params' => {
      'id_method' => 'id',
      'related_class' => undef,
      'related_field' => undef,
      'default_criteria' => undef,
    },
    'interface' => {
      default	    => { '*'=>'fetch', 'count_*'=>'count', 'new_*'=>'new', 'delete_*'=>'delete' },
    },
    'code_expr' => {
      '_FIND_R_CLASS_' => q{
	  my $related = _ATTR_REQUIRED_{related_class};
	},
    },
    'behavior' => {
      'fetch' => q{
	  _FIND_R_CLASS_
	  
	  my $r_field = _ATTR_REQUIRED_{related_field};
	  my $id_method = _ATTR_REQUIRED_{id_method};
	  my $d_crit = _ATTR_{default_criteria};
	  my $id = $self->$id_method()
		or return DBIx::DBO2::RecordSet->new();
	  my $criteria = 
	      ( ref($d_crit) eq 'ARRAY' ) ? { $r_field=>$id, @$d_crit, @_ } :
	      ( ref($d_crit) ) ? DBO::Criteria::And->new_with_contents( 		    DBO::Criteria::StringEquality->new_kv( $r_field,$id ), $d_crit, @_ ) 
				      : { $r_field=>$id, @_ };
	  $related->fetch_select($criteria);
	},
      'count' => q{
	  # my $fetch_method = _STATIC_ATTR_{name};
	  # $self->$fetch_method()->count;
	  
	  _FIND_R_CLASS_
	  
	  my $r_field = _ATTR_REQUIRED_{related_field};
	  my $id_method = _ATTR_REQUIRED_{id_method};
	  my $d_crit = _ATTR_{default_criteria};
	  my $id = $self->$id_method()
		or return DBIx::DBO2::RecordSet->new();
	  # warn "Counting from " . $related->table->name;
	  my $criteria = ref($d_crit) eq 'ARRAY' ? { $r_field=>$id, @$d_crit, @_ }
						 : ref($d_crit) ? DBO::Criteria::And->new_with_contents( 		    DBO::Criteria::StringEquality->new_kv( $r_field,$id ), $d_crit, @_ ) 
				      : { $r_field=>$id, @_ };
	  $related->table->count_rows($criteria);
 	},
      'delete' => q{
	  my $fetch_method = _STATIC_ATTR_{name};
	  foreach my $item ( $self->$fetch_method(@_)->records ) {
	    $item->delete();
	  }
 	},
      'new' => q{
	  _FIND_R_CLASS_
	  
	  my $r_field = _ATTR_REQUIRED_{related_field};
	  my $id_method = _ATTR_REQUIRED_{id_method};
	  my $d_crit = _ATTR_{default_criteria};
	  $related->new( $r_field=>$self->$id_method(), ((ref($d_crit) eq 'ARRAY' ) ? @$d_crit : ()), @_ );
	},
    },
  }
}

########################################################################

=head1 CODE-ORIENTED FIELDS

The below types are for internal use and do not correspond to SQL columns.

=head2 Field Type alias

  use DBIx::DBO2::Fields (
    alias => [ 'x' => 'y' ],
  );

This declares a method -E<gt>x() that simply calls method -E<gt>y() and passes along all of its arguments.

=cut

sub alias {
  my ($class, @args) = @_;
  my %methods;
  while (@args) {
    my $alias = shift @args;
    my $base = shift @args;
    $methods{ $alias } = sub { (shift)->$base( @_ ) };
  }
  $class->install_methods(%methods);
}

########################################################################

=head2 Field Type forward

Local alias for the Universal:forward_methods method generator.

Creates a method which delegates to an object provided by another method. 

Example:

  use DBIx::DBO2::Fields
    forward => [ 
	[ 'w' ], { target=> 'whistle' }, 
	[ 'x', 'y' ], { target=> 'xylophone' }, 
	{ name=>'z', target=>'zither', target_args=>[123], method_name=>do_zed },
      ];

Example: The above defines that method C<w> will be handled by the
calling C<w> on the object returned by C<whistle>, whilst methods C<x>
and C<y> will be handled by xylophone, and method C<z> will be handled
by calling C<do_zed> on the object returned by calling C<zither(123)>.

B<Attributes>: The following additional attributes are supported:

=over 4

=item target

I<Required>. The name of the method that will provide the object that will handle the operation.

=item target_args

Optional ref to an array of arguments to be passed to the target method.

=item method_name

The name of the method to call on the handling object. Defaults to the name of the meta-method being created.

=back

=cut

sub forward { 'Universal:forward_methods' }

########################################################################

=head1 TO DO

=over 4 

=item *

Resolve differing approaches to setting values from human-entered formatted values. Current interface is:

=over 4 

=item - 

julian_day: I<$record>-E<gt>x( I<readable_value> ) 

=item - 

timestamp: I<$record>-E<gt>x( I<readable_value> ) 

=item - 

currency_uspennies: I<$record>-E<gt>x_readable(I<readable_value>) 

=item - 

creditcardnumber: I<$record>-E<gt>x_readable(I<readable_value>) 

=back

=back

=head1 CHANGES

2002-01-17 Simon: Update of Fields to use new version of Class::MakeMethods.

2001-04-09 Simon: Added line_items attrib: default_criteria=>[field=>value,...]

2001-02-07 Simon: Completed fields() method, and improved column attr detection.

2001-01-30 Simon: Added _readable method for all number fields (for ',000's).

2001-01-29 Simon: Filled in missing chunks of documentation.

2001-01-29 Simon: Added *_invalid methods and column-info detection. 

2001-01-20 Simon: Added saved_total_uspennies

2001-01-16 Simon: Added saved_total

2000-12    Simon: Added currency_uspennies, timestamp, and julian_day types

2000-12    Simon: Added foreign_key and line_items types

2000-08-04 Simon: Moved package into EBiz::Database. 

2000-03-30 Simon: Julian day readable now calls method to access value.

2000-03-10 Simon: Added get_and_set, get_set_filter.

2000-03-06 Simon: Added get_set_alias

2000-02-29 Simon: Created.


=head1 COPYRIGHT

Copyright 2000, 2001 Evolution Online Systems, Inc.

You may use, modify, and distribute this software under the same terms as Perl.

=cut

1;
