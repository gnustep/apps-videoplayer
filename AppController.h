/* 
   Project: VideoPlayer

   Author: Gregory John Casamento,,,

   Created: 2025-06-03 03:09:42 -0400 by heron
   
   Application Controller
*/
 
#ifndef _PCAPPPROJ_APPCONTROLLER_H
#define _PCAPPPROJ_APPCONTROLLER_H

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface AppController : NSObject <NSTableViewDelegate, NSTableViewDataSource>
{
  IBOutlet NSWindow *_window;
  IBOutlet NSMovieView *_movieView;
  IBOutlet NSPanel *_controlsPanel;
  IBOutlet NSPanel *_mediaPanel;
  IBOutlet NSTableView *_mediaTable;
  IBOutlet NSOutlineView *_playlistOutline;
  IBOutlet NSSlider *_volume;
  IBOutlet NSSwitch *_mute;
  IBOutlet NSTextField *_info;
}

// Class methods...
+ (void)  initialize;

// Notification methods...
- (void) applicationDidFinishLaunching: (NSNotification *)aNotif;
- (BOOL) applicationShouldTerminate: (id)sender;
- (void) applicationWillTerminate: (NSNotification *)aNotif;
- (BOOL) application: (NSApplication *)application
	    openFile: (NSString *)fileName;

// Actions...
- (IBAction) showPrefPanel: (id)sender;
- (IBAction) openFile: (id)sender;
- (IBAction) volume: (id)sender;
- (IBAction) mute: (id)sender;

@end

#endif
