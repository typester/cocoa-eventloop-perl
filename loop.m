#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#import <Foundation/Foundation.h>

@interface Cocoa__EventLoop__Timer : NSObject {
@public
    NSTimer* timer;
    SV* cb;
}
-(void)callback;
@end

@implementation Cocoa__EventLoop__Timer

-(void)callback {
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    PUTBACK;

    call_sv(cb, G_SCALAR);

    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;
}

-(void)dealloc {
    [super dealloc];
}

@end

@interface Cocoa__EventLoop__IOWatcher : NSObject <NSStreamDelegate> {
@public
    int fd;
    int mode;
    NSInputStream* read_stream;
    NSOutputStream* write_stream;
    SV* cb;
}
@end

@implementation Cocoa__EventLoop__IOWatcher

-(void)stream:(NSStream *)stream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventHasSpaceAvailable:
        case NSStreamEventHasBytesAvailable:
            break;
        default:
            //NSLog(@"ignore event: %d", eventCode);
            return;
    }

    // clear streams
    [read_stream close];
    [read_stream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
    [read_stream release];
    read_stream = nil;

    [write_stream close];
    [write_stream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                     forMode:NSDefaultRunLoopMode];
    [write_stream release];
    write_stream = nil;

    // recreate watcher
    CFStreamCreatePairWithSocket(kCFAllocatorDefault, fd, mode == 0 ? &read_stream : NULL, mode == 1 ? &write_stream : NULL);
    if ((mode == 0 && read_stream) || (mode == 1 && write_stream)) {
        read_stream = [read_stream retain];
        write_stream = [write_stream retain];

        if (0 == mode) {
            [read_stream setDelegate:self];
            [read_stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                   forMode:NSDefaultRunLoopMode];
            [read_stream open];
        }
        else {
            [write_stream setDelegate:self];
            [write_stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                    forMode:NSDefaultRunLoopMode];
            [write_stream open];
        }
    }

    // callback
    dSP;

    ENTER;
    SAVETMPS;

    PUSHMARK(SP);
    PUTBACK;

    call_sv(cb, G_SCALAR);

    SPAGAIN;

    PUTBACK;
    FREETMPS;
    LEAVE;
}

@end

XS(run_while) {
    dXSARGS;

    if (items < 2) {
        Perl_croak(aTHX_ "usage: Cocoa::EventLoop->run_while($secs)\n");
    }

    SV* sv_secs = ST(1);
    if (!SvOK(sv_secs) || !SvNIOK(sv_secs)) {
        Perl_croak(aTHX_ "usage: run_while($secs)\n");
    }

    double secs = SvNV(sv_secs);

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                             beforeDate:[NSDate dateWithTimeIntervalSinceNow:secs]];
    [pool drain];

    XSRETURN(0);
}

XS(run) {
    dXSARGS;

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
    [[NSRunLoop currentRunLoop] run];
    [pool drain];

    XSRETURN(0);
}

XS(add_timer) {
    dXSARGS;

    if (items < 4) {
        Perl_croak(aTHX_ "Usage: add_timer($obj, $after, $interval, $cb)");
    }

    SV* sv_obj      = ST(0);
    SV* sv_after    = ST(1);
    SV* sv_interval = ST(2);
    SV* sv_cb       = ST(3);

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    double after    = SvNV(sv_after);
    double interval = SvNV(sv_interval);

    Cocoa__EventLoop__Timer* t = [[Cocoa__EventLoop__Timer alloc] init];

    t->cb = SvREFCNT_inc(sv_cb);
    t->timer = [[NSTimer alloc]
                   initWithFireDate:[NSDate dateWithTimeIntervalSinceNow:after]
                           interval:interval
                             target:t
                           selector:@selector(callback)
                           userInfo:nil
                            repeats:interval ? YES : NO];

    sv_magic(SvRV(sv_obj), NULL, PERL_MAGIC_ext, NULL, 0);
    mg_find(SvRV(sv_obj), PERL_MAGIC_ext)->mg_obj = (void*)t;

    [[NSRunLoop currentRunLoop] addTimer:t->timer
                                 forMode:NSDefaultRunLoopMode];

    [pool drain];

    XSRETURN(0);
}

