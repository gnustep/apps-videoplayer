/* 
   Project: VideoPlayer

   Author: Gregory John Casamento,,,

   Created: 2025-06-03 03:09:42 -0400 by heron
   
   Application Controller
*/

#import "AppController.h"

static NSString *PlayedVideosDefaultsKey = @"PlayedVideos";

@interface NSMovieView (VideoPlayerDuration)
- (int64_t) getDuration;
@end

@interface AppController (Private)
- (BOOL) playVideoAtPath: (NSString *)filename sender: (id)sender;
- (BOOL) addPlayedVideoIfNeeded: (NSString *)filename;
- (void) savePlayedVideos;
- (void) cacheLengthForCurrentVideoAtPath: (NSString *)filename;
- (NSString *) lengthStringForVideoAtPath: (NSString *)filename;
- (NSString *) stringFromDuration: (int64_t)duration;
@end

@implementation AppController

+ (void) initialize
{
  NSMutableDictionary *defaults = [NSMutableDictionary dictionary];

  /*
   * Register your app's defaults here by adding objects to the
   * dictionary, eg
   *
   * [defaults setObject:anObject forKey:keyForThatObject];
   *
   */
  [defaults setObject: [NSArray array] forKey: PlayedVideosDefaultsKey];
  
  [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) awakeFromNib
{
  NSArray *playedVideos =
    [[NSUserDefaults standardUserDefaults] arrayForKey: PlayedVideosDefaultsKey];
  NSEnumerator *enumerator = [playedVideos objectEnumerator];
  id object = nil;

  [_volume setFloatValue: 1.0];
  [_info setStringValue: @""];

  _playedVideos = [[NSMutableArray alloc] init];
  _videoLengths = [[NSMutableDictionary alloc] init];
  while ((object = [enumerator nextObject]) != nil)
    {
      if ([object isKindOfClass: [NSString class]])
        {
          [self addPlayedVideoIfNeeded: object];
        }
    }
  
  [_mediaTable setDelegate: self];
  [_mediaTable setDataSource: self];
  
  [_window setDelegate: self];
}

- (void) dealloc
{
  RELEASE(_playedVideos);
  RELEASE(_videoLengths);
  [super dealloc];
}

- (void) applicationDidFinishLaunching: (NSNotification *)aNotif
{
  // Uncomment if your application is Renaissance-based
  //  [NSBundle loadGSMarkupNamed: @"Main" owner: self];
}

- (BOOL) applicationShouldTerminate: (id)sender
{
  return YES;
}

- (void) applicationWillTerminate: (NSNotification *)aNotif
{
}

- (BOOL) application: (NSApplication *)application
	    openFile: (NSString *)fileName
{
  return NO;
}

- (IBAction) showPrefPanel: (id)sender
{
}

- (IBAction) openFile: (id)sender
{
  NSOpenPanel *op = [NSOpenPanel openPanel];
  NSModalResponse response; 

  [op setAllowedFileTypes: [NSMovie movieUnfilteredFileTypes]];
  response = [op runModal];
  if (response == NSModalResponseOK)
    {
      NSString *filename = [op filename];

      if (filename != nil)
	{
	  if ([self playVideoAtPath: filename sender: sender])
	    {
	      if ([self addPlayedVideoIfNeeded: filename])
		{
		  [self savePlayedVideos];
		  [_mediaTable reloadData];
		}
	    }
	}
    }
}

- (IBAction) volume: (id)sender
{
  [_movieView setVolume: [sender floatValue]];
}

- (IBAction) mute: (id)sender
{
  [_movieView setMuted: [sender state] == NSOnState ? YES : NO];
}

// Data Source (TableView)

- (NSInteger) numberOfRowsInTableView: (NSTableView *)tv
{
  return [_playedVideos count];
}

- (id)           tableView: (NSTableView *)tv
 objectValueForTableColumn: (NSTableColumn *)tc
		       row: (NSInteger)row
{
  if (row >= 0 && row < [_playedVideos count])
    {
      if ([[tc identifier] isEqualToString: @"column1"])
        {
          NSString *fullPath = [_playedVideos objectAtIndex: row];
          return [fullPath lastPathComponent];
        }
      else if ([[tc identifier] isEqualToString: @"column2"])
        {
          NSString *fullPath = [_playedVideos objectAtIndex: row];
          return [self lengthStringForVideoAtPath: fullPath];
        }
    }
  return nil;
}

- (void) tableView: (NSTableView *)tv
    setObjectValue: (id)value
    forTableColumn: (NSTableColumn *)tc
	       row: (NSInteger)row
{
  // nothing yet...
}

- (BOOL) tableView: (NSTableView *)tv
  shouldSelectRow: (NSInteger)row
{
  if (row >= 0 && row < [_playedVideos count])
    {
      [self playVideoAtPath: [_playedVideos objectAtIndex: row] sender: tv];
    }

  return YES;
}

// Delegate (TableView)
// Window Delegate

- (NSSize) windowWillResize: (NSWindow *)sender
		     toSize: (NSSize)frameSize
{
  NSMovie *movie = [_movieView movie];
  
  if (movie != nil)
    {
      NSRect movieRect = [_movieView movieRect];
      
      if (movieRect.size.width > 0 && movieRect.size.height > 0)
      	{
      	  CGFloat aspectRatio = movieRect.size.width / movieRect.size.height;
      	  NSRect frame = [_window frame];
      	  NSRect contentRect = [_window contentRectForFrameRect: frame];
      	  
      	  // Calculate new content size
      	  CGFloat newWidth = frameSize.width - (frame.size.width - contentRect.size.width);
      	  CGFloat newHeight = newWidth / aspectRatio;
      	  
      	  // Adjust frame size to maintain aspect ratio
      	  frameSize.height = newHeight + (frame.size.height - contentRect.size.height);
      	}
    }

  return frameSize;
}

- (BOOL) playVideoAtPath: (NSString *)filename sender: (id)sender
{
  NSURL *url = [NSURL fileURLWithPath: filename];

  if (url != nil)
    {
      NSMovie *movie = [[NSMovie alloc] initWithURL: url byReference: NO]; 

      if (movie != nil)
        {
          NSRect frame = NSZeroRect;

          [_movieView setMovie: movie];
          RELEASE(movie);
          [_movieView start: sender];
          frame = [_movieView movieRect];

          // Resize and show the window...
          if (frame.size.width > 0 && frame.size.height > 0)
            {
              [_window setContentSize: frame.size];
            }
          [_window makeKeyAndOrderFront: sender];
          [self cacheLengthForCurrentVideoAtPath: filename];

          return YES;
        }
    }

  return NO;
}

- (BOOL) addPlayedVideoIfNeeded: (NSString *)filename
{
  if (filename == nil || [_playedVideos containsObject: filename])
    {
      return NO;
    }

  [_playedVideos addObject: filename];
  return YES;
}

- (void) savePlayedVideos
{
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

  [defaults setObject: _playedVideos forKey: PlayedVideosDefaultsKey];
  [defaults synchronize];
}

- (void) cacheLengthForCurrentVideoAtPath: (NSString *)filename
{
  NSString *length = @"";

  if (filename == nil)
    {
      return;
    }

  if ([_movieView respondsToSelector: @selector(getDuration)])
    {
      int64_t duration = [_movieView getDuration];

      if (duration > 0)
        {
          length = [self stringFromDuration: duration];
        }
    }

  [_videoLengths setObject: length forKey: filename];
}

- (NSString *) lengthStringForVideoAtPath: (NSString *)filename
{
  NSString *cachedLength = [_videoLengths objectForKey: filename];

  if (cachedLength == nil)
    {
      cachedLength = @"";
    }

  return cachedLength;
}

- (NSString *) stringFromDuration: (int64_t)duration
{
  NSInteger seconds = (NSInteger)((duration + 500000) / 1000000);
  NSInteger hours = seconds / 3600;
  NSInteger minutes = (seconds / 60) % 60;

  seconds = seconds % 60;
  if (hours > 0)
    {
      return [NSString stringWithFormat: @"%ld:%02ld:%02ld",
                       (long)hours, (long)minutes, (long)seconds];
    }

  return [NSString stringWithFormat: @"%ld:%02ld",
                   (long)minutes, (long)seconds];
}

@end
