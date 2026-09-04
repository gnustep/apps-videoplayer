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
- (BOOL) seekToTime: (int64_t)timestamp;
- (void) displayCurrentFrame;
@end

@interface AppController (Private)
- (BOOL) playVideoAtPath: (NSString *)filename sender: (id)sender;
- (BOOL) openVideoDocumentAtPath: (NSString *)filename;
- (BOOL) addPlayedVideoIfNeeded: (NSString *)filename;
- (void) savePlayedVideos;
- (void) reloadPlaylistViews;
- (void) attachControlsPanel;
- (void) reconnectMovieControls;
- (void) replaceMovieViewForNewVideo;
- (void) setButtonIconsInView: (NSView *)view;
- (void) setIconForButton: (NSButton *)button;
- (void) startTimeTimer;
- (void) stopTimeTimer;
- (void) updateTimeLeft: (NSTimer *)timer;
- (void) cacheLengthForCurrentVideoAtPath: (NSString *)filename;
- (int64_t) durationForCurrentVideo;
- (NSString *) lengthStringForVideoAtPath: (NSString *)filename;
- (NSString *) displayValueForVideoAtPath: (NSString *)filename
                             columnIdentifier: (id)identifier;
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
  [_time setStringValue: @""];
  [_timeSlider setMinValue: 0.0];
  [_timeSlider setMaxValue: 1.0];
  [_timeSlider setDoubleValue: 0.0];
  [_timeSlider setTarget: self];
  [_timeSlider setAction: @selector(time:)];
  [_timeSlider setContinuous: NO];
  [self reconnectMovieControls];
  [self setButtonIconsInView: [_controlsPanel contentView]];

  _playedVideos = [[NSMutableArray alloc] init];
  _videoLengths = [[NSMutableDictionary alloc] init];
  _reloadingPlaylistViews = YES;
  while ((object = [enumerator nextObject]) != nil)
    {
      if ([object isKindOfClass: [NSString class]])
        {
          [self addPlayedVideoIfNeeded: object];
        }
    }
  
  [_mediaTable setDelegate: self];
  [_mediaTable setDataSource: self];
  
  [_playlistOutline setDelegate: self];
  [_playlistOutline setDataSource: self];
  [self reloadPlaylistViews];
  [_playlistOutline deselectAll: self];

  // Add icons...
  [_start setImage: [NSImage imageNamed: @"button-start"]];
  [_stepBack setImage: [NSImage imageNamed: @"button-step-back"]];
  [_play setImage: [NSImage imageNamed: @"button-play"]];
  [_stop setImage: [NSImage imageNamed: @"button-stop"]];
  [_stepForward setImage: [NSImage imageNamed: @"button-step-forward"]];
  [_end setImage: [NSImage imageNamed: @"button-end"]];

  [_volumeLevel setFloatValue: 100.0]; // set to 100%. Might get this from defaults later.
  
  [_window setDelegate: self];
  //  [self attachControlsPanel];
}

- (void) dealloc
{
  [self stopTimeTimer];
  RELEASE(_playedVideos);
  RELEASE(_videoLengths);
  [super dealloc];
}

- (void) applicationDidFinishLaunching: (NSNotification *)aNotif
{
  NSImage *icon = [NSImage imageNamed: @"videoplayer.png"];

  // Uncomment if your application is Renaissance-based
  //  [NSBundle loadGSMarkupNamed: @"Main" owner: self];
  if (icon != nil)
    {
      [NSApp setApplicationIconImage: icon];
    }
  [_playlistOutline deselectAll: self];
  _reloadingPlaylistViews = NO;
}

- (void) applicationWillTerminate: (NSNotification *)aNotif
{
}

- (BOOL) application: (NSApplication *)application
	    openFile: (NSString *)fileName
{
  return [self openVideoDocumentAtPath: fileName];
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
          [self openVideoDocumentAtPath: filename];
        }
    }
}

- (IBAction) volume: (id)sender
{
  CGFloat level = [sender floatValue];
  [_movieView setVolume: level];
  [_volumeLevel setIntegerValue: (NSUInteger)(level * 100.00)];
}

