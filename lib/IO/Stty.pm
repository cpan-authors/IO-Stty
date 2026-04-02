package IO::Stty;

use strict;
use warnings;

use POSIX;

our $VERSION = '0.07';

# _POSIX_VDISABLE: the value that disables a special character slot.
# On Linux this is typically 0; on macOS/BSD it is typically 255 (0xFF).
# Fall back to 0 if the platform doesn't define it.
my $VDISABLE;
BEGIN {
    $VDISABLE = eval { POSIX::_POSIX_VDISABLE() };
    $VDISABLE = 0 unless defined $VDISABLE;
}

# Baud rate constants: standard POSIX rates plus modern rates.
# Modern rates (B57600, B115200, B230400) are not available on all platforms,
# so we use eval guards to include only what the current system supports.
my %BAUD_RATES;
my %BAUD_SPEEDS;
BEGIN {
    my @standard = qw(0 50 75 110 134 150 200 300 600 1200 1800 2400 4800 9600 19200 38400);
    my @modern   = qw(57600 115200 230400);
    for my $rate (@standard, @modern) {
        my $val = eval { POSIX->can("B$rate") };
        next unless $val && ref($val) eq 'CODE';
        $val = eval { $val->() };
        if (defined $val) {
            $BAUD_RATES{$rate}  = $val;
            $BAUD_SPEEDS{$val}  = $rate;
        }
    }
    # Standard aliases: 134.5 → B134, exta → B19200, extb → B38400
    $BAUD_RATES{'134.5'} = $BAUD_RATES{'134'}   if exists $BAUD_RATES{'134'};
    $BAUD_RATES{'exta'}  = $BAUD_RATES{'19200'} if exists $BAUD_RATES{'19200'};
    $BAUD_RATES{'extb'}  = $BAUD_RATES{'38400'} if exists $BAUD_RATES{'38400'};
}

# Flag-to-constant lookup tables: map stty parameter names to POSIX constants.
# Aliases (hup→HUPCL, crterase→ECHOE) are just extra table entries.
my %CFLAGS = (
    clocal => CLOCAL, cread  => CREAD,  cstopb => CSTOPB,
    hupcl  => HUPCL,  hup    => HUPCL,  parenb => PARENB,
    parodd => PARODD,
);
my %IFLAGS = (
    brkint => BRKINT, icrnl  => ICRNL,  ignbrk => IGNBRK,
    igncr  => IGNCR,  ignpar => IGNPAR, inlcr  => INLCR,
    inpck  => INPCK,  istrip => ISTRIP, ixoff  => IXOFF,
    ixon   => IXON,   parmrk => PARMRK,
);
my %LFLAGS = (
    echo     => ECHO,   echoe    => ECHOE,  crterase => ECHOE,
    echok    => ECHOK,  echonl   => ECHONL, icanon   => ICANON,
    iexten   => IEXTEN, isig     => ISIG,   noflsh   => NOFLSH,
    tostop   => TOSTOP,
);
my %OFLAGS = (
    opost => OPOST,
);

# Control character name → hash key mapping
my %CC_NAMES = (
    intr  => 'INTR',  quit  => 'QUIT',  erase => 'ERASE',
    kill  => 'KILL',  eof   => 'EOF',   eol   => 'EOL',
    start => 'START', stop  => 'STOP',  susp  => 'SUSP',
    min   => 'MIN',   time  => 'TIME',
);

