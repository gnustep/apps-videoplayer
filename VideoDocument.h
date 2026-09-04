/*
   Project: VideoPlayer

   Document object for opened video files.
*/

#ifndef _VIDEOPLAYER_VIDEODOCUMENT_H
#define _VIDEOPLAYER_VIDEODOCUMENT_H

#import <AppKit/AppKit.h>

@interface VideoDocument : NSDocument
{
  NSString *_videoPath;
}

- (NSString *) videoPath;

@end

#endif
