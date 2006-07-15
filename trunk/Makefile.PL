use strict;
use warnings;
use inc::Module::Install;

name 'Test-WWW-Mechanize-Object';
author 'Hans Dieter Pearcey <hdp@cpan.org>';
all_from;

build_requires 'Test::More' => 0;
build_requires 'Test::MockObject' => 0;

WriteAll;
