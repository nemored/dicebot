#!/usr/bin/env perl
use strict;
use warnings;

use Getopt::Long qw(GetOptions);
use AnyEvent;
use AnyEvent::IRC::Client;

my $config_file = 'config/dicebot.conf.pl';
GetOptions('config=s' => \$config_file) or die "Usage: $0 [--config path/to/config.pl]\n";

my $config = do $config_file;
die "Failed to load config '$config_file': $@\n" if $@;
die "Failed to load config '$config_file': $!\n" if !defined $config;
die "Config in '$config_file' must return a hash reference\n" if ref($config) ne 'HASH';

for my $required (qw(server port nick channels)) {
    die "Missing required config key: $required\n" if !exists $config->{$required};
}

die "Config key 'channels' must be an array reference\n" if ref($config->{channels}) ne 'ARRAY';

my $trigger       = defined $config->{trigger}       ? $config->{trigger}       : '!roll';
my $max_dice      = defined $config->{max_dice}      ? $config->{max_dice}      : 20;
my $max_sides     = defined $config->{max_sides}     ? $config->{max_sides}     : 1000;
my $max_abs_bonus = defined $config->{max_abs_bonus} ? $config->{max_abs_bonus} : 1000;
my $password      = $config->{password};
my $tls           = $config->{tls} ? 1 : 0;

my $irc = AnyEvent::IRC::Client->new;
my $cv  = AnyEvent->condvar;

$irc->reg_cb(
    registered => sub {
        my ($con) = @_;
        for my $channel (@{$config->{channels}}) {
            $con->send_srv(JOIN => $channel);
        }
    },
    disconnect => sub {
        warn "Disconnected from IRC server\n";
        $cv->send;
    },
    error => sub {
        my (undef, $message) = @_;
        warn "IRC error: $message\n";
    },
    publicmsg => sub {
        my (undef, $channel, $ircmsg) = @_;
        my $text = $ircmsg->{params}[1] // '';

        return if index($text, $trigger) != 0;

        my $expression = substr($text, length($trigger));
        $expression =~ s/^\s+|\s+$//g;
        $expression = '1d20' if $expression eq '';

        my $result = evaluate_roll($expression, {
            max_dice      => $max_dice,
            max_sides     => $max_sides,
            max_abs_bonus => $max_abs_bonus,
        });

        my $nick = (split /!/, $ircmsg->{prefix}, 2)[0] // 'someone';
        my $reply = defined $result->{error}
            ? "$nick: $result->{error}"
            : "$nick: $result->{summary} = $result->{total}";

        $irc->send_chan($channel, 'PRIVMSG', $channel, $reply);
    },
);

my %connect_info = (
    nick     => $config->{nick},
    user     => $config->{username} // $config->{nick},
    real     => $config->{realname} // 'Perl Dice Bot',
    password => $password,
);

$connect_info{tls} = 'connect' if $tls;

$irc->connect(
    $config->{server},
    $config->{port},
    \%connect_info,
);

$cv->recv;

sub evaluate_roll {
    my ($expression, $limits) = @_;

    if ($expression !~ /^\s*(\d*)d(\d+)(?:\s*([+-])\s*(\d+))?\s*$/i) {
        return { error => "Invalid roll. Use NdS[+/-B], for example: 3d6+2" };
    }

    my $dice  = $1 eq '' ? 1 : int($1);
    my $sides = int($2);
    my $sign  = $3 // '+';
    my $bonus = defined($4) ? int($4) : 0;

    return { error => 'Number of dice must be at least 1' } if $dice < 1;
    return { error => 'Number of sides must be at least 2' } if $sides < 2;
    return { error => "Too many dice (max $limits->{max_dice})" } if $dice > $limits->{max_dice};
    return { error => "Too many sides (max $limits->{max_sides})" } if $sides > $limits->{max_sides};
    return { error => "Bonus too large in magnitude (max $limits->{max_abs_bonus})" }
        if $bonus > $limits->{max_abs_bonus};

    $bonus *= -1 if $sign eq '-';

    my @rolls;
    my $total = 0;
    for (1 .. $dice) {
        my $roll = int(rand($sides)) + 1;
        push @rolls, $roll;
        $total += $roll;
    }

    my $summary = join(' + ', @rolls);
    if ($bonus != 0) {
        my $op = $bonus > 0 ? '+' : '-';
        $summary .= sprintf(' %s %d', $op, abs($bonus));
        $total += $bonus;
    }

    return {
        total   => $total,
        summary => $summary,
    };
}
