#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "FLTLocalAuthPlugin.h"
#import "FLTLocalAuthPlugin_Test.h"
#import "messages.g.h"

FOUNDATION_EXPORT double local_auth_iosVersionNumber;
FOUNDATION_EXPORT const unsigned char local_auth_iosVersionString[];

