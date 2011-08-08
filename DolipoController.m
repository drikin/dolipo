/*
 File:		DolipoController.m
 */

#import <SystemConfiguration/SystemConfiguration.h>
#import "DolipoController.h"
#import "NSFileManagerDK.h"

@implementation DolipoController

#pragma mark private
- (void)createStatusBar
{
	// create status bar
	// ステータスバー作成
	NSStatusBar *bar = [ NSStatusBar systemStatusBar ];
	// ステータスアイテム作成
	sbItem = [ bar statusItemWithLength : NSVariableStatusItemLength ];
	[sbItem retain ];
	[sbItem setTitle         : @""   ];
	[sbItem setImage         : [ NSImage imageNamed : @"dolipo.tiff" ] ];
	[sbItem setToolTip       : @"dolipo" ];
	[sbItem setHighlightMode : YES       ];
	[sbItem setMenu			 : sbMenu    ];
	[sbItem retain];
	
	return;
}

- (void)confirmProxySetting
{
	// auto input parentProxy from System Preferences
	if ( [[proxyTextField stringValue] isEqualToString:@""] && [[portTextField stringValue] isEqualToString:@""] ) {
		CFDictionaryRef proxyDict = SCDynamicStoreCopyProxies(NULL);
		CFNumberRef enableNum = (CFNumberRef)CFDictionaryGetValue(proxyDict, kSCPropNetProxiesHTTPEnable);
		if ( [(NSNumber*)enableNum intValue] == NSOnState ) {
			CFStringRef hostStr = (CFStringRef)CFDictionaryGetValue(proxyDict, kSCPropNetProxiesHTTPProxy);
			if ( ![(NSString*)hostStr isEqualToString:@"127.0.0.1"] ) {
				[proxyTextField setStringValue:(NSString*)hostStr];
				[proxyEnableButton setState:NSOnState];
			}
			CFNumberRef portNum = (CFNumberRef)CFDictionaryGetValue(proxyDict, kSCPropNetProxiesHTTPPort);
			if ( ![[(NSNumber*)portNum stringValue] isEqualToString:@"8123"] ) {
				[portTextField setStringValue:[(NSNumber*)portNum stringValue]];
			}			
		}
	}
	
	return;
}

#pragma mark public
-(void)awakeFromNib
{	
	firstRun = YES;
    polipoRunning=NO;
    polipoTask=nil;

	[self createStatusBar];

	// trim cache first
	[self trim:self];
	
	// create Cache Directory
	[[NSFileManager defaultManager] createDirectoryAtSupportPath:@"Cache"];
	
	// copy resource files for polipo
	NSArray* copylist = [NSArray arrayWithObjects:	@"ForbiddenDefault", 
													@"Forbidden",
													@"Uncachable",
													@"Config",
													@"proxy.pac",
													nil];
	int i;
	for ( i = 0; i < [copylist count]; i++ ) {
		[[NSFileManager defaultManager] copyFileFromResourcePathToSupportPath:[copylist objectAtIndex:i]];
	}
	
	[self confirmProxySetting];
	[self restart:self];
	
	// callbackの登録 
	[self watchForNetworkChanges];
	
	// schedule trim cache : 60*60*24 sec = 24 hour
	[NSTimer scheduledTimerWithTimeInterval:60*60*24 target:self selector:@selector(trim:) userInfo:nil repeats:YES];
}

#pragma mark Delegate

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	[self kill];
	
	return YES;
}

#pragma mark TaskWrapper

- (void)kill
{
	TaskWrapper* killall = [[TaskWrapper alloc] initWithController:self arguments:[NSArray arrayWithObjects:@"/usr/bin/killall", @"polipo", nil]];
	[killall startProcess];
	[killall release];
	
	if (polipoRunning)
    {
        // This stops the task and calls our callback (-processFinished)
        [polipoTask stopProcess];
        // Release the memory for this wrapper object
        [polipoTask release];
        polipoTask=nil;
    }
}

- (IBAction)restart:(id)sender
{
	NSLog(@"polipo restart");
	[self kill];
	[self run:self];
	return;
}

