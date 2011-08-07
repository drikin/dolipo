//
//  NSFileManagerDK.h
//  dolipo
//
//  Created by Kohichi Aoki on 08/03/10.
//  Copyright 2008 drikin.com. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSFileManager (SupportPathOperation)

- (NSString*)applicationSupportPath;
- (void)createDirectoryAtSupportPath:(NSString*)pathname;
- (void)copyFileFromResourcePathToSupportPath:(NSString*)name;

@end
