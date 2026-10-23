//
//  SideHomeBridge.h
//  SideHome
//
//  Guest apps run inside the LiveProcess extension, which iOS doesn't let post notifications,
//  prompt for permission or play haptics. SideHome passes an XPC endpoint to LiveProcess
//  ("sideHomeEndpoint" in the extension item) and TweakLoader forwards those calls through it.
//

#import <Foundation/Foundation.h>
#import <UserNotifications/UserNotifications.h>

NS_ASSUME_NONNULL_BEGIN

/// Haptic kinds for -playHapticOfKind:value:
typedef NS_ENUM(NSInteger, SideHomeHapticKind) {
    SideHomeHapticKindNotification = 0, // value is a UINotificationFeedbackType
    SideHomeHapticKindImpact = 1,       // value is a UIImpactFeedbackStyle
    SideHomeHapticKindSelection = 2,
};

/// Implemented by the SideHome app, called from guest apps.
@protocol SideHomeHostServer
- (void)postNotificationRequest:(UNNotificationRequest *)request fromApp:(NSString *)bundleId NS_SWIFT_NAME(post(_:fromApp:));
- (void)removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString *> *)identifiers NS_SWIFT_NAME(removePending(_:));
- (void)requestNotificationAuthorizationWithOptions:(NSUInteger)options reply:(void (^)(BOOL granted))reply NS_SWIFT_NAME(requestAuthorization(_:reply:));
- (void)setBadgeCount:(NSInteger)count fromApp:(NSString *)bundleId NS_SWIFT_NAME(setBadge(_:fromApp:));
- (void)playHapticOfKind:(SideHomeHapticKind)kind value:(NSInteger)value NS_SWIFT_NAME(playHaptic(kind:value:));
/// The guest opened one of its own URL schemes; SideHome delivers it to the guest's scene.
- (void)openURL:(NSString *)url inApp:(NSString *)bundleId NS_SWIFT_NAME(open(_:inApp:));
@end

/// Lives in the LiveProcess executable. TweakLoader looks it up with NSClassFromString.
@interface SideHomeGuestBridge : NSObject
@property (class, nonatomic, strong, nullable) NSObject<SideHomeHostServer> *server;
@end

NS_ASSUME_NONNULL_END