- (IBAction) mute: (id)sender
{
  [_movieView setMuted: [sender state] == NSOnState ? YES : NO];
}

- (IBAction) time: (id)sender
{
  int64_t duration = [self durationForCurrentVideo];
  double position = [_timeSlider doubleValue];
  int64_t timestamp = 0;
  BOOL wasPlaying = [_movieView isPlaying];
  BOOL didSeek = NO;

  if (_seekingWithTimeSlider)
    {
      return;
    }

  if (duration <= 0 || [_movieView movie] == nil)
    {
      [_timeSlider setDoubleValue: 0.0];
      [self updateTimeLeft: nil];
      return;
    }

  if (position < 0.0)
    {
      position = 0.0;
    }
  else if (position > 1.0)
    {
      position = 1.0;
    }

  timestamp = (int64_t)((double)duration * position);
  _seekingWithTimeSlider = YES;
  [NSObject cancelPreviousPerformRequestsWithTarget: _movieView];
  if ([_movieView respondsToSelector: @selector(seekToTime:)])
    {
      didSeek = [_movieView seekToTime: timestamp];
      if (didSeek)
        {
          if ([_movieView respondsToSelector: @selector(displayCurrentFrame)])
            {
              [_movieView displayCurrentFrame];
            }
          if (wasPlaying)
            {
              [_movieView performSelector: @selector(start:)
                               withObject: sender
                               afterDelay: 0.1];
            }
        }
    }
  _seekingWithTimeSlider = NO;

  [self updateTimeLeft: nil];
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
          return [self displayValueForVideoAtPath: fullPath
                                 columnIdentifier: [tc identifier]];
        }
      else if ([[tc identifier] isEqualToString: @"column2"])
        {
          NSString *fullPath = [_playedVideos objectAtIndex: row];
          return [self displayValueForVideoAtPath: fullPath
                                 columnIdentifier: [tc identifier]];
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

// Delegate (TableView)

- (BOOL) tableView: (NSTableView *)tv
  shouldSelectRow: (NSInteger)row
{
  return YES;
}

// DataSource NSOutlineView

- (id) outlineView: (NSOutlineView *)ov
	     child: (NSInteger)c
	    ofItem: (id)item
{
  if (item == nil && c >= 0 && c < [_playedVideos count])
    {
      return [_playedVideos objectAtIndex: c];
    }

  return nil;
}

- (BOOL) outlineView: (NSOutlineView *)ov
    isItemExpandable: (id)item
{
  return NO;
}

- (NSInteger) outlineView: (NSOutlineView *)ov
  numberOfChildrenOfItem: (id)item
{
  if (item == nil)
    {
      return [_playedVideos count];
    }

  return 0;
}

- (id) outlineView: (NSOutlineView *)ov
  objectValueForTableColumn: (NSTableColumn *)tc
  byItem: (id)item
{
  if ([item isKindOfClass: [NSString class]])
    {
      return [self displayValueForVideoAtPath: item
                             columnIdentifier: [tc identifier]];
    }

  return nil;
}

- (id) outlineView: (NSOutlineView *)ov
  persistentObjectForItem: (id)item
{
  if ([item isKindOfClass: [NSString class]])
    {
      return item;
    }

  return nil;
}

- (id) outlineView: (NSOutlineView *)ov
  itemForPersistentObject: (id)object
{
  if ([object isKindOfClass: [NSString class]]
      && [_playedVideos containsObject: object])
    {
      return object;
    }

  return nil;
}

- (void) outlineView: (NSOutlineView *)ov
      setObjectValue: (id)object
      forTableColumn: (NSTableColumn *)tc
              byItem: (id)item
{
  // Playlist entries are managed by opening files.
}

- (BOOL) outlineView: (NSOutlineView *)ov
          acceptDrop: (id <NSDraggingInfo>)info
                item: (id)item
          childIndex: (NSInteger)index
{
  return NO;
}

- (NSDragOperation) outlineView: (NSOutlineView *)ov
                   validateDrop: (id <NSDraggingInfo>)info
                   proposedItem: (id)item
             proposedChildIndex: (NSInteger)index
{
  return NSDragOperationNone;
}

- (BOOL) outlineView: (NSOutlineView *)ov
          writeItems: (NSArray *)items
        toPasteboard: (NSPasteboard *)pboard
{
  return NO;
}

- (void) outlineView: (NSOutlineView *)ov
  sortDescriptorsDidChange: (NSArray *)oldSortDescriptors
{
}

- (NSArray *) outlineView: (NSOutlineView *)ov
namesOfPromisedFilesDroppedAtDestination: (NSURL *)dropDestination
          forDraggedItems: (NSArray *)items
{
  return nil;
}

// Delegate NSOutlineView

- (BOOL) outlineView: (NSOutlineView *)ov
    shouldSelectItem: (id)item
{
  return [item isKindOfClass: [NSString class]];
}

- (void) outlineViewColumnDidMove: (NSNotification *)notification
{
}

- (void) outlineViewColumnDidResize: (NSNotification *)notification
{
}

- (void) outlineViewItemDidCollapse: (NSNotification *)notification
{
}

- (void) outlineViewItemDidExpand: (NSNotification *)notification
{
}

- (void) outlineViewItemWillCollapse: (NSNotification *)notification
{
}

- (void) outlineViewItemWillExpand: (NSNotification *)notification
{
}

- (void) outlineViewSelectionDidChange: (NSNotification *)notification
{
  NSOutlineView *outlineView = [notification object];
  NSInteger row = [outlineView selectedRow];

  if (_reloadingPlaylistViews)
    {
      return;
    }

  if (row >= 0)
    {
      id item = [outlineView itemAtRow: row];

      if ([item isKindOfClass: [NSString class]])
        {
          [self openVideoDocumentAtPath: item];
        }
    }
}

- (void) outlineViewSelectionIsChanging: (NSNotification *)notification
{
}

- (BOOL) outlineView: (NSOutlineView *)ov
  shouldCollapseItem: (id)item
{
  return NO;
}

- (BOOL) outlineView: (NSOutlineView *)ov
shouldEditTableColumn: (NSTableColumn *)tc
                item: (id)item
{
  return NO;
}

- (BOOL) outlineView: (NSOutlineView *)ov
    shouldExpandItem: (id)item
{
  return NO;
}

- (BOOL) outlineView: (NSOutlineView *)ov
shouldSelectTableColumn: (NSTableColumn *)tc
{
  return YES;
}

- (void) outlineView: (NSOutlineView *)ov
     willDisplayCell: (id)cell
      forTableColumn: (NSTableColumn *)tc
                item: (id)item
{
}

- (NSCell *) outlineView: (NSOutlineView *)ov
  dataCellForTableColumn: (NSTableColumn *)tc
                    item: (id)item
{
  return nil;
}

- (CGFloat) outlineView: (NSOutlineView *)ov
  heightOfRowByItem: (id)item
{
  return [ov rowHeight];
}

- (CGFloat) outlineView: (NSOutlineView *)ov
  sizeToFitWidthOfColumn: (NSInteger)column
{
  return 0.0;
}

- (void) outlineView: (NSOutlineView *)ov
willDisplayOutlineCell: (id)cell
      forTableColumn: (NSTableColumn *)tc
                item: (id)item
{
}

- (BOOL) selectionShouldChangeInOutlineView: (NSOutlineView *)ov
{
  return YES;
}

- (void) outlineView: (NSOutlineView *)ov
 didClickTableColumn: (NSTableColumn *)tc
{
}

- (NSView *) outlineView: (NSOutlineView *)ov
      viewForTableColumn: (NSTableColumn *)tc
                    item: (id)item
{
  return nil;
}

- (NSTableRowView *) outlineView: (NSOutlineView *)ov
                  rowViewForItem: (id)item
{
  return nil;
}

- (void) outlineView: (NSOutlineView *)ov
       didAddRowView: (NSTableRowView *)rowView
              forRow: (NSInteger)rowIndex
{
}

- (void) outlineView: (NSOutlineView *)ov
    didRemoveRowView: (NSTableRowView *)rowView
              forRow: (NSInteger)rowIndex
{
}

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
  NSMovie *movie = nil;
  NSURL *url = nil;

  if (filename == nil)
    {
      return NO;
    }

  [NSObject cancelPreviousPerformRequestsWithTarget: _movieView];
  [self stopTimeTimer];
  [self replaceMovieViewForNewVideo];
  [_time setStringValue: @""];
  [_timeSlider setDoubleValue: 0.0];

  url = [NSURL fileURLWithPath: filename];

  if (url != nil)
    {
      movie = [[NSMovie alloc] initWithURL: url byReference: NO]; 

      if (movie != nil)
        {
          NSRect frame = NSZeroRect;

          [_movieView setMovie: movie];
          RELEASE(movie);
          [_movieView start: sender];
          [self startTimeTimer];
          [self updateTimeLeft: nil];
          frame = [_movieView movieRect];

          // Resize and show the window...
          if (frame.size.width > 0 && frame.size.height > 0)
            {
              [_window setContentSize: frame.size];
            }
          [_window makeKeyAndOrderFront: sender];
          [_controlsPanel orderFront: sender];
          [self cacheLengthForCurrentVideoAtPath: filename];

          return YES;
        }
    }

  return NO;
}

