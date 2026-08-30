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

@interface AppController : NSObject <NSTableViewDelegate, NSTableViewDataSource, NSWindowDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource>
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
  IBOutlet NSTextField *_time;
  IBOutlet NSSlider *_timeSlider;

  IBOutlet NSButton *_start;
  IBOutlet NSButton *_stepBack;
  IBOutlet NSButton *_play;
  IBOutlet NSButton *_stop;
  IBOutlet NSButton *_stepForward;
  IBOutlet NSButton *_end;
  IBOutlet NSTextField *_volumeLevel;
  
  NSMutableArray *_playedVideos;
  NSMutableDictionary *_videoLengths;
  NSTimer *_timeTimer;
  BOOL _reloadingPlaylistViews;
  BOOL _seekingWithTimeSlider;
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
- (IBAction) time: (id)sender;

@end

#endif