// This action kicks off a locate search task if we aren't already searching for something,
// or stops the current search if one is already running
- (IBAction)run:(id)sender
{
    if (polipoRunning)
    {
        // This stops the task and calls our callback (-processFinished)
        [polipoTask stopProcess];
        // Release the memory for this wrapper object
        [polipoTask release];
        polipoTask=nil;
        return;
    }
    else
    {
        // If the task is still sitting around from the last run, release it
        if (polipoTask!=nil)
        [polipoTask release];
		
		/* create an Path to polipo file */
		NSBundle* bundle = [NSBundle mainBundle];
		NSString* polipoPath = [bundle pathForResource:@"polipo" ofType:@""];
		
		NSString* proxy;
		if ( [proxyEnableButton state] == NSOnState ) {
			proxy = [[[NSString alloc] initWithFormat:@"parentProxy=%@:%@", [proxyTextField stringValue], [portTextField stringValue]] autorelease];
		} else {
			proxy = @"";
		}
		NSString* forbidden;
		if ( [adblockEnableMenu state] == NSOnState ) {
			forbidden = [[[NSString alloc] initWithFormat:@"forbiddenFile = \"~/Library/Application Support/dolipo/Forbidden\""] autorelease];
		} else {
			forbidden = [[[NSString alloc] initWithFormat:@"forbiddenFile = \"~/Library/Application Support/dolipo/ForbiddenDefault\""] autorelease];
		}
		NSString* pmm;
		if ( [pmmEnableMenu state] == NSOnState ) {
			pmm = [[[NSString alloc] initWithFormat:@"pmmSize=8192"] autorelease];
		} else {
			pmm = @"";
		}
        polipoTask=[[TaskWrapper alloc] initWithController:self arguments:[NSArray arrayWithObjects:polipoPath, @"-c", @"Config", proxy, forbidden, pmm, nil]];
        // kick off the process asynchronously
        [polipoTask startProcess];
		
		if ( firstRun ) {
			if ( ![[NSFileManager defaultManager] fileExistsAtPath:[@"~/Library/Preferences/com.drikin.dolipo.plist" stringByExpandingTildeInPath]] ) {
				//NSLog(@"initial startup");
				// open Network config preference if proxy setting is wrong
				CFDictionaryRef proxyDict = SCDynamicStoreCopyProxies(NULL);
				CFStringRef hostStr = (CFStringRef)CFDictionaryGetValue(proxyDict, kSCPropNetProxiesHTTPProxy);
				CFNumberRef portNum = (CFNumberRef)CFDictionaryGetValue(proxyDict, kSCPropNetProxiesHTTPPort);
				if ( ![(NSString*)hostStr isEqualToString:@"127.0.0.1"] || ![[(NSNumber*)portNum stringValue] isEqualToString:@"8123"] ) {
					[self openNetworkPreference:self];					
				}
			}
			firstRun = NO;
		}
    }
}

- (IBAction)trim:(id)sender
{	
	NSBundle* bundle = [NSBundle mainBundle];
	NSString* trimPath = [bundle pathForResource:@"polipo_trimcache-0.2" ofType:@"py"];
	NSString* maximumCacheSize;
	
	if ( [maximumCacheSizeField intValue] > 0 ) {
		maximumCacheSize = [[maximumCacheSizeField stringValue] stringByAppendingString:@"M"];
	} else {
		maximumCacheSize = @"500M";
	}
	
	TaskWrapper* trimTask=[[TaskWrapper alloc] initWithController:self arguments:[NSArray arrayWithObjects:@"/usr/bin/python", trimPath, @"-v", [[[NSFileManager defaultManager] applicationSupportPath] stringByAppendingPathComponent:@"Cache"], maximumCacheSize, nil]];
	[trimTask startProcess];
}

// This callback is implemented as part of conforming to the ProcessController protocol.
// It will be called whenever there is output from the TaskWrapper.
- (void)appendOutput:(NSString *)output
{
    // add the string (a chunk of the results from locate) to the NSTextView's
    // backing store, in the form of an attributed string
    [[resultsTextField textStorage] appendAttributedString: [[[NSAttributedString alloc]
                             initWithString: output] autorelease]];
    // setup a selector to be called the next time through the event loop to scroll
    // the view to the just pasted text.  We don't want to scroll right now,
    // because of a bug in Mac OS X version 10.1 that causes scrolling in the context
    // of a text storage update to starve the app of events
    [self performSelector:@selector(scrollToVisible:) withObject:nil afterDelay:0.0];
}

// This routine is called after adding new results to the text view's backing store.
// We now need to scroll the NSScrollView in which the NSTextView sits to the part
// that we just added at the end
- (void)scrollToVisible:(id)ignore {
    [resultsTextField scrollRangeToVisible:NSMakeRange([[resultsTextField string] length], 0)];
}

