/* 
   Project: VideoPlayer

   Author: Gregory John Casamento,,,

   Created: 2025-06-03 03:09:42 -0400 by heron
   
   Application Controller
*/

#import "AppController.h"

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
  
  [[NSUserDefaults standardUserDefaults] registerDefaults: defaults];
  [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) awakeFromNib
{
  [_volume setFloatValue: 1.0];
  [_info setStringValue: @""];

  [_mediaTable setDelegate: self];
  [_mediaTable setDataSource: self];
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
	  NSURL *url = [NSURL fileURLWithPath: filename];

	  if (url != nil)
	    {
	      NSMovie *movie = [[NSMovie alloc] initWithURL: url byReference: NO]; 
	      NSRect frame = NSZeroRect;
	      
	      [_movieView setMovie: movie];
	      [_movieView start: sender];
	      frame = [_movieView movieRect];

	      // Resize and show the window...
	      [_window setContentSize: frame.size];
	      [_window makeKeyAndOrderFront: sender];
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
  return 0;
}

- (id)           tableView: (NSTableView *)tv
 objectValueForTableColumn: (NSTableColumn *)tc
		       row: (NSInteger)row
{
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


@end
