#C:\Perl\bin\perl.exe
#fantasy.pl

use warnings;
use HTTP::Status;
use HTTP::Response;
use LWP::UserAgent;
use URI::URL;
use LWP::UserAgent;
use HTML::Parse;
use Win32::OLE;
use Cwd;

sub current_scoreboard {
    my $now           = time;
    my $yesterday     = $now - 86400;
    my $daybefore     = $yesterday - 86400;
    my $now_url       = get_scoreboard($now);
    my $yesterday_url = get_scoreboard($yesterday);
    my $daybefore_url = get_scoreboard($daybefore);

    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime $now;

    if ( $wday == 6 || $wday == 7 ) {
        if ( $hour < 12 ) { return $now_url; }
    }

    elsif ( $hour < 17 ) {
        return $yesterday_url;
    }

    return $now_url;
}

sub get_scoreboard {
    my $t = shift(@_);
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      localtime $t;
    $year = $year + 1900;
    $mon  = $mon + 1;
    if ( $mday < 10 ) { $mday = "0" . $mday; }

    my $scoreboard =
      "http://sports.yahoo.com/nba/scoreboard?d=$year-$mon-$mday";
    return $scoreboard;
}

sub unchomp {
    my $ref = shift;
    for $element ( @{$ref} ) {
        $element .= "<BR>";
        $element .= "\n";
    }
}

sub get_games($$) {
    my ( $url, $prefix ) = @_;

    my $ua = LWP::UserAgent->new( agent => $ENV{SCRIPT_NAME} );
    my $r = HTTP::Request->new( 'GET', $url );
    my $response = $ua->request($r);

    unless ( $response->is_success ) {
        print $response->error_as_HTML . "\n";
        print "Could not connect to server trying to get games\n";
        exit(1);
    }

    my $Result = $response->content();    # content without HTTP header
    my @games;
    my $parsed_html = HTML::Parse::parse_html($Result);
    for ( @{ $parsed_html->extract_links(qw (a)) } ) {
        my ($link) = @$_;
        if ( $link =~ /boxscore\?gid=(\d+)/ ) {
            my $temp = $prefix . $1;
            push( @games, $temp );
        }
    }
    $parsed_html->delete();               # manually do garbage collection

    my %occured;
    foreach my $game_today (@games) {
        $occured{$game_today} = 1;
    }

    my @unique = keys %occured;

    return @unique;
}

sub get_content($) {
    my ($url) = @_;
    my $ua = LWP::UserAgent->new( agent => $ENV{SCRIPT_NAME} );
    my $r = HTTP::Request->new( 'GET', $url );
    my $response = $ua->request($r);

    unless ( $response->is_success ) {
        print $response->error_as_HTML . "\n";
        print "Could not connect to server trying to get content\n";
        exit(1);
    }

    my $Result = $response->content();    # content without HTTP header
    my @arr = split( /\n/, $Result );
    return @arr;
}

sub clean_html(@) {
    print "Cleaning up stat.\n";
}

my $url = current_scoreboard();
print "\nCurrent scoreboard is at $url\n\n";
my $prefix = "http://sports.yahoo.com/nba/boxscore?gid=";
my @stats;
open( INPUT, "files/template.html" ) or die $!;
my @html;
@html = <INPUT>;
open( PLAYERS, "players.txt" ) or die $!;
my @players = <PLAYERS>;
close(PLAYERS);
chomp(@players);

my $count = 0;
my @totals;
$totals[0] = 0;
my @games = get_games( $url, $prefix );

foreach $game (@games) {
    my @body = get_content($game);
    my $stat;

    foreach $player (@players) {
        $count = 0;
        my $game_time = "";

        #print "Checking for $player in $game\n";
        foreach $line (@body) {

            if ( $line =~ /td align.*$player<\/a.*td/ ) {

                #PLAYER WAS FOUND
                print "Player $player was found in $game \@ line $count\n";
                $line =~ s/\/nba\/players\/\d+/$game/;

                my $player_game = $player . " ->> " . $game_time;
                $line =~ s/$player/$player_game/;

                my $injured = 13;

                #if injured (AKA did not play), there's no need to get 13 lines
                if ( $body[ $count + 4 ] !~ /<td.*/ ) {
                    $injured = 4;
                }
                else {
                    $body[ $count + 12 ] =~ /(\d+).nbsp/;
                    my $pts = $1;
                    print "$player scored $pts.\n";
                    $totals[0] = $totals[0] + $pts;
                }

                for ( $i = ( $count - 1 ) ; $i <= ( $count + $injured ) ; $i++ )
                {

                    #print "$body[$i]\n";
                    $stat = $body[$i] . "\n";
                    push( @stats, $stat );
                }
            }
            $count++;

            if ( $line =~ /ysptblclbg6.*yspscores">(.+)<\/span/ ) {

                #print "Time left is $1\n";
                $game_time = $game_time . " " . $1;

            }
        }
    }
}
print "Okay we're finally done. Writing to file.\n";
print "Total points: $totals[0]\n";

clean_html(@stats);

#unchomp(\@players);

splice( @html, 208, 0, $totals[0] );

splice( @html, 200, 0, @stats );
open( STATS, "> files/stats.html" ) or die $!;
print STATS @html;
close STATS;

$IE = Win32::OLE->new("InternetExplorer.Application")
  || die "Could not start Internet Explorer.Application\n";
$IE->{visible} = 1;
$IE->Navigate( cwd . "/files/stats.html" );

exit;

