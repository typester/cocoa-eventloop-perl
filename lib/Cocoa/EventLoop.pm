package Cocoa::EventLoop;
use strict;
use XSLoader;

our $VERSION = '0.01';

BEGIN {
    XSLoader::load __PACKAGE__, $VERSION;
}

sub timer {
    my ($class, %arg) = @_;

    my $cb    = $arg{cb};
    my $ival  = $arg{interval} || 0;
    my $after = $arg{after} || 0;

    my $timer = bless {}, 'Cocoa::EventLoop::timer';
    __add_timer($timer, $after, $ival, $cb);

    $timer;
}

sub Cocoa::EventLoop::timer::DESTROY {
    __remove_timer($_[0]);
}

sub io {
    my ($class, %arg) = @_;

    my $fd = fileno($arg{fh});
    defined $fd or $fd = $arg{fh};

    my $mode = $arg{poll} eq 'r' ? 0 : 1;
    my $io = bless {}, 'Cocoa::EventLoop::io';

    __add_io($io, $fd, $mode, $arg{cb});

    $io;
}

sub Cocoa::EventLoop::io::DESTROY {
    __remove_io($_[0]);
}

1;

__END__

=for stopwords io

=head1 NAME

Cocoa::EventLoop - perl interface for Cocoa event loop.

=head1 SYNOPSIS

    use Cocoa::EventLoop;
    
    # on-shot timer
    my $timer = Cocoa::EventLoop->timer(
        after => 10,
        cb    => sub {
            # do something
        },
    );
    
    # repeatable timer
    my $timer = Cocoa::EventLoop->timer(
        after    => 10,
        interval => 10,
        cb       => sub {
            # do something
        },
    );
    
    # stop or cancel timers
    undef $timer;
    
    
    # IO Watcher
    my $io = Cocoa::EventLoop->io(
        fh   => *STDIN,
        poll => 'r',
        cb   => sub {
            warn 'read: ', <STDIN>;
        },
    );
    
    
    # run main loop
    Cocoa::EventLoop->run;
    
    # run main loop for specified period.
    Cocoa::EventLoop->run_while($secs);


=head1 DESCRIPTION

Stub documentation for this module was created by ExtUtils::ModuleMaker.
It looks like the author of the extension was negligent enough
to leave the stub unedited.

=head1 METHODS

=head2 timer

=head2 io

=head2 run

=head2 run_while

=head1 AUTHOR

Daisuke Murase <typester@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2009 by KAYAC Inc.

This program is free software; you can redistribute
it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the
LICENSE file included with this module.

=cut
