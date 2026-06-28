// iOS App Switcher Cover - native Objective-C++ source.
//
// Compiled into ../bin/libAppSwitcherCover.a by build_ios_lib.sh, then linked
// into the iOS export by app_switcher_cover.gd (add_ios_project_static_lib +
// the "-ObjC" linker flag, which is REQUIRED so the linker keeps this otherwise
// unreferenced class and runs its +load).
//
// Why this exists: iOS snapshots the UIKit view hierarchy for the app-switcher
// card, which EXCLUDES a GPU-backed render layer (OpenGL/Metal) - so a Godot
// app's snapshot is the empty window (white). We cover the key window with a
// configured image (or a solid color) on background and remove it on
// foreground, so the card shows the app's brand instead of white.
//
// Configuration is read from the app's Info.plist at runtime (the editor export
// plugin writes these keys from Project Settings - so the prebuilt lib is
// generic and consumers never recompile):
//   GodotIOSAppSwitcherCoverImage       (String)  bundled image filename, e.g. "cover.png"; empty = none
//   GodotIOSAppSwitcherCoverBackground  (String)  "#RRGGBB"; default black
//   GodotIOSAppSwitcherCoverScaleMode   (String)  "fill" | "fit"; default fill
//
// Self-contained: touches only UIKit + Foundation, never Godot. Registers
// itself at launch via +load.

#import <UIKit/UIKit.h>

@interface HLSAppSwitcherCover : NSObject
@end

@implementation HLSAppSwitcherCover

// Strong (ARC) static ref to the cover while it is on screen.
static UIImageView *hls_cover_view = nil;

+ (void)load {
	// Runs once when the class is loaded (before main()). The notifications fire
	// on the main thread, so the UIKit work in the handlers is main-thread-safe.
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(hls_showCover)
	                                             name:UIApplicationDidEnterBackgroundNotification
	                                           object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
	                                         selector:@selector(hls_hideCover)
	                                             name:UIApplicationWillEnterForegroundNotification
	                                           object:nil];
}

// Parse "#RRGGBB" / "RRGGBB" -> UIColor; black on anything unexpected (so the
// cover is never white by accident).
+ (UIColor *)hls_colorFromHex:(NSString *)hex {
	if (hex == nil) {
		return UIColor.blackColor;
	}
	NSString *s = [hex stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	if ([s hasPrefix:@"#"]) {
		s = [s substringFromIndex:1];
	}
	if (s.length != 6) {
		return UIColor.blackColor;
	}
	unsigned int rgb = 0;
	NSScanner *scanner = [NSScanner scannerWithString:s];
	if (![scanner scanHexInt:&rgb]) {
		return UIColor.blackColor;
	}
	CGFloat r = ((rgb >> 16) & 0xFF) / 255.0;
	CGFloat g = ((rgb >> 8) & 0xFF) / 255.0;
	CGFloat b = (rgb & 0xFF) / 255.0;
	return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

// Find the active key window across the app's connected scenes (iOS 13+ UIScene).
+ (UIWindow *)hls_keyWindow {
	UIWindow *win = nil;
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:[UIWindowScene class]]) {
			continue;
		}
		UIWindowScene *ws = (UIWindowScene *)scene;
		for (UIWindow *w in ws.windows) {
			if (w.isKeyWindow) {
				win = w;
				break;
			}
		}
		if (win == nil && ws.windows.count > 0) {
			win = ws.windows.firstObject;
		}
		if (win != nil) {
			break;
		}
	}
	return win;
}

+ (void)hls_showCover {
	UIWindow *win = [self hls_keyWindow];
	if (win == nil) {
		return;
	}
	if (hls_cover_view != nil) {
		[hls_cover_view removeFromSuperview];
		hls_cover_view = nil;
	}

	NSBundle *bundle = [NSBundle mainBundle];
	NSString *imgName = [bundle objectForInfoDictionaryKey:@"GodotIOSAppSwitcherCoverImage"];
	NSString *bgHex = [bundle objectForInfoDictionaryKey:@"GodotIOSAppSwitcherCoverBackground"];
	NSString *scaleMode = [bundle objectForInfoDictionaryKey:@"GodotIOSAppSwitcherCoverScaleMode"];

	UIImage *img = nil;
	if (imgName != nil && imgName.length > 0) {
		// imgName carries the extension (e.g. "cover.png") -> ofType:nil.
		NSString *path = [bundle pathForResource:imgName ofType:nil];
		if (path != nil) {
			img = [UIImage imageWithContentsOfFile:path];
		}
		if (img == nil) {
			img = [UIImage imageNamed:imgName];
		}
	}

	UIImageView *cover = [[UIImageView alloc] initWithFrame:win.bounds];
	cover.backgroundColor = [self hls_colorFromHex:bgHex];
	cover.contentMode = [scaleMode isEqualToString:@"fit"]
			? UIViewContentModeScaleAspectFit
			: UIViewContentModeScaleAspectFill;
	cover.clipsToBounds = YES;
	cover.image = img;
	cover.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[win addSubview:cover];
	hls_cover_view = cover;
}

+ (void)hls_hideCover {
	if (hls_cover_view != nil) {
		[hls_cover_view removeFromSuperview];
		hls_cover_view = nil;
	}
}

@end
