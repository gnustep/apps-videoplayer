#import "AppController.h"
#import <math.h>

@interface AppController (SwitchTesting)
- (void) stopTimeTimer;
@end

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
  [view stop: nil];
  [controller stopTimeTimer];
  [[NSRunLoop currentRunLoop] runUntilDate:
    [NSDate dateWithTimeIntervalSinceNow: 0.1]];
  [view setMovie: nil];
  NSLog(@"Video switching tests passed (12 opens)");
  [pool drain];
  return 0;
}
