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
- (void) reloadPlaylistViews;
- (void) cacheLengthForCurrentVideoAtPath: (NSString *)filename;
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
  if (fileName == nil)
    {
      return NO;
    }

  if ([self playVideoAtPath: fileName sender: application])
    {
      if ([self addPlayedVideoIfNeeded: fileName])
        {
          [self savePlayedVideos];
          [self reloadPlaylistViews];
        }

      return YES;
    }

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
                  [self reloadPlaylistViews];
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
          [self playVideoAtPath: item sender: outlineView];
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
  if (filename == nil)
    {
      return NO;
    }

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

- (void) reloadPlaylistViews
{
  BOOL wasReloadingPlaylistViews = _reloadingPlaylistViews;

  _reloadingPlaylistViews = YES;
  [_mediaTable reloadData];
  [_playlistOutline reloadData];
  _reloadingPlaylistViews = wasReloadingPlaylistViews;
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
  [self reloadPlaylistViews];
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
