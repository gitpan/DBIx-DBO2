use ExtUtils::MakeMaker;
WriteMakefile(
    'NAME'		=> 'DBIx::DBO2',
    'VERSION_FROM'	=> 'DBO2.pm', 
    'PREREQ_PM'		=> {
	DBIx::SQLEngine	   => 0.005, # for new Criteria methods
	Class::MakeMethods => 1.001, # for Composite::Inheritable:hook
    }, 
    ($] >= 5.005 ? (
      ABSTRACT_FROM => 'DBO2.pm', 
      AUTHOR     => 'Matthew Simon Cavalletto <simonm@cavalletto.org>',
    ) : ()),
);
sub MY::postamble { q{

docs : README CHANGES TODO

README: DBO2/ReadMe.pod
	pod2text DBO2/ReadMe.pod > README

CHANGES: DBO2/Changes.pod
	pod2text DBO2/Changes.pod > CHANGES

TODO: DBO2/ToDo.pod
	pod2text DBO2/ToDo.pod > TODO

cleanmanifest:
	rm MANIFEST ; touch MANIFEST; make manifest

}; }
