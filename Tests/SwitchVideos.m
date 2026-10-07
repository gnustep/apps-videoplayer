#import "AppController.h"
#import <math.h>

// Exercise the actual Gorm view and installed playback backend, including
// queued frame callbacks that can outlive a switch to another movie.
int main(int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSCAssert(argc == 3, @"Expected two video paths");
  [NSApplication sharedApplication];
  NSString *path = [[[NSFileManager defaultManager] currentDirectoryPath]
    stringByAppendingPathComponent: @"Resources/VideoPlayer.gorm"];
  NSCAssert([NSBundle loadNibFile: path externalNameTable: @{NSNibOwner: NSApp}
                       withZone: NSDefaultMallocZone()], @"Load interface");
  AppController *controller = [NSApp delegate];
  [controller applicationDidFinishLaunching: nil];
  NSMovieView *view = [controller valueForKey: @"movieView"];
  NSSlider *volume = [controller valueForKey: @"volume"];
  id mute = [controller valueForKey: @"mute"];
  [volume setFloatValue: 0.25];

  for (int i = 0; i < 12; i++)
    {
      [mute setState: i % 2 ? NSOnState : NSOffState];
      NSCAssert([controller openVideoAtPath:
        [NSString stringWithUTF8String: argv[1 + i % 2]] sender: nil], @"Open video");
      NSCAssert([controller valueForKey: @"movieView"] == view, @"Reuse backend");
      NSCAssert(fabs([view volume] - 0.25) < 0.001, @"Keep volume");
      NSCAssert([view isMuted] == (i % 2 != 0), @"Keep mute state");
      for (NSString *key in @[@"start", @"stepBack", @"play", @"stop", @"stepForward", @"end"])
        NSCAssert([[controller valueForKey: key] target] == view, @"Keep controls connected");
      [[NSRunLoop currentRunLoop] runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow: 0.3]];
      if (i % 3 == 1)
        [view stop: nil]; // Also switch from paused playback.
    }
  NSWindow *window = [controller valueForKey: @"window"];
  for (int i = 0; i < 3; i++)
    {
      NSCAssert([controller openVideoAtPath:
        [NSString stringWithUTF8String: argv[1]] sender: nil], @"Reopen audio video");
      NSCAssert([window isVisible] && [view isPlaying], @"Reopen starts playback");
      if (i == 1)
        [view stop: nil];
      if (i == 2)
        {
          [[controller valueForKey: @"timeSlider"] setDoubleValue: 0.5];
          [controller time: nil]; // Close while a seek restart is pending.
        }
      [window performClose: nil];
      NSCAssert(![window isVisible], @"Video window closes");
      NSCAssert(![view isPlaying] && [view movie] == nil, @"Close unloads playback");
      NSCAssert([controller valueForKey: @"timeTimer"] == nil, @"Close stops timer");
      NSCAssert([[[controller valueForKey: @"info"] stringValue] length] == 0
        && [[[controller valueForKey: @"time"] stringValue] length] == 0,
        @"Close clears labels");
      NSCAssert([[controller valueForKey: @"timeSlider"] doubleValue] == 0.0,
        @"Close resets position");
      [[NSRunLoop currentRunLoop] runUntilDate:
        [NSDate dateWithTimeIntervalSinceNow: 0.3]];
      NSCAssert(![view isPlaying], @"Queued callbacks do not restart playback");
    }
  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  [view setMovie: nil];
  NSLog(@"Video switching and window closing tests passed");
  [pool drain];
  return 0;
}
