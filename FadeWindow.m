#import "FadeWindow.h"

@implementation FadeWindow
- (void)superclose
{
	[super close];
}

- (void)close
{
	NSMutableDictionary* dict;
	dict = [NSMutableDictionary dictionary];
	
	NSRect frame;
	frame = [self frame];
	
	[dict setObject:self forKey:NSViewAnimationTargetKey];
	[dict setObject:[NSValue valueWithRect:frame] forKey:NSViewAnimationStartFrameKey];
	
	frame.origin.y-= 20;
	[dict setObject:[NSValue valueWithRect:frame] forKey:NSViewAnimationEndFrameKey];
	
	[dict setValue:NSViewAnimationFadeOutEffect forKey:NSViewAnimationEffectKey];
	
	NSViewAnimation* animation;
	animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:dict]];
	[animation setDuration:0.3];
	[animation setFrameRate:30.0f];
	[animation startAnimation];
	[NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(superclose) userInfo:nil repeats:NO];
}

- (void)show
{
	[self orderOut: self];
	[self center];
	[self setAlphaValue:0.0f];
	[self makeKeyAndOrderFront: self];
	
	NSMutableDictionary* dict;
	dict = [NSMutableDictionary dictionary];
	
	NSRect frame;
	frame = [self frame];
	
	[dict setObject:self forKey:NSViewAnimationTargetKey];
	[dict setObject:[NSValue valueWithRect:frame] forKey:NSViewAnimationStartFrameKey];
	
	frame.origin.y-= 20;
	[dict setObject:[NSValue valueWithRect:frame] forKey:NSViewAnimationEndFrameKey];
	
	[dict setValue:NSViewAnimationFadeInEffect forKey:NSViewAnimationEffectKey];
	
	NSViewAnimation* animation;
	animation = [[NSViewAnimation alloc] initWithViewAnimations:[NSArray arrayWithObject:dict]];
	[animation setDuration:0.3];
	[animation setFrameRate:30.0f];
	[animation startAnimation];
	
	[NSApp activateIgnoringOtherApps: YES];
}
@end
