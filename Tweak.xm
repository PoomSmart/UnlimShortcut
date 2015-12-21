#import <Foundation/Foundation.h>

BOOL unlimitedShortcut;
BOOL customLayout;
CGFloat rowHeight;
CGFloat titleFontSize;
CGFloat iconMaxHeight;
CGFloat contentWidth;

#ifdef CGFLOAT_IS_DOUBLE
#define floatVal(num) [num doubleValue]
#else
#define floatVal(num) [num floatValue]
#endif

@interface SBSApplicationShortcutItem : NSObject
@end

@interface SBApplication : NSObject
@property(copy, nonatomic) NSArray *staticShortcutItems;
@property(copy, nonatomic) NSArray *dynamicShortcutItems;
@end

@interface SBApplicationShortcutMenu : NSObject
@property(retain, nonatomic) SBApplication *application;
- (BOOL)_canDisplayShortcutItem:(SBSApplicationShortcutItem *)item;
@end

CFStringRef PreferencesNotification = CFSTR("com.PS.UnlimShortcut.prefs");

static void prefs()
{
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.PS.UnlimShortcut.plist"];
	id val = prefs[@"UnlimitedShortcut"];
	unlimitedShortcut = val ? [val boolValue] : YES;
	val = prefs[@"CustomLayout"];
	customLayout = [val boolValue];
	val = prefs[@"RowHeight"];
	rowHeight = val && customLayout ? floatVal(val) : 1.0;
	val = prefs[@"TitleFontSize"];
	titleFontSize = val && customLayout ? floatVal(val) : 1.0;
	val = prefs[@"IconMaxHeight"];
	iconMaxHeight = val && customLayout ? floatVal(val) : 1.0;
	val = prefs[@"ContentWidth"];
	contentWidth = val && customLayout ? floatVal(val) : 1.0;
}

%hook SBApplicationShortcutMenuItemView

- (void)setIconMaxHeight:(CGFloat)height
{
	%orig(height * iconMaxHeight);
}

- (CGFloat)_titleFontSize
{
	return %orig * titleFontSize;
}

%end

%hook SBApplicationShortcutMenuContentView

- (CGFloat)_rowHeight
{
	return %orig * rowHeight;
}

- (CGFloat)_menuWidth
{
	return %orig * contentWidth;
}

%end

%hook SBApplicationShortcutMenu

- (NSArray *)_shortcutItemsToDisplay
{
	if (!unlimitedShortcut)
		return %orig;
	NSMutableArray *items = [NSMutableArray array];
	for (SBSApplicationShortcutItem *item in self.application.staticShortcutItems) {
		if ([self _canDisplayShortcutItem:item])
			[items addObject:item];
	}
	for (SBSApplicationShortcutItem *item in self.application.dynamicShortcutItems) {
		if ([self _canDisplayShortcutItem:item])
			[items addObject:item];
	}
	return items;
}

%end

static void prefsChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo)
{
	prefs();
}

%ctor
{
	CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), NULL, &prefsChanged, PreferencesNotification, NULL, CFNotificationSuspensionBehaviorCoalesce);
	prefs();
	dlopen("/Library/MobileSubstrate/DynamicLibraries/Apex.dylib", RTLD_LAZY);
	dlopen("/Library/MobileSubstrate/DynamicLibraries/Ghosty.dylib", RTLD_LAZY);
	%init;
}