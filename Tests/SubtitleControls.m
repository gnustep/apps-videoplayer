#import "AppController.h"

@interface AppController (SubtitleTesting)
- (void) createSubtitleControls;
- (void) updateSubtitleControls;
@end

// Non-contiguous indices catch accidental use of dropdown positions as IDs.
@interface SubtitleBackend : NSObject
{
@public
  NSArray *streams;
  int selected;
  BOOL rejectSelection;
}
@end
@implementation SubtitleBackend
- (NSArray *) subtitleStreams { return streams; }
- (int) subtitleStreamIndex { return selected; }
- (BOOL) setSubtitleStreamIndex: (int)index
{
  if (rejectSelection) return NO;
  selected = index;
  return YES;
}
@end

@interface SubtitleControllerTest : AppController
- (void) run;
@end
@implementation SubtitleControllerTest
- (void) run
{
  SubtitleBackend *backend = [SubtitleBackend new];
  NSObject *unsupported = [NSObject new];
  _controlsPanel = [[NSPanel alloc]
    initWithContentRect: NSMakeRect(0, 0, 360, 200)
    styleMask: NSTitledWindowMask backing: NSBackingStoreBuffered defer: NO];
  _movieView = (NSMovieView *)backend;
  [self createSubtitleControls];
  [self updateSubtitleControls];
  NSCAssert(![_subtitles isEnabled] && ![_subtitleStream isEnabled], @"Empty movie");

  backend->streams = @[
    @{@"index": @2, @"title": @"English captions", @"language": @"eng"},
    @{@"index": @5, @"title": @"", @"language": @"fra"}];
  backend->selected = -1;
  [self updateSubtitleControls];
  NSCAssert([_subtitles isEnabled] && [_subtitleStream numberOfItems] == 2, @"Tracks loaded");
  NSCAssert([[_subtitleStream itemTitleAtIndex: 0] rangeOfString: @"English captions (eng)"].location != NSNotFound, @"Metadata");
  [_subtitleStream selectItemAtIndex: 1];
  [self selectSubtitleStream: _subtitleStream];
  NSCAssert(backend->selected == 5 && [_subtitles state] == NSOnState, @"Select stream ID");
  [_subtitles setState: NSOffState];
  [self toggleSubtitles: _subtitles];
  NSCAssert(backend->selected == -1 && [[_subtitleStream selectedItem] tag] == 5, @"Remember disabled stream");
  [_subtitles setState: NSOnState];
  [self toggleSubtitles: _subtitles];
  NSCAssert(backend->selected == 5, @"Restore stream");

  backend->rejectSelection = YES;
  [_subtitleStream selectItemAtIndex: 0];
  [self selectSubtitleStream: _subtitleStream];
  NSCAssert([[_subtitleStream selectedItem] tag] == 5, @"Failed selection restores UI");
  [_subtitles setState: NSOffState];
  [self toggleSubtitles: _subtitles];
  NSCAssert([_subtitles state] == NSOnState, @"Failed disable restores UI");

  backend->streams = @[@{@"index": @3, @"title": @"", @"language": @""}];
  backend->selected = -1;
  [self updateSubtitleControls];
  NSCAssert([_subtitleStream numberOfItems] == 1 && [[_subtitleStream selectedItem] tag] == 3, @"New movie clears old tracks");
  NSCAssert([[_subtitleStream titleOfSelectedItem] isEqual: @"Stream 3"], @"Missing metadata fallback");
  backend->streams = nil;
  [self updateSubtitleControls];
  NSCAssert(![_subtitles isEnabled] && [_subtitles state] == NSOffState, @"No subtitle tracks");
  _movieView = (NSMovieView *)unsupported;
  [self updateSubtitleControls];
  NSCAssert(![_subtitleStream isEnabled], @"Backend without extensions");
  _movieView = nil;
  [_controlsPanel release];
  [backend release];
  [unsupported release];
}
@end

int main(void)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  [NSApplication sharedApplication];
  SubtitleControllerTest *controller = [SubtitleControllerTest new];
  [controller run];
  [controller release];
  // Verify the added row against the real Gorm layout as well.
  NSString *nibPath = [[[NSFileManager defaultManager] currentDirectoryPath]
    stringByAppendingPathComponent: @"Resources/VideoPlayer.gorm"];
  BOOL loaded = [NSBundle loadNibFile: nibPath
    externalNameTable: @{NSNibOwner: NSApp} withZone: NSDefaultMallocZone()];
  NSCAssert(loaded, @"Load application interface");
  AppController *appController = [NSApp delegate];
  NSPanel *panel = [appController valueForKey: @"controlsPanel"];
  NSView *checkbox = [appController valueForKey: @"subtitles"];
  NSView *dropdown = [appController valueForKey: @"subtitleStream"];
  NSCAssert(panel != nil && checkbox != nil && dropdown != nil, @"Subtitle controls created");
  NSRect bounds = [[panel contentView] bounds];
  NSCAssert(NSContainsRect(bounds, [checkbox frame])
    && NSContainsRect(bounds, [dropdown frame]), @"Controls fit panel");
  for (NSView *view in [[panel contentView] subviews])
    if (view != checkbox && view != dropdown)
      NSCAssert(!NSIntersectsRect([view frame], [checkbox frame])
        && !NSIntersectsRect([view frame], [dropdown frame]), @"No overlapping controls");
  NSLog(@"Subtitle control tests passed");
  [pool drain];
  return 0;
}
