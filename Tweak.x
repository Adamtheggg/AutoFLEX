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
	NSLog(@"Openning explorer: %@", [FLEXManager sharedManager]);
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


// ==== SuperGrok header override ====
static NSString *const kAFSubValue = @"SuperGrok";

static BOOL AFIsGrokHost(NSURLRequest *req) {
    NSString *h = req.URL.host.lowercaseString;
    if (!h) return NO;
    return [h hasSuffix:@"grok.com"] || [h hasSuffix:@"x.ai"];
}

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field.lowercaseString isEqualToString:@"x-user-subscription"] && AFIsGrokHost(self)) {
        %orig(kAFSubValue, field);
        return;
    }
    %orig;
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    if (AFIsGrokHost(request) && [request isKindOfClass:[NSMutableURLRequest class]]) {
        [(NSMutableURLRequest *)request setValue:kAFSubValue forHTTPHeaderField:@"x-user-subscription"];
    }
    return %orig;
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    if (AFIsGrokHost(request) && [request isKindOfClass:[NSMutableURLRequest class]]) {
        [(NSMutableURLRequest *)request setValue:kAFSubValue forHTTPHeaderField:@"x-user-subscription"];
    }
    return %orig;
}
%end


// ==== SuperGrok header override v2 ====
static NSString *const kAFSubValue = @"SuperGrok";

static NSMutableURLRequest *AFMint(NSURLRequest *req) {
    if (![req isKindOfClass:[NSURLRequest class]]) return nil;
    NSString *h = req.URL.host.lowercaseString;
    if (!h) return nil;
    if (![h hasSuffix:@"grok.com"] && ![h hasSuffix:@"x.ai"]) return nil;
    NSMutableURLRequest *m = [req mutableCopy];
    if (![m isKindOfClass:[NSMutableURLRequest class]]) return nil;
    [m setValue:kAFSubValue forHTTPHeaderField:@"x-user-subscription"];
    return m;
}

%hook NSMutableURLRequest
- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field.lowercaseString isEqualToString:@"x-user-subscription"]) {
        NSString *h = self.URL.host.lowercaseString;
        if (h && ([h hasSuffix:@"grok.com"] || [h hasSuffix:@"x.ai"])) {
            %orig(kAFSubValue, field);
            return;
        }
    }
    %orig;
}
- (void)addValue:(NSString *)value forHTTPHeaderField:(NSString *)field {
    if ([field.lowercaseString isEqualToString:@"x-user-subscription"]) {
        NSString *h = self.URL.host.lowercaseString;
        if (h && ([h hasSuffix:@"grok.com"] || [h hasSuffix:@"x.ai"])) {
            %orig(kAFSubValue, field);
            return;
        }
    }
    %orig;
}
%end

%hook NSURLSession
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSMutableURLRequest *m = AFMint(request);
    return %orig(m ?: request);
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler {
    NSMutableURLRequest *m = AFMint(request);
    return %orig(m ?: request, completionHandler);
}
- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id)delegate {
    NSMutableURLRequest *m = AFMint(request);
    return %orig(m ?: request, delegate);
}
%end
