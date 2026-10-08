#import "AppController.h"
#import <objc/runtime.h>
#import <unistd.h>

@interface NSMovieView (PlaybackTests)
- (BOOL) seekToTime: (int64_t)timestamp;
- (void) displayCurrentFrame;
@end

static void RunFor(NSTimeInterval seconds)
{
  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: seconds]];
}

// Model a file read that takes longer than the former one-second stop timeout.
static void SlowFeed(id self, SEL command)
{
  while (![[NSThread currentThread] isCancelled])
    usleep(1000);
  usleep(1300000);
}

int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSCAssert(argc == 2, @"Expected a video path");
  [NSApplication sharedApplication];
  NSCAssert([NSBundle loadNibFile: @"Resources/VideoPlayer.gorm"
    externalNameTable: @{NSNibOwner: NSApp} withZone: NSDefaultMallocZone()],
    @"Load interface");
  AppController *controller = [NSApp delegate];
  [controller applicationDidFinishLaunching: nil];
  NSMovieView *view = [controller valueForKey: @"movieView"];
  NSString *path = [NSString stringWithUTF8String: argv[1]];
  NSCAssert([controller openVideoAtPath: path sender: nil], @"Open video");
  [view stop: nil];

  Method feed = class_getInstanceMethod([view class], @selector(feed));
  IMP originalFeed = method_setImplementation(feed, (IMP)SlowFeed);
  [view start: nil];
  NSThread *worker = [[view valueForKey: @"feedThread"] retain];
  [view stop: nil];
  NSCAssert([worker isFinished], @"Stop must join even a slow file reader");
  [worker release];
  method_setImplementation(feed, originalFeed);

  for (int i = 0; i < 8; i++)
    {
      NSLog(@"Playback controls cycle %d", i + 1);
      [view start: nil];
      RunFor(0.15);
      [[controller valueForKey: @"volume"] setFloatValue: 0.3];
      [controller volume: [controller valueForKey: @"volume"]];
      [[controller valueForKey: @"mute"] setState: i % 2];
      [controller mute: [controller valueForKey: @"mute"]];
      [[controller valueForKey: @"timeSlider"] setDoubleValue: 0.1 + i * 0.1];
      [controller time: nil];
      RunFor(0.15);
      [view stepForward: nil];
      RunFor(0.15);
      [view stepBack: nil];
      RunFor(0.15);
      [view gotoBeginning: nil];
      [view start: nil];
      [view stepForward: nil]; // Queues a restart after the seek.
      [view stop: nil];
      RunFor(0.2);
      NSCAssert(![view isPlaying], @"Pause stops playback");
      NSCAssert([view valueForKey: @"feedThread"] == nil
        && [view valueForKey: @"videoThread"] == nil, @"No live workers after stop");
    }
  [view gotoEnd: nil];
  [view gotoBeginning: nil];
  [[controller valueForKey: @"window"] performClose: nil];
  RunFor(0.3);
  NSCAssert(![view isPlaying] && [view movie] == nil, @"Close cancels restarts");
  NSLog(@"Playback control and slow-reader tests passed");
  [pool drain];
  return 0;
}
