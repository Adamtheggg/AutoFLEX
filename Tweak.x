
#import <dlfcn.h>
#import <UIKit/UIKit.h>
#include <notify.h>
#include <objc/message.h>
#import "FLEXManager.h"

@interface UIStatusBarWindow : UIWindow @end

__attribute__((visibility("hidden")))
@interface AutoFLEX : NSObject {
@private
}
@end

@implementation AutoFLEX

+ (instancetype)sharedInstance
{
    static AutoFLEX *_sharedFactory;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedFactory = [[self alloc] init];
    });
    return _sharedFactory;
}

- (id)init
{
    self = [super init];
    return self;
}

-(void)inject {
    [[FLEXManager sharedManager] showExplorer];
}
@end

%hook UIStatusBarWindow
- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    [self addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(inject:)]];
    return self;
}
-(void) inject: (UILongPressGestureRecognizer*)lges {
    [[FLEXManager sharedManager] showExplorer];
}
%end

%ctor {
    [[NSNotificationCenter defaultCenter] addObserver:[AutoFLEX sharedInstance] selector:@selector(inject) name:UIApplicationDidBecomeActiveNotification object:nil];
}

// ==== diagnostics + subscription header override ====
static NSString *const kAFSubValue = @"SuperGrok";
static int afSetValue, afAddValue, afSetAll, afTask, afTaskBlock, afTaskDelegate;

static BOOL AFIsGrokHostString(NSString *host) {
    if (![host isKindOfClass:[NSString class]]) return NO;
    NSString *h = host.lowercaseString;
    return [h hasSuffix:@"grok.com"] || [h hasSuffix:@"x.ai"];
}

static void AFStamp(NSMutableURLRequest *m) {
    if (![m isKindOfClass:[NSMutableURLRequest class]]) return;
    [m setValue:kAFSubValue forHTTPHeaderField:@"x-user-subscription"];
}

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field.lowercaseString isEqualToString:@"x-user-subscription"] && AFIsGrokHostString(self.URL.host)) {
        if (afSetValue++ < 5) NSLog(@"[AF] setValue hook hit: %@", self.URL.host);
        %orig(kAFSubValue, field);
        return;
    }
    %orig;
}
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field.lowercaseString isEqualToString:@"x-user-subscription"] && AFIsGrokHostString(self.URL.host)) {
        if (afAddValue++ < 5) NSLog(@"[AF] addValue hook hit: %@", self.URL.host);
        %orig(kAFSubValue, field);
        return;
    }
    %orig;
}
- (void)setAllHTTPHeaderFields:(NSDictionary *)fields {
    if (AFIsGrokHostString(self.URL.host)) {
        if (afSetAll++ < 5) NSLog(@"[AF] setAllHTTPHeaderFields hit: %@", self.URL.host);
        NSMutableDictionary *d = [fields mutableCopy] ?: [NSMutableDictionary dictionary];
        d[@"x-user-subscription"] = kAFSubValue;
        %orig(d);
        return;
    }
    %orig;
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (AFIsGrokHostString(request.URL.host)) {
        if (afTask++ < 5) NSLog(@"[AF] dataTask hit: %@", request.URL.host);
        NSMutableURLRequest *m = [request mutableCopy];
        AFStamp(m);
        return %orig(m);
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (AFIsGrokHostString(request.URL.host)) {
        if (afTaskBlock++ < 5) NSLog(@"[AF] dataTaskBlock hit: %@", request.URL.host);
        NSMutableURLRequest *m = [request mutableCopy];
        AFStamp(m);
        return %orig(m, completionHandler);
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    if (AFIsGrokHostString(request.URL.host)) {
        if (afTaskDelegate++ < 5) NSLog(@"[AF] dataTaskDelegate hit: %@", request.URL.host);
        NSMutableURLRequest *m = [request mutableCopy];
        AFStamp(m);
        return %orig(m, delegate);
    }
    return %orig;
}
%end
