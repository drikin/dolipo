/*
 File:		DolipoController.h
 */

#import <Cocoa/Cocoa.h>
#import <SystemConfiguration/SCDynamicStore.h>
#import <SystemConfiguration/SCSchemaDefinitions.h>
#import "TaskWrapper.h"
#import "FadeWindow.h"
#import "NTLoginItemMgr.h"

//we conform to the ProcessController protocol, as defined in Process.h
@interface DolipoController : NSObject <TaskWrapperController>
{
	// StatusItem instance
	NSStatusItem *sbItem;	
	
	IBOutlet id prefWindow;
	IBOutlet id alertPanel;
	IBOutlet id sbMenu;
	IBOutlet NSButton *proxyEnableButton;
	IBOutlet id adblockEnableMenu;
	IBOutlet id pmmEnableMenu;
	IBOutlet id proxyTextField;
    IBOutlet id portTextField;
	IBOutlet id maximumCacheSizeField;
	IBOutlet id startAtLoginMenuItem;
	NSTask* polipoTask;
	BOOL firstRun;
}
- (IBAction)run:(id)sender;
- (IBAction)trim:(id)sender;
- (IBAction)restart:(id)sender;
- (IBAction)test:(id)sender;

- (IBAction)openNetworkPreference:(id)sender;
- (IBAction)openPolipoConfig:(id)sender;
- (IBAction)openPreference:(id)sender;
- (IBAction)startAtLogin:(id)sender;

- (void)kill;
- (void)watchForNetworkChanges;

@end
