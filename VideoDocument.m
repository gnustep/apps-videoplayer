/*
   Project: VideoPlayer

   Document object for opened video files.
*/

#import "VideoDocument.h"
#import "AppController.h"

@implementation VideoDocument

+ (NSArray *) readableTypes
{
  return [NSArray arrayWithObject: @"Video"];
}

+ (NSArray *) writableTypes
{
  return [NSArray array];
}

- (void) dealloc
{
  RELEASE(_videoPath);
  [super dealloc];
}

- (NSString *) videoPath
{
  return _videoPath;
}

- (void) makeWindowControllers
{
}

- (void) showWindows
{
  AppController *controller = (AppController *)[NSApp delegate];

  [super showWindows];

  if (_videoPath != nil
      && [controller respondsToSelector: @selector(openVideoAtPath:sender:)])
    {
      [controller openVideoAtPath: _videoPath sender: self];
    }
}

- (BOOL) readFromFile: (NSString *)fileName ofType: (NSString *)type
{
  BOOL isDirectory = NO;

  if (fileName == nil
      || ![[NSFileManager defaultManager] fileExistsAtPath: fileName
                                               isDirectory: &isDirectory]
      || isDirectory)
    {
      return NO;
    }

  ASSIGN(_videoPath, fileName);
  return YES;
}

- (BOOL) readFromURL: (NSURL *)url ofType: (NSString *)type
{
  if (url == nil || ![url isFileURL])
    {
      return NO;
    }

  return [self readFromFile: [url path] ofType: type];
}

@end
