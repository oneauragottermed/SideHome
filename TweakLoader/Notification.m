//
//  Notification.m
//  LiveContainer
//
//  Created by s s on 2025/7/21.
//

@import UIKit;
#import "UserNotifications/UserNotifications.h"
#import "../LiveContainer/utils.h"
#import "../LiveContainerSwiftUI/SideHome/SideHomeBridge.h"

@interface UNUserNotificationCenter(private)
@property (nonatomic, copy) NSString *bundleIdentifier;
@end

#pragma mark SideHome forwarding

// Guest apps in LiveProcess can't post notifications, ask for permission or play haptics,
// so when SideHome launched us with its XPC endpoint, these calls go to SideHome instead.
static NSObject<SideHomeHostServer> *SideHomeServer(void) {
    return [NSClassFromString(@"SideHomeGuestBridge") server];
}

@interface SHAuthorizedNotificationSettings : UNNotificationSettings
@end
@implementation SHAuthorizedNotificationSettings
- (UNAuthorizationStatus)authorizationStatus {
    return UNAuthorizationStatusAuthorized;
}
@end

@implementation UNUserNotificationCenter(SideHome)
- (void)sh_addNotificationRequest:(UNNotificationRequest *)request withCompletionHandler:(void (^)(NSError *error))completionHandler {
    [SideHomeServer() postNotificationRequest:request fromApp:NSUserDefaults.lcGuestAppId];
    if (completionHandler) completionHandler(nil);
}

- (void)sh_removePendingNotificationRequestsWithIdentifiers:(NSArray<NSString *> *)identifiers {
    [SideHomeServer() removePendingNotificationRequestsWithIdentifiers:identifiers];
}

- (void)sh_requestAuthorizationWithOptions:(UNAuthorizationOptions)options completionHandler:(void (^)(BOOL granted, NSError *error))completionHandler {
    [SideHomeServer() requestNotificationAuthorizationWithOptions:options reply:^(BOOL granted) {
        if (completionHandler) completionHandler(granted, nil);
    }];
}

- (void)sh_getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *settings))completionHandler {
    if (completionHandler) completionHandler(class_createInstance(SHAuthorizedNotificationSettings.class, 0));
}

- (void)sh_setBadgeCount:(NSInteger)newBadgeCount withCompletionHandler:(void (^)(NSError *error))completionHandler {
    [SideHomeServer() setBadgeCount:newBadgeCount fromApp:NSUserDefaults.lcGuestAppId];
    if (completionHandler) completionHandler(nil);
}
@end

@implementation UIApplication(SideHome)
- (void)sh_setApplicationIconBadgeNumber:(NSInteger)number {
    [SideHomeServer() setBadgeCount:number fromApp:NSUserDefaults.lcGuestAppId];
}
@end

@implementation UINotificationFeedbackGenerator(SideHome)
- (void)sh_notificationOccurred:(UINotificationFeedbackType)notificationType {
    [SideHomeServer() playHapticOfKind:SideHomeHapticKindNotification value:notificationType];
}
@end

@implementation UIImpactFeedbackGenerator(SideHome)
// shortcut: the generator's style is private, so every impact plays as medium
- (void)sh_impactOccurred {
    [SideHomeServer() playHapticOfKind:SideHomeHapticKindImpact value:UIImpactFeedbackStyleMedium];
}
- (void)sh_impactOccurredWithIntensity:(CGFloat)intensity {
    [SideHomeServer() playHapticOfKind:SideHomeHapticKindImpact value:UIImpactFeedbackStyleMedium];
}
@end

@implementation UISelectionFeedbackGenerator(SideHome)
- (void)sh_selectionChanged {
    [SideHomeServer() playHapticOfKind:SideHomeHapticKindSelection value:0];
}
@end

static void SideHomeHooksInit(void) {
    Class center = UNUserNotificationCenter.class;
    swizzle(center, @selector(addNotificationRequest:withCompletionHandler:), @selector(sh_addNotificationRequest:withCompletionHandler:));
    swizzle(center, @selector(removePendingNotificationRequestsWithIdentifiers:), @selector(sh_removePendingNotificationRequestsWithIdentifiers:));
    swizzle(center, @selector(requestAuthorizationWithOptions:completionHandler:), @selector(sh_requestAuthorizationWithOptions:completionHandler:));
    swizzle(center, @selector(getNotificationSettingsWithCompletionHandler:), @selector(sh_getNotificationSettingsWithCompletionHandler:));
    swizzle(center, @selector(setBadgeCount:withCompletionHandler:), @selector(sh_setBadgeCount:withCompletionHandler:));
    swizzle(UIApplication.class, @selector(setApplicationIconBadgeNumber:), @selector(sh_setApplicationIconBadgeNumber:));
    swizzle(UINotificationFeedbackGenerator.class, @selector(notificationOccurred:), @selector(sh_notificationOccurred:));
    swizzle(UIImpactFeedbackGenerator.class, @selector(impactOccurred), @selector(sh_impactOccurred));
    swizzle(UIImpactFeedbackGenerator.class, @selector(impactOccurredWithIntensity:), @selector(sh_impactOccurredWithIntensity:));
    swizzle(UISelectionFeedbackGenerator.class, @selector(selectionChanged), @selector(sh_selectionChanged));
}

__attribute__((constructor))
static void UNHooksInit(void) {
    if(!NSUserDefaults.lcGuestAppId) return;
    if(!NSUserDefaults.isSideStore && SideHomeServer()) {
        SideHomeHooksInit();
        return;
    }
    if([NSUserDefaults.guestAppInfo[@"fixLocalNotification"] boolValue] || NSUserDefaults.isSideStore) {
        [UNUserNotificationCenter.currentNotificationCenter setBundleIdentifier:[NSUserDefaults.lcMainBundle bundleIdentifier]];
    }
}
