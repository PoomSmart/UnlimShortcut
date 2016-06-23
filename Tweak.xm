#import "../PS.h"
#import <dlfcn.h>

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

// iOS 9
@interface SBApplication : NSObject
@property(copy, nonatomic) NSArray *staticShortcutItems;
@property(copy, nonatomic) NSArray *dynamicShortcutItems;
@end

@interface SBApplicationShortcutMenu : NSObject
@property(retain, nonatomic) SBApplication *application;
- (BOOL)_canDisplayShortcutItem:(SBSApplicationShortcutItem *)item;
@end

// iOS 10
@interface SBUIAppIconForceTouchControllerDataProvider : NSObject
- (NSArray *)applicationShortcutItems;
@end

@interface SBUIAppIconForceTouchController : NSObject
- (SBSApplicationShortcutItem *)_shareApplicationShortcutItemForDataProvider:(SBUIAppIconForceTouchControllerDataProvider *)provider;
@end

@interface SBUIActionViewLabel : UILabel
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
	rowHeight = val && customLayout ? floatVal(val) : 0.8;
	val = prefs[@"TitleFontSize"];
	titleFontSize = val && customLayout ? floatVal(val) : 0.8;
	val = prefs[@"IconMaxHeight"];
	iconMaxHeight = val && customLayout ? floatVal(val) : 0.8;
	val = prefs[@"ContentWidth"];
	contentWidth = val && customLayout ? floatVal(val) : 0.7;
}

%group iOS10

%hook SBUIAppIconForceTouchController

- (NSArray *)_applicationShortcutItemsForDataProvider:(SBUIAppIconForceTouchControllerDataProvider *)provider
{
	NSMutableArray *items = [[provider applicationShortcutItems].mutableCopy retain];
	SBSApplicationShortcutItem *shareItem = [[self _shareApplicationShortcutItemForDataProvider:provider] retain];
	if (shareItem) {
		[items addObject:shareItem];
		[shareItem release];
	}
	return [items autorelease];
}

+ (NSArray *)filteredApplicationShortcutItemsWithStaticApplicationShortcutItems:(NSMutableArray *)staticItems dynamicApplicationShortcutItems:(NSMutableArray *)dynamicItems
{
	if (!unlimitedShortcut)
		return %orig;
	[staticItems addObjectsFromArray:dynamicItems];
	return staticItems;
}

%end

BOOL override = NO;

%hook NSLayoutConstraint

+ (NSArray *)constraintsWithVisualFormat:(NSString *)format options:(NSLayoutFormatOptions)opts metrics:(NSDictionary *)metrics views:(NSDictionary *)views
{
	if (override) {
		if ([format isEqualToString:@"H:|-(12)-[imageView(35)]-(12)-[textContainer]-(17)-|"])
			return %orig([NSString stringWithFormat:@"H:|-(12)-[imageView(%lf)]-(12)-[textContainer]-(17)-|", (double)(35 * iconMaxHeight)], opts, metrics, views);
	}
	return %orig;
}

%end


%hook SBUIActionView

- (CGSize)intrinsicContentSize
{
	CGSize size = %orig;
	return CGSizeMake(size.width * contentWidth, size.height * rowHeight);
}

- (void)_updateImageViewLayoutConstraints
{
	override = YES;
	%orig;
	override = NO;
}

%end

%hook SBUIActionViewLabel

- (void)setFont:(UIFont *)font
{
	%orig([font fontWithSize:font.pointSize * titleFontSize]);
}

%end

%end

%group preiOS10

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
	if (isiOS10Up) {
		%init(iOS10);
	} else {
		%init(preiOS10);
	}
}