- (BOOL) openVideoAtPath: (NSString *)filename sender: (id)sender
{
  if ([self playVideoAtPath: filename sender: sender])
    {
      if ([self addPlayedVideoIfNeeded: filename])
        {
          [self savePlayedVideos];
          [self reloadPlaylistViews];
        }

      return YES;
    }

  return NO;
}

- (BOOL) openVideoDocumentAtPath: (NSString *)filename
{
  NSDocument *document = nil;

  if (filename == nil)
    {
      return NO;
    }

  document =
    [[NSDocumentController sharedDocumentController]
      openDocumentWithContentsOfFile: filename
                              display: YES];

  return document != nil;
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

- (void) reloadPlaylistViews
{
  BOOL wasReloadingPlaylistViews = _reloadingPlaylistViews;

  _reloadingPlaylistViews = YES;
  [_mediaTable reloadData];
  [_playlistOutline reloadData];
  _reloadingPlaylistViews = wasReloadingPlaylistViews;
}

- (void) reconnectMovieControls
{
  [_start setTarget: _movieView];
  [_start setAction: @selector(gotoBeginning:)];
  [_stepBack setTarget: _movieView];
  [_stepBack setAction: @selector(stepBack:)];
  [_play setTarget: _movieView];
  [_play setAction: @selector(start:)];
  [_stop setTarget: _movieView];
  [_stop setAction: @selector(stop:)];
  [_stepForward setTarget: _movieView];
  [_stepForward setAction: @selector(stepForward:)];
  [_end setTarget: _movieView];
  [_end setAction: @selector(gotoEnd:)];
}

- (void) replaceMovieViewForNewVideo
{
  NSMovieView *oldMovieView = _movieView;
  NSMovieView *newMovieView = nil;
  NSView *superview = nil;
  NSRect frame = NSZeroRect;
  NSUInteger autoresizingMask = 0;

  if (oldMovieView == nil)
    {
      return;
    }

  [NSObject cancelPreviousPerformRequestsWithTarget: oldMovieView];
  [oldMovieView stop: self];

  superview = [oldMovieView superview];
  if (superview == nil)
    {
      return;
    }

  frame = [oldMovieView frame];
  autoresizingMask = [oldMovieView autoresizingMask];

  newMovieView = [[NSMovieView alloc] initWithFrame: frame];
  [newMovieView setAutoresizingMask: autoresizingMask];
  [newMovieView setVolume: [_volume floatValue]];
  [newMovieView setMuted: [_mute state] == NSOnState ? YES : NO];

  [superview replaceSubview: oldMovieView
                       with: newMovieView];

  _movieView = newMovieView;
  [self reconnectMovieControls];
  RELEASE(newMovieView);
}

- (void) attachControlsPanel
{
  NSRect windowFrame;
  NSRect controlsFrame;

  if (_window == nil || _controlsPanel == nil)
    {
      return;
    }

  windowFrame = [_window frame];
  controlsFrame = [_controlsPanel frame];
  controlsFrame.origin.x =
    NSMinX(windowFrame) + ((NSWidth(windowFrame) - NSWidth(controlsFrame)) / 2.0);
  controlsFrame.origin.y = NSMinY(windowFrame) - NSHeight(controlsFrame);
  [_controlsPanel setFrame: controlsFrame display: NO];
  // [_window addChildWindow: _controlsPanel ordered: NSWindowBelow];
  [_controlsPanel orderOut: self];
}

- (void) setButtonIconsInView: (NSView *)view
{
  NSEnumerator *enumerator = [[view subviews] objectEnumerator];
  NSView *subview = nil;

  if ([view isKindOfClass: [NSButton class]])
    {
      [self setIconForButton: (NSButton *)view];
    }

  while ((subview = [enumerator nextObject]) != nil)
    {
      [self setButtonIconsInView: subview];
    }
}

- (void) setIconForButton: (NSButton *)button
{
  SEL action = [button action];
  NSString *imageName = nil;
  NSImage *image = nil;

  if (action == @selector(gotoBeginning:))
    {
      imageName = @"button-start.png";
    }
  else if (action == @selector(stepBack:))
    {
      imageName = @"button-step-back.png";
    }
  else if (action == @selector(start:))
    {
      imageName = @"button-play.png";
    }
  else if (action == @selector(stepForward:))
    {
      imageName = @"button-step-forward.png";
    }
  else if (action == @selector(gotoEnd:))
    {
      imageName = @"button-end.png";
    }

  if (imageName == nil)
    {
      return;
    }

  image = [NSImage imageNamed: imageName];
  if (image != nil)
    {
      [button setImage: image];
      [button setImagePosition: NSImageOnly];
    }
}

- (void) startTimeTimer
{
  if (_timeTimer != nil)
    {
      return;
    }

  _timeTimer = RETAIN([NSTimer scheduledTimerWithTimeInterval: 0.5
                                                       target: self
                                                     selector: @selector(updateTimeLeft:)
                                                     userInfo: nil
                                                      repeats: YES]);
}

- (void) stopTimeTimer
{
  if (_timeTimer != nil)
    {
      [_timeTimer invalidate];
      RELEASE(_timeTimer);
      _timeTimer = nil;
    }
}

- (void) updateTimeLeft: (NSTimer *)timer
{
  int64_t duration = [self durationForCurrentVideo];
  double position = 0.0;
  int64_t remaining = 0;

  if (_seekingWithTimeSlider)
    {
      return;
    }

  if (duration <= 0)
    {
      [_time setStringValue: @""];
      [_timeSlider setDoubleValue: 0.0];
      return;
    }

  if ([_movieView respondsToSelector: @selector(currentPosition)])
    {
      position = [_movieView currentPosition];
    }

  if (position < 0.0)
    {
      position = 0.0;
    }
  else if (position > 1.0)
    {
      position = 1.0;
    }

  remaining = (int64_t)((double)duration * (1.0 - position));
  [_time setStringValue: [self stringFromDuration: remaining]];
  [_timeSlider setDoubleValue: position];

  if (![_movieView isPlaying] && position >= 1.0)
    {
      [self stopTimeTimer];
    }
}

- (void) cacheLengthForCurrentVideoAtPath: (NSString *)filename
{
  NSString *length = @"";

  if (filename == nil)
    {
      return;
    }

  int64_t duration = [self durationForCurrentVideo];

  if (duration > 0)
    {
      length = [self stringFromDuration: duration];
    }

  [_videoLengths setObject: length forKey: filename];
  [self reloadPlaylistViews];
}

- (int64_t) durationForCurrentVideo
{
  if ([_movieView respondsToSelector: @selector(getDuration)])
    {
      return [_movieView getDuration];
    }

  return 0;
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

- (NSString *) displayValueForVideoAtPath: (NSString *)filename
                         columnIdentifier: (id)identifier
{
  if ([identifier isEqualToString: @"column1"])
    {
      return [filename lastPathComponent];
    }
  else if ([identifier isEqualToString: @"column2"])
    {
      return [self lengthStringForVideoAtPath: filename];
    }

  return filename;
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
