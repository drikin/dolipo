//
//  NTLoginItemMgr.h
//  CocoaTechBase
//
//  Created by sgehrman on Sun Jun 17 2001.
//  Copyright (c) 2001 CocoaTech. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#define kLaunchAfterLogin @"kLaunchAfterLogin"

@interface NTLoginItemMgr : NSObject {

}

+ (NTLoginItemMgr*)sharedInstance;

- (BOOL)isLoginItem:(NSString*)path;
- (void)removeLoginItem:(NSString*)path;
- (void)addLoginItem:(NSString*) path hide:(BOOL)hide;

- (void)reorderLoginItemToEnd:(NSString*)path hide:(BOOL)hide;
- (int)loginIndex:(NSString*)path;

@end
