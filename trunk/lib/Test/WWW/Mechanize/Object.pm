package Test::WWW::Mechanize::Object;

use v5.6.1;
use Carp ();
use warnings;
use strict;

=head1 NAME

Test::WWW::Mechanize::Object - run mech tests by making
requests on an object

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

  use Test::WWW::Mechanize::Object;
  my $mech = Test::WWW::Mechanize::Object->new(handler => $obj);
  # use $mech as usual

=head1 DESCRIPTION

Test::WWW::Mechanize::Object exists to make it easier to run
tests with unusual request semantics.

Instead of having to guess at which parts of the
LWP::UserAgent and WWW::Mechanize code needs to be
overridden, any object that implements a (relatively) simple
API can be passed in.

All methods from Test::WWW::Mechanize.  The only change is
the addition of the 'handler' parameter to the C<< new >>
method.

=head1 METHODS

=head2 request

  $obj->request($request);

This method receives a L<HTTP::Request|HTTP::Request> as its
only argument.  It should return a
L<HTTP::Response|HTTP::Response> object.  It should not
follow redirects; LWP will take care of that.

This is the only method that handler objects B<must>
implement.

=head2 prepare_request

  $obj->prepare_request($request);

Called before LWP and Mech do all their request object
preparation.

Note: this method will be called once per request in a redirect
chain.

=head2 before_request

  $obj->before_request($request);

Called after LWP and Mech do their request object
preparation, but before C<< $obj->request >> is called.

Note: this method will be called once per request in a redirect
chain.

=head2 after_request

  $obj->after_request($request, $response);

Called after the object has returned its response and LWP
and Mech have done any post-processing.

Note: this method will be called once per request in a redirect
chain.

=head2 on_redirect

  $obj->on_redirect($request, $response);

Called after C<after_request> each time the object returns a response that is a
redirect (3XX status code). 

=head1 INTERNALS

You don't need to read this section unless you are
interested in finding out how this module works, for
subclassing or debugging.  Most users will only need to read
the method documentation above.

=head2 new

Overridden to note the 'handler' parameter.

=cut

sub new {
  my ($class, %arg) = @_;
  my $handler = delete $arg{handler}
    or Carp::croak("the 'handler' argument is required for $class->new()");
  my $self = $class->SUPER::new(%arg);
  $self->{handler} = $handler;
  return $self;
}

sub __hook {
  my ($self, $hookname, $args) = @_;
  return unless my $meth = $self->{handler}->can($hookname);
  $self->{handler}->$meth(@$args);
}

=head2 _make_request

Overridden (from WWW::Mechanize) to call the C<prepare_request> hook.

=cut

sub _make_request {
  my ($self, $request, @rest) = @_;
  $self->__hook(prepare_request => [ $request ]);
  $self->SUPER::_make_request($request, @rest);
}

=head2 send_request 

Overridden (from LWP::UserAgent) to send requests to the
handler object and to call the C<before_request> hook.

Note: This ignores the C<$arg> and C<$size> arguments that
LWP::UserAgent uses.

=cut

sub send_request {
  my ($self, $request, $arg, $size) = @_;
  $self->__hook(before_request => [ $request ]);
  my $response = $self->{handler}->request($request);
  $response->request($request);
  $self->cookie_jar->extract_cookies($response) if $self->cookie_jar;
  
  $self->__hook(after_request => [ $request, $response ]);

  if ($response->is_redirect) {
    $self->__hook(on_redirect => [ $request, $response ]);
  }

  return $response;
}

=head1 SEE ALSO

L<Test::WWW::Mechanize|Test::WWW::Mechanize>
L<HTTP::Request|HTTP::Request>
L<HTTP::Response|HTTP::Response>

=head1 AUTHOR

Hans Dieter Pearcey, C<< <hdp at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-test-www-mechanize-object at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Test-WWW-Mechanize-Object>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Test::WWW::Mechanize::Object

You can also look for information at:

=over 4

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Test-WWW-Mechanize-Object>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Test-WWW-Mechanize-Object>

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Test-WWW-Mechanize-Object>

=item * Search CPAN

L<http://search.cpan.org/dist/Test-WWW-Mechanize-Object>

=back

=head1 ACKNOWLEDGEMENTS

=head1 COPYRIGHT & LICENSE

Copyright 2006 Hans Dieter Pearcey, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of Test::WWW::Mechanize::Object
