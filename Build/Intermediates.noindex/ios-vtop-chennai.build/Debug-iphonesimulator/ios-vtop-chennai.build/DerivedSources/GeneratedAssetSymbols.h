#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "AppLogoIcon" asset catalog image resource.
static NSString * const ACImageNameAppLogoIcon AC_SWIFT_PRIVATE = @"AppLogoIcon";

/// The "VITConnectIcon" asset catalog image resource.
static NSString * const ACImageNameVITConnectIcon AC_SWIFT_PRIVATE = @"VITConnectIcon";

#undef AC_SWIFT_PRIVATE