// A callback that gets called when a TaskWrapper is launched, allowing us to do any setup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processStarted
{
    polipoRunning=YES;
    // clear the results
    [resultsTextField setString:@""];
}

// A callback that gets called when a TaskWrapper is completed, allowing us to do any cleanup
// that is needed from the app side.  This method is implemented as a part of conforming
// to the ProcessController protocol.
- (void)processFinished
{
    polipoRunning=NO;
    // change the button's title back for the next search
}

// If the user closes the search window, let's just quit
-(BOOL)windowShouldClose:(id)sender
{
    [NSApp terminate:nil];
    return YES;
}

#pragma mark IBAction

- (IBAction)openNetworkPreference:(id)sender
{
	[[NSWorkspace sharedWorkspace] openFile:@"/System/Library/PreferencePanes/Network.prefPane/"];
	[alertPanel makeKeyAndOrderFront:self];
}

- (IBAction)openPolipoConfig:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[[[NSURL alloc] initWithString:@"http://127.0.0.1:8123/polipo/config?"] autorelease]];
}

- (IBAction)openConsole:(id)sender
{
	[window show];
}

- (IBAction)openPreference:(id)sender
{
	[prefWindow show];
}

- (IBAction)startAtLogin:(id)sender
{
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	NTLoginItemMgr *loginItemMgr;
	loginItemMgr = [[NTLoginItemMgr alloc] init];
	if( [startAtLoginMenuItem state] == NSOnState ){
		[loginItemMgr addLoginItem:bundlePath hide:false];
	}else{	
		[loginItemMgr removeLoginItem:bundlePath];	
	}
}

- (IBAction)test:(id)sender
{
	[[NSWorkspace sharedWorkspace] openURL:[[[NSURL alloc] initWithString:@"http://dolipo.googlecode.com/svn/trunk/sites/dolipo.html"] autorelease]];
}

#pragma mark SCFramework

//	基本方針としては SCDynamicStoreCopyValue を呼び出して結果を分析する。
//	SCDynamicStoreCopyValue のstoreはSCDynamicStoreCreateで作成する。このstoreにcallbackが登録できる。 
//	SCDynamicStoreCopyValue のkeyは呼び出すkeyの文字列 
void networkChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info)
{
	//NSLog(@"changedKeys = %@", (NSArray *)changedKeys);
	[(DolipoController*)info restart:(DolipoController*)info];
}

static SCDynamicStoreRef store = NULL;
static CFRunLoopSourceRef rls;

- (void)watchForNetworkChanges
{
	NSArray *				keys;
	SCDynamicStoreContext	context = { 0, (void *)self, NULL, NULL, NULL };
	
	store = SCDynamicStoreCreate(NULL,
								 CFSTR("watchForNetworkChanges"),						//	@"watchForNetworkChanges"
								 networkChanged,
								 &context);												//	NULLでも良い気がする。
	if (!store) {
		NSLog(@"error = %s", SCErrorString(SCError()));
		return;
	}
	
	//	ここで監視したいサービスを登録する 
	//	global IPv4の変化
	//	サービスごとのIPv4の変化
	//	インターフェースごとのLinkの変化 
	
	NSString *	key;
	key = SCDynamicStoreKeyCreateNetworkGlobalEntity(NULL,
													 kSCDynamicStoreDomainState,
													 kSCEntNetIPv4);
	//NSLog(@"key                        = %@", key);
	keys = [NSArray arrayWithObject:key];
	[key release];
	
	//NSLog(@"keys = %@", (NSArray *)keys);
	
	if (!SCDynamicStoreSetNotificationKeys(store, (CFArrayRef)keys, NULL)) {
		NSLog(@"error = %s", SCErrorString(SCError()));
		CFRelease(store);
		return;
	}
	
	/* add a callback */
	rls = SCDynamicStoreCreateRunLoopSource(NULL, store, 0);
	if (!rls) {
		NSLog(@"error = %s", SCErrorString(SCError()));
		CFRelease(store);
		return;
	}
	CFRunLoopAddSource(CFRunLoopGetCurrent(), rls, kCFRunLoopDefaultMode);
	
	/* closing the session will cancel the notifier so we
	 leave it open until we no longer want any notifications */
	
	return;
}

@end