XS(remove_timer) {
    dXSARGS;

    if (items < 1) {
        Perl_croak(aTHX_ "Usage: remove_timer($timer)");
    }

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    SV* sv_timer = ST(0);

    MAGIC* m = mg_find(SvRV(sv_timer), PERL_MAGIC_ext);
    Cocoa__EventLoop__Timer* t = (Cocoa__EventLoop__Timer*)m->mg_obj;

    [t->timer invalidate];
    SvREFCNT_dec(t->cb);
    [t release];

    [pool drain];

    XSRETURN(0);
}

XS(add_io) {
    dXSARGS;

    if (items < 4) {
        Perl_croak(aTHX_ "Usage: add_io($obj, $fd, $mode, $cb)");
    }

    SV* sv_obj  = ST(0);
    SV* sv_fd   = ST(1);
    SV* sv_mode = ST(2);
    SV* sv_cb   = ST(3);

    int fd   = SvIV(sv_fd);
    int mode = SvIV(sv_mode);

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    NSInputStream* read_stream = nil;
    NSOutputStream* write_stream = nil;

    CFStreamCreatePairWithSocket(kCFAllocatorDefault, fd, mode == 0 ? &read_stream : NULL, mode == 1 ? &write_stream : NULL);
    if ((mode == 0 && read_stream) || (mode == 1 && write_stream)) {
        Cocoa__EventLoop__IOWatcher* io = [[Cocoa__EventLoop__IOWatcher alloc] init];
        io->fd = fd;
        io->mode = mode;
        io->read_stream = [read_stream retain];
        io->write_stream = [write_stream retain];
        io->cb = SvREFCNT_inc(sv_cb);

        if (0 == mode) {
            [io->read_stream setDelegate:io];
            [io->read_stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                       forMode:NSDefaultRunLoopMode];
            [io->read_stream open];
        }
        else {
            [io->write_stream setDelegate:io];
            [io->write_stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                                        forMode:NSDefaultRunLoopMode];
            [io->write_stream open];
        }

        sv_magic(SvRV(sv_obj), NULL, PERL_MAGIC_ext, NULL, 0);
        mg_find(SvRV(sv_obj), PERL_MAGIC_ext)->mg_obj = (void*)io;
    }
    else {
        NSLog(@"open socket failed");
    }

    [pool drain];

    XSRETURN(0);
}

XS(remove_io) {
    dXSARGS;

    if (items < 1) {
        Perl_croak(aTHX_ "Usage: remove_io($obj)");
    }

    NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];

    SV* sv_obj = ST(0);
    MAGIC* m = mg_find(SvRV(sv_obj), PERL_MAGIC_ext);
    if (m) {
        Cocoa__EventLoop__IOWatcher* io = (Cocoa__EventLoop__IOWatcher*)m->mg_obj;

        if (0 == io->mode) {    // read
            [io->read_stream close];
            [io->read_stream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                       forMode:NSDefaultRunLoopMode];

        }
        else {
            [io->write_stream close];
            [io->write_stream removeFromRunLoop:[NSRunLoop currentRunLoop]
                                       forMode:NSDefaultRunLoopMode];
        }

        [io->read_stream release];
        [io->write_stream release];
        SvREFCNT_dec(io->cb);
        [io release];
    }

    [pool release];

    XSRETURN(0);
}

XS(boot_Cocoa__EventLoop) {
    newXS("Cocoa::EventLoop::run_while", run_while, __FILE__);
    newXS("Cocoa::EventLoop::run", run, __FILE__);
    newXS("Cocoa::EventLoop::__add_timer", add_timer, __FILE__);
    newXS("Cocoa::EventLoop::__remove_timer", remove_timer, __FILE__);
    newXS("Cocoa::EventLoop::__add_io", add_io, __FILE__);
    newXS("Cocoa::EventLoop::__remove_io", remove_io, __FILE__);
}
