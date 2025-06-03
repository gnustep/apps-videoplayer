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

- (id) init
{
  if ((self = [super init]))
    {
    }
  return self;
}

- (void) dealloc
{
  [super dealloc];
}

- (void) awakeFromNib
{
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
  NSModalResponse response = [op runModal];

  [op setAllowedFileTypes: [NSMovie movieUnfilteredFileTypes]];
  if (response == NSModalResponseOK)
    {
      NSString *filename = [op filename];

      if (filename != nil)
	{
	  NSURL *url = [NSURL URLWithString: filename];
	  NSMovie *movie = [[NSMovie alloc] initWithURL: url byReference: YES]; 

	  NSLog(@"filename = %@", filename);
	  [_movieView setMovie: movie];
	  [_movieView start: sender];
	}
    }
}

@end
