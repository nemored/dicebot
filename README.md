# dicebot

A lightweight IRC dice bot written in Perl.

## Dependencies

Install one non-core dependency for IRC connectivity:

- `AnyEvent::IRC::Client`

Everything else used by the bot comes from Perl core modules.

## Configuration

Configuration is plain Perl and is loaded with `do`, so you can use Perl expressions in it.

1. Copy `config/dicebot.conf.pl` and edit values.
2. Ensure it returns a hash reference.

Required keys:

- `server`
- `port`
- `nick`
- `channels` (arrayref)

Optional keys:

- `tls` (default: disabled; set to `1` to enable TLS)
- `username`
- `realname`
- `password`
- `trigger` (default: `!roll`)
- `max_dice` (default: 20)
- `max_sides` (default: 1000)
- `max_abs_bonus` (default: 1000)

When TLS is enabled, use a TLS IRC port (commonly `6697`).

## Run

```bash
perl bin/dicebot.pl --config config/dicebot.conf.pl
```

## Usage in IRC

In any configured channel:

- `!roll` → rolls `1d20`
- `!roll d20`
- `!roll 3d6+2`
- `!roll 4d8-1`

The bot replies with each die result and the final total.
