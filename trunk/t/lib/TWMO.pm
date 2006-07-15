package TWMO;

use strict;
use warnings;

my @pies = qw(cherry apple blueberry);

sub new {
  bless {} => shift;
}

sub request {
  my ($self, $request) = @_;
  my $query = { $request->uri->query_form };

  if ($query->{pie} && $query->{pie} eq 'random') {
    my $response = HTTP::Response->new(302);
    $response->header(
      Location => 'http://localhost' .
        ($request->uri->path || '/') .
          '?pie=' . $pies[rand @pies]
        );
    return $response;
  } 

  my $response = HTTP::Response->new(200);
  $response->content(
    sprintf <<"END",
You got to %s.
You asked for a %s pie.
END
    $request->uri->path || "nowhere",
    $query->{pie} || "void",
  );
  return $response;
}

package TWMO::Rebasing;


1;
