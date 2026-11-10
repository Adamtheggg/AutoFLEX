
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#include <notify.h>
#include <objc/message.h>
#import "FLEXManager.h"

#define AF_SUB @"SuperGrok"
#define AF_MARKER @"X-AF-Stamped"

@interface UIStatusBarWindow : UIWindow @end

__attribute__((visibility("hidden")))
@interface AutoFLEX : NSObject @end

@implementation AutoFLEX
+ (instancetype)sharedInstance {
    static AutoFLEX *s; static dispatch_once_t t;
    dispatch_once(&t, ^{ s = [[self alloc] init]; });
    return s;
}
- (void)inject { [[FLEXManager sharedManager] showExplorer]; }
@end

%hook UIStatusBarWindow
- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    [self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(inject:)]];
    return self;
}
- (void)inject:(UILongPressGestureRecognizer *)g { [[FLEXManager sharedManager] showExplorer]; }
%end

static BOOL AFIsGrok(NSString *host) {
    if (![host isKindOfClass:[NSString class]]) return NO;
    NSString *h = host.lowercaseString;
    return [h hasSuffix:@"grok.com"] || [h hasSuffix:@"x.ai"];
}

// stamp any mutable request for grok hosts
static void AFStamp(id req) {
    if (![req isKindOfClass:[NSMutableURLRequest class]]) return;
    NSMutableURLRequest *m = (NSMutableURLRequest *)req;
    [m setValue:AF_SUB forHTTPHeaderField:@"x-user-subscription"];
    [m setValue:@"1" forHTTPHeaderField:AF_MARKER];
}

// NSURLProtocol catches URLSession traffic the hooks miss
@interface AFProtocol : NSURLProtocol
@property (nonatomic, strong) NSURLSessionDataTask *task;
@end

@implementation AFProtocol
+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if ([NSURLProtocol propertyForKey:AF_MARKER inRequest:request]) return NO;
    if (!AFIsGrok(request.URL.host)) return NO;
    NSString *s = request.URL.scheme.lowercaseString;
    return [s isEqualToString:@"https"] || [s isEqualToString:@"http"];
}
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *m = [request mutableCopy];
    AFStamp(m);
    return m;
}
- (void)startLoading {
    NSMutableURLRequest *m = [self.request mutableCopy];
    AFStamp(m);
    NSURLSession *s = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]];
    __weak typeof(self) w = self;
    self.task = [s dataTaskWithRequest:m completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        __strong typeof(w) s2 = w; if (!s2) return;
        if (e) { [s2.client URLProtocol:s2 didFailWithError:e]; return; }
        [s2.client URLProtocol:s2 didReceiveResponse:r cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        [s2.client URLProtocol:s2 didLoadData:d];
        [s2.client URLProtocolDidFinishLoading:s2];
    }];
    [self.task resume];
}
- (void)stopLoading { [self.task cancel]; }
@end

%hook NSMutableURLRequest
- (void)setValue:(NSString *)v forHTTPHeaderField:(NSString *)f {
    if ([f.lowercaseString isEqualToString:@"x-user-subscription"] && AFIsGrok(self.URL.host)) {
        %orig(AF_SUB, f); return;
    }
    %orig;
}
- (void)addValue:(NSString *)v forHTTPHeaderField:(NSString *)f {
    if ([f.lowercaseString isEqualToString:@"x-user-subscription"] && AFIsGrok(self.URL.host)) {
        %orig(AF_SUB, f); return;
    }
    %orig;
}
- (void)setAllHTTPHeaderFields:(NSDictionary *)d {
    if (AFIsGrok(self.URL.host)) {
        NSMutableDictionary *n = [d mutableCopy] ?: [NSMutableDictionary dictionary];
        n[@"x-user-subscription"] = AF_SUB;
        %orig(n); return;
    }
    %orig;
}
%end

// websocket handshake (chat runs over /ws)
%hook NSMutableURLRequest
- (void)setURL:(NSURL *)u { %orig; if (AFIsGrok(u.host)) AFStamp(self); }
%end

// local profile cache, so the app boots believing it
%hook NSUserDefaults
- (id)objectForKey:(NSString *)k {
    id v = %orig;
    if ([k isEqualToString:@"cachedUserProfile"] && [v isKindOfClass:[NSString class]]) {
        NSString *s = (NSString *)v;
        if ([s containsString:@"\"xSubscriptionType\":\"\""]) {
            return [s stringByReplacingOccurrencesOfString:@"\"xSubscriptionType\":\"\""
                                                withString:@"\"xSubscriptionType\":\"SuperGrok\""];
        }
    }
    return v;
}
%end

%ctor {
    [NSURLProtocol registerClass:objc_getClass("AFProtocol")];
    [[NSNotificationCenter defaultCenter] addObserver:[AutoFLEX sharedInstance]
                                             selector:@selector(inject)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
}
