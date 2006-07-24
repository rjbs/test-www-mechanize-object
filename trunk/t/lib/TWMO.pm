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

sub uri_base { $ENV{TWMO_SERVER} || shift->SUPER::uri_base }

sub __munge_uri {
  my ($uri, $old, $new) = @_;
  my $clone = $uri->clone;
  #warn "starting to convert $old to $new in $uri\n";
  for my $part (qw(host scheme)) {
    return unless $clone->$part eq $old->$part;
  }
  my %path = (
    clone => [ grep { length } $clone->path_segments ],
    old   => [ grep { length } $old->path_segments ],
  );
  while (@{$path{clone}} and @{$path{old}}
           and $path{clone}->[0] eq $path{old}->[0]
         ) {
    #warn "'$path{clone}[0]' matches '$path{old}[0]'\n";
    shift @{$path{$_}} for qw(clone old);
  }
  if (@{$path{old}}) {
    # unmatched path parts remaining
    #warn "unmatched path parts: '@{$path{old}}'\n";
    return;
  }
  for my $part (qw(host scheme)) {
    $clone->$part($new->$part);
  }
  my $path = join "/", $new->path_segments, @{$path{clone}};
  $path =~ s{/+}{/}g;
  $clone->path($path);
  #warn "converted $uri to $clone\n";
  return $clone->canonical;
}

sub __munge_request_uri {
  my $req = shift;
  my $clone = __munge_uri( $req->uri, @_ ) || return;
  $req->uri($clone);
}

sub before_request {
  my ($self, $request) = @_;
  my $twmo = URI->new($ENV{TWMO_SERVER} || return);
  __munge_request_uri($request, $twmo, $DEFAULT);
}

sub after_request {
  my ($self, $request, $response) = @_;
  
  my $twmo = URI->new($ENV{TWMO_SERVER} || return);
  __munge_request_uri($request, $DEFAULT, $twmo);

  for my $header (qw(Set-Cookie Set-Cookie2 Set-Cookie3)) {
    my @values = $response->header($header);
    $response->header($header => [ map {
      #warn "$header: was: $_\n";
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
}

sub on_redirect {
  my ($self, $request, $response) = @_;
  my $twmo = URI->new($ENV{TWMO_SERVER} || return);
  my $clone = __munge_uri(
    URI->new($response->header('Location')),
    $DEFAULT, $twmo
  ) || return;
  $response->header(Location => $clone);
}

1;
