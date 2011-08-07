//
//  NTLoginItemMgr.m
//  CocoaTechBase
//
//  Created by sgehrman on Sun Jun 17 2001.
//  Copyright (c) 2001 CocoaTech. All rights reserved.
//

#import "NTLoginItemMgr.h"

@implementation NTLoginItemMgr

+ (NTLoginItemMgr*)sharedInstance;
{
	static NTLoginItemMgr* shared=nil;
	
	if (!shared)
		shared = [[NTLoginItemMgr alloc] init];
	
	return shared;
}

- (id)init;
{
	self = [super init];
	
	// make sure the pref is in sync
	[[NSUserDefaults standardUserDefaults] setBool:[self isLoginItem:[[NSBundle mainBundle] bundlePath]] forKey:kLaunchAfterLogin];	

	// register for changes in the pref so we can do our thing, removing or adding the login item
	[[NSUserDefaultsController sharedUserDefaultsController] addObserver:self
															  forKeyPath:[NSString stringWithFormat:@"values.%@", kLaunchAfterLogin]
																 options:NSKeyValueObservingOptionOld
																 context:NULL];
	
	
	return self;
}

- (void)dealloc;
{
	[[NSUserDefaultsController sharedUserDefaultsController] removeObserver:self forKeyPath:[NSString stringWithFormat:@"values.%@", kLaunchAfterLogin]];

	[super dealloc];
}

- (BOOL)isLoginItem:(NSString*)path;
{
    int loginIndex = [self loginIndex:path];

    return (loginIndex != -1);
}

// returns the index in the login array, returns -1 for not found
- (int)loginIndex:(NSString*)path;
{
    int result = -1;
    NSString *loginwindow = @"loginwindow";
    NSUserDefaults	*u;
    NSDictionary	*d;
    NSDictionary	*e;
    NSMutableArray	*a;

    // get data from user defaults
    // (~/Library/Preferences/loginwindow.plist)

    u = [NSUserDefaults standardUserDefaults];
    d = [u persistentDomainForName:loginwindow];

    if (d)
    {
        a = [d objectForKey:@"AutoLaunchedApplicationDictionary"];
        if (a)
        {
            int i, cnt = [a count];
            for (i=0;i<cnt;i++)
            {
                e = [a objectAtIndex:i];

                if ([[e objectForKey:@"Path"] isEqualToString:path])
                {
                    result = i;
                    break;
                }
            }
        }
    }

    return result;
}

- (void)removeLoginItem:(NSString*)path
{
    NSString *loginwindow = @"loginwindow";
    NSUserDefaults	*u;
    NSDictionary	*d;
    NSDictionary	*e;
    NSArray	*a;

    // get data from user defaults
    // (~/Library/Preferences/loginwindow.plist)

    u = [NSUserDefaults standardUserDefaults];
    d = [u persistentDomainForName:loginwindow];

    if (d)
    {
        a = [d objectForKey:@"AutoLaunchedApplicationDictionary"];
        if (a)
        {
            int i, cnt = [a count];
            for (i=0;i<cnt;i++)
            {
                e = [a objectAtIndex:i];

                if ([[e objectForKey:@"Path"] isEqualToString:path])
                {
                    NSMutableDictionary	*md;
                    NSMutableArray	*ma;

                    // make a mutable copy of a and d, replace a in d and set the new settings
                    ma = [[a mutableCopy] autorelease];
                    md = [[d mutableCopy] autorelease];

                    [ma removeObjectAtIndex:i];
                    [md setObject:ma forKey:@"AutoLaunchedApplicationDictionary"];

                    [u removePersistentDomainForName:loginwindow];
                    [u setPersistentDomain:md forName:loginwindow];
                    [u synchronize];
                    break;
                }
            }
        }
    }
}

- (void)addLoginItem:(NSString*) path hide:(BOOL)hide
{
    NSString *loginwindow = @"loginwindow";
    NSUserDefaults	*u;
    NSMutableDictionary	*d;
    NSDictionary	*e;
    NSMutableArray	*a;

    // first remove existing entry if it exists
    [self removeLoginItem:path];

    // get data from user defaults
    // (~/Library/Preferences/loginwindow.plist)

    u = [NSUserDefaults standardUserDefaults];

    if (!(d = [[u persistentDomainForName:loginwindow] mutableCopy]))
        d = [[NSMutableDictionary alloc] initWithCapacity:1];
    [d autorelease];

    if (!(a = [[d objectForKey:@"AutoLaunchedApplicationDictionary"] mutableCopy]))
        a = [[NSMutableArray alloc] initWithCapacity:1];
    [a autorelease];

    // build entry
    e = [[[NSDictionary alloc] initWithObjectsAndKeys:
        [NSNumber numberWithBool:hide], @"Hide",
        path, @"Path",
        nil] autorelease];

    // add entry
    if (e)
    {
        [a insertObject:e atIndex:[a count]];  // add to end of list
        [d setObject:a forKey:@"AutoLaunchedApplicationDictionary"];
    }

    // update user defaults
    [u removePersistentDomainForName:loginwindow];
    [u setPersistentDomain:d forName:loginwindow];
    [u synchronize];
}

// work around for OS X bug
- (void)reorderLoginItemToEnd:(NSString*)path hide:(BOOL)hide;
{
    int loginIndex = [self loginIndex:path];

    // if first item, remove and add again
    if (loginIndex == 0)
    {
        [self removeLoginItem:path];
        [self addLoginItem:path hide:hide];
    }
}

- (void)observeValueForKeyPath:(NSString *)key
					  ofObject:(id)object 
                        change:(NSDictionary *)change
                       context:(void *)context;
{
	NSString* appPath = [[NSBundle mainBundle] bundlePath];
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:kLaunchAfterLogin])
	{
		if (![self isLoginItem:appPath])
			[self addLoginItem:appPath hide:NO];
	}
	else
	{
		if ([self isLoginItem:appPath])
			[self removeLoginItem:appPath];
	}	
}

@end