# Ordered display lists for show_me_the_crap — preserves GNU-like output order.
my @CFLAG_DISPLAY = ( [CLOCAL,'clocal'], [CREAD,'cread'], [CSTOPB,'cstopb'], [HUPCL,'hupcl'], [PARENB,'parenb'], [PARODD,'parodd'] );
my @LFLAG_DISPLAY = ( [ECHO,'echo'], [ECHOE,'echoe'], [ECHOK,'echok'], [ECHONL,'echonl'], [ICANON,'icanon'], [ISIG,'isig'], [NOFLSH,'noflsh'], [TOSTOP,'tostop'], [IEXTEN,'iexten'] );
my @IFLAG_DISPLAY = ( [BRKINT,'brkint'], [IGNBRK,'ignbrk'], [IGNPAR,'ignpar'], [PARMRK,'parmrk'], [INPCK,'inpck'], [ISTRIP,'istrip'], [INLCR,'inlcr'], [IGNCR,'igncr'], [ICRNL,'icrnl'], [IXON,'ixon'], [IXOFF,'ixoff'] );

=for markdown [![testsuite](https://github.com/cpan-authors/IO-Stty/actions/workflows/testsuite.yml/badge.svg)](https://github.com/cpan-authors/IO-Stty/actions/workflows/testsuite.yml)

=head1 NAME

IO::Stty - Change and print terminal line settings

=head1 SYNOPSIS

    # calling the script directly
    stty.pl [setting...]
    stty.pl {-a,-g,-v,--version}
    
    # Calling Stty module
    use IO::Stty;
    IO::Stty::stty(\*TTYHANDLE, @modes);

     use IO::Stty;
     $old_mode=IO::Stty::stty(\*STDIN,'-g');

     # Turn off echoing.
     IO::Stty::stty(\*STDIN,'-echo');

     # Do whatever.. grab input maybe?
     $read_password = <>;

     # Now restore the old mode.
     IO::Stty::stty(\*STDIN,$old_mode);

     # What settings do we have anyway?
     print IO::Stty::stty(\*STDIN,'-a');

=head1 DESCRIPTION

This is the PERL POSIX compliant stty. 

=head1 INTRO

This has not been tailored to the IO::File stuff but will work with it as
indicated. Before you go futzing with term parameters it's a good idea to grab
the current settings and restore them when you finish.

stty accepts the following non-option arguments that change aspects of the
terminal line operation. A `[-]' before a capability means that it can be
turned off by preceding it with a `-'. 

=head1 stty parameters

=head2 Control settings

=over 4

=item [-]parenb

Generate parity bit in output and expect parity bit in input.

=item [-]parodd

Set odd parity (even with `-').

=item cs5 cs6 cs7 cs8

Set character size to 5, 6, 7, or 8 bits.

=item [-]hupcl [-]hup

Send a hangup signal when the last process closes the tty.

=item [-]cstopb

Use two stop bits per character (one with `-').

=item [-]cread

Allow input to be received.

=item [-]clocal

Disable modem control signals.

=back

=head2 Input settings

=over 4

=item [-]ignbrk

Ignore break characters.

=item [-]brkint

Breaks cause an interrupt signal.

=item [-]ignpar

Ignore characters with parity errors.

=item [-]parmrk

Mark parity errors (with a 255-0-character sequence).

=item [-]inpck

Enable input parity checking.

=item [-]istrip

Clear high (8th) bit of input characters.

=item [-]inlcr

Translate newline to carriage return.

=item [-]igncr

Ignore carriage return.

=item [-]icrnl

Translate carriage return to newline.

=item [-]ixon

Enable XON/XOFF flow control.

=item [-]ixoff

Enable sending of stop character when the system
input buffer is almost full, and start character
when it becomes almost empty again.

=back 

=head2 Output settings

=over 4

=item [-]opost

Postprocess output.

=back

=head2 Local settings

=over 4

=item [-]isig

Enable interrupt, quit, and suspend special characters.

=item [-]icanon

Enable erase, kill, werase, and rprnt special characters.

=item [-]echo

Echo input characters.

=item [-]echoe, [-]crterase

Echo erase characters as backspace-space-backspace.

=item [-]echok

Echo a newline after a kill character.

=item [-]echonl

Echo newline even if not echoing other characters.

=item [-]noflsh

Disable flushing after interrupt and quit special characters.

* Though this claims non-posixhood it is supported by the perl POSIX.pm.

=item [-]iexten

Enable implementation-defined input processing.  This is needed for
special characters like werase and lnext to be recognized.

=item [-]tostop (np)

Stop background jobs that try to write to the terminal.

=back

=head2 Combination settings

=over 4

=item ek

Reset the erase and kill special characters to their default values.

=item sane

Same as:

    cread -ignbrk brkint -inlcr -igncr icrnl -ixoff opost
    isig icanon iexten echo echoe echok -echonl -noflsh -tostop

also sets all special characters to their default
values.

=item [-]cooked

Same as:

    brkint ignpar istrip icrnl ixon opost isig icanon

plus sets the eof and eol characters to their default values 
if they are the same as the min and time characters.
With `-', same as raw.

=item [-]raw

Same as:

    -ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr
    -icrnl -ixon -ixoff -opost -isig -icanon min 1 time 0

With `-', same as cooked.

=item [-]pass8

Same as:

    -parenb -istrip cs8

With  `-',  same  as parenb istrip cs7.

=item crt

Same as:

    echoe echok

=item dec

Same as:

    echoe echok

Also sets the interrupt special character to Ctrl-C, erase to
Del, and kill to Ctrl-U.

=item [-]cbreak

Same as C<-icanon> (with C<->, same as C<icanon>).

=item evenp, parity

Same as:

    parenb -parodd cs7

=item oddp

Same as:

    parenb parodd cs7

=item -evenp, -parity, -oddp

Same as:

    -parenb cs8

=item [-]litout

Same as:

    -parenb -istrip -opost cs8

With C<->, same as C<parenb istrip opost cs7>.

=back

=head2 Special characters

The special characters' default values vary from system to
system. They are set with the syntax `name value', where
the names are listed below and the value can be given
either literally, in hat notation (`^c'), or as an integer
which may start with `0x' to indicate hexadecimal, `0' to
indicate octal, or any other digit to indicate decimal.
Giving a value of `^-' or `undef' disables that special
character (sets it to C<_POSIX_VDISABLE>, which is 0 on
Linux and 255 on macOS/BSD).

=over 4

=item intr

Send an interrupt signal.

=item quit

Send a quit signal.

=item erase

Erase the last character typed.

=item kill

Erase the current line.

=item eof

Send an end of file (terminate the input).

=item eol

End the line.

=item start

Restart the output after stopping it.

=item stop

Stop the output.

=item susp

Send a terminal stop signal.

=back

=head2 Special settings

=over 4

=item min N

Set the minimum number of characters that will satisfy a read 
until the time value has expired, when C<-icanon> is set.

=item time N

Set the number of tenths of a second before reads
time out if the min number of characters  have  not
been read, when -icanon is set.

=item N

Set the input and output speeds to N.  N can be one
of: 0 50 75 110 134 134.5 150 200 300 600 1200 1800
2400 4800 9600 19200 38400 57600 115200 230400 exta
extb.  134.5 is the same as 134; exta is the same
as 19200; extb is the same as 38400.  Modern rates
(57600, 115200, 230400) are only available on
platforms whose POSIX implementation defines them.
0 hangs up the line if -clocal is set.

=back

=head2 OPTIONS

=over 4

=item -a

Print all current settings in human-readable  form.

=item -g

Print all current settings in a form  that  can  be
used  as  an  argument  to  another stty command to
restore the current settings.

=item speed

Print the output baud rate.

=item -v,--version

Print version info.

=back

=head1 Direct Subroutines

=over 4

=item B<_parse_char_value()>

    my $numeric = IO::Stty::_parse_char_value($value);

Parse a special character value from any of the supported notations:
literal integers, hat notation (C<^c>), hexadecimal (C<0x...>),
octal (C<0...>), or C<undef>/C<^-> to disable (returns
C<_POSIX_VDISABLE>).

=cut

sub _parse_char_value {
    my ($val) = @_;

    # undef or ^- means disable the character
    if ( $val eq 'undef' || $val eq '^-' ) {
        return $VDISABLE;
    }

    # Hat notation: ^c means Ctrl-C (0x03), ^? means DEL (0x7F)
    if ( $val =~ /^\^(.)$/ ) {
        my $ch = $1;
        if ( $ch eq '?' ) {
            return 0x7F;
        }
        return ord( uc($ch) ) & 0x1F;
    }

    # Hexadecimal: 0x...
    if ( $val =~ /^0x([0-9a-fA-F]+)$/ ) {
        return hex($1);
    }

    # Octal: 0 followed by digits (but not plain "0" which is decimal zero)
    if ( $val =~ /^0(\d+)$/ ) {
        return oct($1);
    }

    # Decimal integer (including plain 0)
    if ( $val =~ /^\d+$/ ) {
        return $val + 0;
    }

    # Single literal character
    if ( length($val) == 1 ) {
        return ord($val);
    }

    warn "IO::Stty: unrecognized character value '$val'\n";
    return 0;
}

=item B<stty()>

    IO::Stty::stty(\*STDIN, @params);

Returns a string for query options (C<-a>, C<-g>, C<-v>), C<undef> if
the handle is not a terminal or if the terminal parameters could not be
read, and a true value on success when setting parameters.

From comments:

    I'm not feeling very inspired about this. Terminal parameters are obscure
    and boring. Basically what this will do is get the current setting,
    take the parameters, modify the setting and write it back. Zzzz.
    This is not especially efficent and probably not too fast. Assuming the POSIX
    spec has been implemented properly it should mostly work.

=cut

sub stty {
    my $tty_handle = shift;    # This should be a \*HANDLE

    @_ or die("No parameters passed to stty");

    # Notice fileno() instead of handle->fileno(). I want it to work with
    # normal fhs.
    my ($file_num) = fileno($tty_handle);

    # Is it a terminal?
    return undef unless isatty($file_num);
    my ($tty_name) = ttyname($file_num);

    # make a terminal object.
    my ($termios) = POSIX::Termios->new();
    unless ( $termios->getattr($file_num) ) {
        warn "Couldn't get terminal parameters for '$tty_name', file num ($file_num)";
        return undef;
    }
    my ($c_cflag) = $termios->getcflag;
    my ($c_iflag) = $termios->getiflag;
    my ($ispeed)  = $termios->getispeed;
    my ($c_lflag) = $termios->getlflag;
    my ($c_oflag) = $termios->getoflag;
    my ($ospeed)  = $termios->getospeed;
    my (%control_chars);
    $control_chars{'INTR'}  = $termios->getcc(VINTR);
    $control_chars{'QUIT'}  = $termios->getcc(VQUIT);
    $control_chars{'ERASE'} = $termios->getcc(VERASE);
    $control_chars{'KILL'}  = $termios->getcc(VKILL);
    $control_chars{'EOF'}   = $termios->getcc(VEOF);
    $control_chars{'TIME'}  = $termios->getcc(VTIME);
    $control_chars{'MIN'}   = $termios->getcc(VMIN);
    $control_chars{'START'} = $termios->getcc(VSTART);
    $control_chars{'STOP'}  = $termios->getcc(VSTOP);
    $control_chars{'SUSP'}  = $termios->getcc(VSUSP);
    $control_chars{'EOL'}   = $termios->getcc(VEOL);

    # OK.. we have our crap.

    my @parameters;

    if ( @_ == 1 ) {

        # handle the one-arg cases specifically
        # Version info
        if ( $_[0] =~ /^(-v|--version|version)$/ ) {
            return $IO::Stty::VERSION . "\n";
        }
        elsif ( $_[0] =~ /^\d+$/ || $_[0] eq '134.5'
            || $_[0] eq 'exta' || $_[0] eq 'extb' )
        {
            push( @parameters, 'ispeed', $_[0], 'ospeed', $_[0] );
        }

        # Print just the output speed (matches GNU stty 'speed')
        elsif ( $_[0] eq 'speed' ) {
            my $speed_str = exists $BAUD_SPEEDS{$ospeed} ? $BAUD_SPEEDS{$ospeed} : $ospeed;
            return "$speed_str\n";
        }

        # Do we want to know what the crap is?
        elsif ( $_[0] eq '-a' ) {
            return show_me_the_crap(
                $c_cflag, $c_iflag, $ispeed, $c_lflag, $c_oflag,
                $ospeed,  \%control_chars
            );
        }

        # did we get the '-g' flag?
        elsif ( $_[0] eq '-g' ) {
            return
                "$c_cflag:$c_iflag:$ispeed:$c_lflag:$c_oflag:$ospeed:"
              . $control_chars{'INTR'} . ":"
              . $control_chars{'QUIT'} . ":"
              . $control_chars{'ERASE'} . ":"
              . $control_chars{'KILL'} . ":"
              . $control_chars{'EOF'} . ":"
              . $control_chars{'TIME'} . ":"
              . $control_chars{'MIN'} . ":"
              . $control_chars{'START'} . ":"
              . $control_chars{'STOP'} . ":"
              . $control_chars{'SUSP'} . ":"
              . $control_chars{'EOL'};
        }
        else {
            # Or the converse.. -g used before and we're getting the return.
            # Note that this uses the functionality of stty -g, not any specific
            # method. Don't take the output here and feed it to the OS stty.

            # This will make  perl -w happy.
            my (@g_params) = split( ':', $_[0] );
            if ( @g_params == 17 ) {

                #   print "Feeding back...\n";
                ( $c_cflag, $c_iflag, $ispeed, $c_lflag, $c_oflag, $ospeed ) = (@g_params);
                $control_chars{'INTR'}  = $g_params[6];
                $control_chars{'QUIT'}  = $g_params[7];
                $control_chars{'ERASE'} = $g_params[8];
                $control_chars{'KILL'}  = $g_params[9];
                $control_chars{'EOF'}   = $g_params[10];
                $control_chars{'TIME'}  = $g_params[11];
                $control_chars{'MIN'}   = $g_params[12];
                $control_chars{'START'} = $g_params[13];
                $control_chars{'STOP'}  = $g_params[14];
                $control_chars{'SUSP'}  = $g_params[15];
                $control_chars{'EOL'}   = $g_params[16];

                # leave parameters empty
            }
            else {
                # a simple single option
                @parameters = @_;
            }
        }
    }
    else {
        @parameters = @_;
    }

    # So.. what shall we set?
    my ($set_value);
    local ($_);
    while ( defined( $_ = shift(@parameters) ) ) {

        #    print "Param:$_:\n";
        # Build the 'this really means this' cases.
        if ( $_ eq 'ek' ) {
            unshift( @parameters, 'erase', 8, 'kill', 21 );
            next;
        }
        if ( $_ eq 'sane' ) {
            unshift(
                @parameters, 'cread', '-ignbrk', 'brkint', '-inlcr', '-igncr', 'icrnl',
                '-ixoff', 'opost', 'isig', 'icanon', 'iexten', 'echo', 'echoe', 'echok',
                '-echonl', '-noflsh', '-tostop', 'intr', 3, 'quit', 28, 'erase',
                8,      'kill', 21,    'eof', 4, 'eol', 'undef', 'stop', 19, 'start', 17, 'susp', 26,
                'time', 0,      'min', 0
            );
            next;

            # Ugh.
        }
        if ( $_ eq 'cooked' || $_ eq '-raw' ) {

            # Is this right?
            unshift(
                @parameters, 'brkint', 'ignpar', 'istrip', 'icrnl', 'ixon', 'opost',
                'isig',      'icanon',
                'intr', 3, 'quit', 28, 'erase', 8, 'kill', 21, 'eof',
                4, 'eol', 'undef', 'stop', 19, 'start', 17, 'susp', 26, 'time', 0, 'min', 0
            );
            next;
        }
        if ( $_ eq 'raw' || $_ eq '-cooked' ) {
            unshift(
                @parameters, '-ignbrk', '-brkint', '-ignpar', '-parmrk', '-inpck',
                '-istrip',   '-inlcr',  '-igncr',  '-icrnl',  '-ixon',   '-ixoff',
                '-opost', '-isig', '-icanon', 'min', 1, 'time', 0
            );
            next;
        }
        if ( $_ eq 'pass8' ) {
            unshift( @parameters, '-parenb', '-istrip', 'cs8' );
            next;
        }
        if ( $_ eq '-pass8' ) {
            unshift( @parameters, 'parenb', 'istrip', 'cs7' );
            next;
        }
        if ( $_ eq 'crt' ) {
            unshift( @parameters, 'echoe', 'echok' );
            next;
        }
        if ( $_ eq 'dec' ) {

            # 127 == delete, no?
            unshift( @parameters, 'echoe', 'echok', 'intr', 3, 'erase', 127, 'kill', 21 );
            next;
        }
        if ( $_ eq 'evenp' || $_ eq 'parity' ) {
            unshift( @parameters, 'parenb', '-parodd', 'cs7' );
            next;
        }
        if ( $_ eq '-evenp' || $_ eq '-parity' || $_ eq '-oddp' ) {
            unshift( @parameters, '-parenb', 'cs8' );
            next;
        }
        if ( $_ eq 'oddp' ) {
            unshift( @parameters, 'parenb', 'parodd', 'cs7' );
            next;
        }
        if ( $_ eq 'cbreak' ) {
            unshift( @parameters, '-icanon' );
            next;
        }
        if ( $_ eq '-cbreak' ) {
            unshift( @parameters, 'icanon' );
            next;
        }
        if ( $_ eq 'litout' ) {
            unshift( @parameters, '-parenb', '-istrip', '-opost', 'cs8' );
            next;
        }
        if ( $_ eq '-litout' ) {
            unshift( @parameters, 'parenb', 'istrip', 'opost', 'cs7' );
            next;
        }
        $set_value = 1;              # On by default...
                                     # unset if starts w/ -, as in  -crtscts
        $set_value = 0 if s/^\-//;

        # Now the fun part.

        # Control character settings (intr, quit, erase, kill, etc.)
        if ( exists $CC_NAMES{$_} ) {
            $control_chars{ $CC_NAMES{$_} } = _parse_char_value( shift @parameters );
            next;
        }

        # Character size (cs5-cs8) — special: mask and set, not a simple toggle
        if ( $_ eq 'cs5' ) { $c_cflag = ( ( $c_cflag & ~CS8 ) | CS5 ); next; }
        if ( $_ eq 'cs6' ) { $c_cflag = ( ( $c_cflag & ~CS8 ) | CS6 ); next; }
        if ( $_ eq 'cs7' ) { $c_cflag = ( ( $c_cflag & ~CS8 ) | CS7 ); next; }
        if ( $_ eq 'cs8' ) { $c_cflag = ( $c_cflag | CS8 );            next; }

        # Flag tables: cflag, iflag, lflag, oflag
        if ( exists $CFLAGS{$_} ) { $c_cflag = ( $set_value ? ( $c_cflag | $CFLAGS{$_} ) : ( $c_cflag & ~$CFLAGS{$_} ) ); next; }
        if ( exists $IFLAGS{$_} ) { $c_iflag = ( $set_value ? ( $c_iflag | $IFLAGS{$_} ) : ( $c_iflag & ~$IFLAGS{$_} ) ); next; }
        if ( exists $LFLAGS{$_} ) { $c_lflag = ( $set_value ? ( $c_lflag | $LFLAGS{$_} ) : ( $c_lflag & ~$LFLAGS{$_} ) ); next; }
        if ( exists $OFLAGS{$_} ) { $c_oflag = ( $set_value ? ( $c_oflag | $OFLAGS{$_} ) : ( $c_oflag & ~$OFLAGS{$_} ) ); next; }

        # Speed?
        if ( $_ eq 'ospeed' ) {
            my $rate = shift(@parameters);
            exists $BAUD_RATES{$rate} or warn "IO::Stty::stty: unknown baud rate '$rate'\n";
            $ospeed = $BAUD_RATES{$rate} if exists $BAUD_RATES{$rate};
            next;
        }
        if ( $_ eq 'ispeed' ) {
            my $rate = shift(@parameters);
            exists $BAUD_RATES{$rate} or warn "IO::Stty::stty: unknown baud rate '$rate'\n";
            $ispeed = $BAUD_RATES{$rate} if exists $BAUD_RATES{$rate};
            next;
        }

        # Default.. parameter hasn't matched anything
        #    print "char:".sprintf("%lo",ord($_))."\n";
        warn "IO::Stty::stty passed invalid parameter '$_'\n";
    }

    # What a pain in the ass! Ok.. let's write the crap back.
    $termios->setcflag($c_cflag);
    $termios->setiflag($c_iflag);
    $termios->setispeed($ispeed);
    $termios->setlflag($c_lflag);
    $termios->setoflag($c_oflag);
    $termios->setospeed($ospeed);
    $termios->setcc( VINTR,  $control_chars{'INTR'} );
    $termios->setcc( VQUIT,  $control_chars{'QUIT'} );
    $termios->setcc( VERASE, $control_chars{'ERASE'} );
    $termios->setcc( VKILL,  $control_chars{'KILL'} );

    # On some systems (e.g. Solaris/SVR4), VEOF==VMIN and VEOL==VTIME
    # share the same cc slot.  The slot's meaning depends on ICANON:
    # canonical mode uses VEOF/VEOL, non-canonical uses VMIN/VTIME.
    # Writing both would let the second overwrite the first, so we
    # write only the one that matches the final ICANON state.
    if (VEOF == VMIN) {
        if ($c_lflag & ICANON) {
            $termios->setcc( VEOF, $control_chars{'EOF'} );
        }
        else {
            $termios->setcc( VMIN, $control_chars{'MIN'} );
        }
    }
    else {
        $termios->setcc( VEOF, $control_chars{'EOF'} );
        $termios->setcc( VMIN, $control_chars{'MIN'} );
    }
    if (VEOL == VTIME) {
        if ($c_lflag & ICANON) {
            $termios->setcc( VEOL, $control_chars{'EOL'} );
        }
        else {
            $termios->setcc( VTIME, $control_chars{'TIME'} );
        }
    }
    else {
        $termios->setcc( VTIME, $control_chars{'TIME'} );
        $termios->setcc( VEOL,  $control_chars{'EOL'} );
    }

    $termios->setcc( VSTART, $control_chars{'START'} );
    $termios->setcc( VSTOP,  $control_chars{'STOP'} );
    $termios->setcc( VSUSP,  $control_chars{'SUSP'} );
    return $termios->setattr( $file_num, TCSANOW );    # TCSANOW = do immediately. don't unbuffer first.
                                                      # OK.. that sucked.
}

=item B<show_me_the_crap()>

    my $output = IO::Stty::show_me_the_crap(
        $c_cflag, $c_iflag, $ispeed, $c_lflag, $c_oflag,
        $ospeed,  \%control_chars
    );

Format terminal settings as a human-readable string, equivalent to
C<stty -a> output.  Returns a multi-line string showing the current baud
rate, special character assignments (in hat notation), and the state of
all control, input, output, and local flags.

This is the back-end for C<stty(\*FH, '-a')>.

=cut

sub _cc_to_hat {
    my ($val) = @_;
    return '<undef>' if !defined $val || $val == $VDISABLE;
    return '^?' if $val == 127;
    return '^' . chr( ord('@') + $val ) if $val >= 0 && $val < 32;
    return chr($val);
}

sub show_me_the_crap {
    my (
        $c_cflag, $c_iflag, $ispeed, $c_lflag, $c_oflag,
        $ospeed,  $control_chars
    ) = @_;
    my (%cc) = %$control_chars;

    # rs = return string
    my ($rs) = '';
    $rs .= 'speed ';
    if ( exists $BAUD_SPEEDS{$ospeed} ) {
        $rs .= $BAUD_SPEEDS{$ospeed};
    }
    else {
        $rs .= $ospeed;
    }
    $rs .= " baud;";
    if ( $ispeed != $ospeed ) {
        $rs .= ' ispeed ';
        if ( exists $BAUD_SPEEDS{$ispeed} ) {
            $rs .= $BAUD_SPEEDS{$ispeed};
        }
        else {
            $rs .= $ispeed;
        }
        $rs .= ' baud;';
    }
    $rs .= "\n";
    $rs .= 'intr = ' . _cc_to_hat($cc{'INTR'}) . '; quit = ' . _cc_to_hat($cc{'QUIT'}) . '; erase = ' . _cc_to_hat($cc{'ERASE'}) . '; kill = ' . _cc_to_hat($cc{'KILL'}) . ";\n";
    $rs .= 'eof = ' . _cc_to_hat($cc{'EOF'}) . '; eol = ' . _cc_to_hat($cc{'EOL'}) . '; start = ' . _cc_to_hat($cc{'START'}) . '; stop = ' . _cc_to_hat($cc{'STOP'}) . '; susp = ' . _cc_to_hat($cc{'SUSP'}) . ";\n";
    $rs .= 'min = ' . (defined $cc{'MIN'} ? $cc{'MIN'} : 0) . '; time = ' . (defined $cc{'TIME'} ? $cc{'TIME'} : 0) . ";\n";

    # c flags.
    for my $pair (@CFLAG_DISPLAY) {
        $rs .= ( ( $c_cflag & $pair->[0] ) ? '' : '-' ) . "$pair->[1] ";
    }
    my $cs_bits = $c_cflag & CS8;
    if    ( $cs_bits == CS8 ) { $rs .= "cs8\n"; }
    elsif ( $cs_bits == CS7 ) { $rs .= "cs7\n"; }
    elsif ( $cs_bits == CS6 ) { $rs .= "cs6\n"; }
    else                      { $rs .= "cs5\n"; }

    # l flags.
    for my $pair (@LFLAG_DISPLAY) {
        $rs .= ( ( $c_lflag & $pair->[0] ) ? '' : '-' ) . "$pair->[1] ";
    }

    # o flag — appended after l flags for compact display.
    $rs .= ( ( $c_oflag & OPOST ) ? '' : '-' ) . "opost\n";

    # i flags.
    for my $i ( 0 .. $#IFLAG_DISPLAY ) {
        my $pair = $IFLAG_DISPLAY[$i];
        my $sep = ( $i == $#IFLAG_DISPLAY ) ? "\n" : ' ';
        $rs .= ( ( $c_iflag & $pair->[0] ) ? '' : '-' ) . "$pair->[1]$sep";
    }
    return $rs;
}

=back

=head1 AUTHOR

Austin Schutz <auschutz@cpan.org> (Initial version and maintenance)

Todd Rinaldo <toddr@cpan.org> (Maintenance)

=head1 BUGS

This is use at your own risk software. Do anything you want with it except
blame me for it blowing up your machine because it's full of bugs.

See above for what functions are supported. It's mostly standard POSIX
stuff. If any of the settings are wrong and you actually know what some of
these extremely arcane settings (like what 'sane' should be in POSIX land)
really should be, please open an RT ticket.

=head1 ACKNOWLEDGEMENTS

None

=head1 COPYRIGHT & LICENSE

Copyright 1997 Austin Schutz, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;
