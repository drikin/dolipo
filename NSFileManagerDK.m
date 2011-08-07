//
//  NSFileManagerDK.m
//  dolipo
//
//  Created by Kohichi Aoki on 08/03/10.
//  Copyright 2008 drikin.com. All rights reserved.
//

#import "NSFileManagerDK.h"

@implementation NSFileManager (SupportPathOperation)

#pragma mark public
- (NSString*)applicationSupportPath
{
	NSFileManager *fileManager;
    NSString* supportPath = nil;
	
    fileManager = [NSFileManager defaultManager];
	NSString* appname = [[[NSBundle mainBundle] bundleIdentifier] pathExtension];
	
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    supportPath = [basePath stringByAppendingPathComponent:appname];
    if ( ![fileManager fileExistsAtPath:supportPath isDirectory:NULL] ) {
        [fileManager createDirectoryAtPath:supportPath attributes:nil];
    }
	return supportPath;
}

- (void)createDirectoryAtSupportPath:(NSString*)pathname
{
	NSFileManager *fileManager;
	fileManager = [NSFileManager defaultManager];
	
    NSString *supportPath = [self applicationSupportPath];
	NSString* cachePath = [supportPath stringByAppendingPathComponent:pathname];
	if ( ![fileManager fileExistsAtPath:cachePath isDirectory:NULL] ) {
		[fileManager createDirectoryAtPath:cachePath attributes:nil];
	}
	
	return;
}

- (void)copyFileFromResourcePathToSupportPath:(NSString*)name
{
	NSFileManager *fileManager;
	fileManager = [NSFileManager defaultManager];

    NSString *supportPath = [self applicationSupportPath];

	NSString* srcPath = [[NSBundle mainBundle] pathForResource:[name stringByDeletingPathExtension] ofType:[name pathExtension]];
	NSString* distPath = [supportPath stringByAppendingPathComponent:[srcPath lastPathComponent]];
	if ( [fileManager fileExistsAtPath:distPath isDirectory:NULL] ) {
		[fileManager removeFileAtPath:distPath handler:NULL];
	}
	[fileManager copyPath:srcPath toPath:distPath handler:nil];
}



@end
