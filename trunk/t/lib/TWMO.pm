package TWMO;

use strict;
use warnings;

my @pies = qw(cherry apple blueberry);

sub new {
  bless {} => shift;
}

sub uri_base { 'http://localhost.localdomain' }

sub request {
  my ($self, $request) = @_;
  my $query = { $request->uri->query_form };

  if ($query->{pie} && $query->{pie} eq 'random') {
    my $response = HTTP::Response->new(302);
    my $location = $request->uri->clone;
    $location->query_form(pie => $pies[rand @pies]);
    $response->header( Location => $location );
    return $response;
  } 

  my $response = HTTP::Response->new(200);
  my $uri = $request->uri->canonical;
  $response->content(
    sprintf(
      <<"END",
Your host is %s.
You got to %s.
You asked for a %s pie.
END
      $uri->host,
      ($uri->path eq '/' ? "nowhere" : $uri->path),
      $query->{pie} || "void",
    )
  );
  if (($request->uri->path_segments)[1] and
        ($request->uri->path_segments)[1] eq 'cookie') {
    $response->header(
      'Set-Cookie' => 'cookie=yummy; domain=' . $uri->host . "; path=/"
    );
  }

  return $response;
}

package TWMO::Remote;

use URI;
our @ISA = qw(TWMO);
my $DEFAULT = URI->new("http://localhost.localdomain")->canonical;

sub uri_base { $ENV{TWMO_SERVER} || "http://localhost.localdomain" }

sub prepare_request {
  my ($self, $request) = @_;
  my $uri = $request->uri;
  my $twmo = URI->new($ENV{TWMO_SERVER} || return);

  if ($uri->scheme eq $DEFAULT->scheme and
        $uri->host eq $DEFAULT->host) {
    $uri->scheme($twmo->scheme);
    $uri->host($twmo->host);
    my $path = $twmo->path . '/' . $uri->path;
    $path =~ s{/+}{/}g;
    $uri->path($path);

    $request->uri($uri->canonical);
  }
#  main::diag($request->uri);
}

sub before_request {
  my ($self, $request) = @_;
  my $uri = $request->uri;
  my $twmo = URI->new($ENV{TWMO_SERVER} || return);

  if ($uri->scheme eq $twmo->scheme and
        $uri->host eq $twmo->host and
          $uri->path =~ /^\Q@{[ $twmo->path ]}\E/) {
    $uri->scheme($DEFAULT->scheme);
    $uri->host($DEFAULT->host);
    my $path = $uri->path;
    $path =~ s,^\Q@{[ $twmo->path ]}\E/*,,;
    $uri->path($path);
    $request->uri($uri->canonical);
  }
#  main::diag($request->uri);
}

sub request {
  my ($self, $request) = @_;
  my $response = $self->SUPER::request($request);

  # this is redundant in some ways
  $self->prepare_request($request);
  
  my $twmo = URI->new($ENV{TWMO_SERVER} || return $response);

  for my $header (qw(Set-Cookie Set-Cookie2 Set-Cookie3 Location)) {
    my @values = $response->header($header);
    $response->header($header => [ map {
      #warn "$header: was: $_\n";
      # the extra slash is necessary because $DEFAULT will
      # often (always?) end with a slash, while the
      # environment variable may not.
      s{$DEFAULT}{$twmo/};
      if (/\bdomain=\Q@{[ $DEFAULT->host ]}\E([;\s]|$)/ and
            /\bpath=\Q@{[ $DEFAULT->path ]}\E([;\s]|$)/) {
        s{\bdomain=\Q@{[ $DEFAULT->host ]}\E([;\s]|$)}
          {domain=@{[ $twmo->host ]}$1};
        s{\bpath=\Q@{[ $DEFAULT->path ]}\E([;\s]|$)}
          {path=@{[ $twmo->path ]}$1};
      }
      #warn "$header: now: $_\n";
      $_
    } @values ]);
  }
  
  return $response;
}

1;
