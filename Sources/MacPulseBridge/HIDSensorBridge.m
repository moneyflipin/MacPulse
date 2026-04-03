#import "MacPulseBridge.h"

#import <Foundation/Foundation.h>
#import <IOKit/hid/IOHIDDeviceKeys.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <IOKit/hidsystem/IOHIDServiceClient.h>
#import <math.h>

extern IOHIDEventSystemClientRef IOHIDEventSystemClientCreate(CFAllocatorRef allocator);
extern int IOHIDEventSystemClientSetMatching(IOHIDEventSystemClientRef client, CFDictionaryRef match);
extern CFTypeRef IOHIDServiceClientCopyEvent(IOHIDServiceClientRef service, int64_t type, int32_t options, int64_t timestamp);
extern double IOHIDEventGetFloatValue(CFTypeRef event, int32_t field);

#define MP_IOHID_EVENT_FIELD_BASE(type) ((type) << 16)

static const int64_t kMPTemperatureEventType = 15;
static const NSInteger kMPAppleVendorPage = 0xff00;
static const NSInteger kMPAppleVendorTemperatureUsage = 0x0005;

static NSString *MPGroupForProduct(NSString *product) {
    NSString *lowercased = product.lowercaseString;

    if ([lowercased containsString:@"battery"]) {
        return @"battery";
    }
    if ([lowercased containsString:@"pacc"]) {
        return @"cpu_p";
    }
    if ([lowercased containsString:@"eacc"]) {
        return @"cpu_e";
    }
    if ([lowercased containsString:@"gpu"]) {
        return @"gpu";
    }
    if ([lowercased containsString:@"tdie"]) {
        return @"soc";
    }
    if ([lowercased containsString:@"tdev"]) {
        return @"board";
    }
    if ([lowercased containsString:@"pmu"]) {
        return @"power";
    }
    return @"other";
}

CFArrayRef MPHIDCopySensorValues(void) {
    @autoreleasepool {
        IOHIDEventSystemClientRef system = IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        if (!system) {
            return NULL;
        }

        NSDictionary *filter = @{
            @kIOHIDPrimaryUsagePageKey: @(kMPAppleVendorPage),
            @kIOHIDPrimaryUsageKey: @(kMPAppleVendorTemperatureUsage),
        };
        IOHIDEventSystemClientSetMatching(system, (__bridge CFDictionaryRef)filter);

        CFArrayRef services = IOHIDEventSystemClientCopyServices(system);
        if (!services) {
            CFRelease(system);
            return NULL;
        }

        NSMutableArray<NSDictionary *> *result = [NSMutableArray array];
        CFIndex serviceCount = CFArrayGetCount(services);

        for (CFIndex index = 0; index < serviceCount; index++) {
            IOHIDServiceClientRef service = (IOHIDServiceClientRef)CFArrayGetValueAtIndex(services, index);
            NSString *product = CFBridgingRelease(IOHIDServiceClientCopyProperty(service, CFSTR(kIOHIDProductKey)));
            if (product.length == 0) {
                continue;
            }

            CFTypeRef event = IOHIDServiceClientCopyEvent(service, kMPTemperatureEventType, 0, 0);
            if (!event) {
                continue;
            }

            double value = IOHIDEventGetFloatValue(event, MP_IOHID_EVENT_FIELD_BASE(kMPTemperatureEventType));
            CFRelease(event);

            if (!isfinite(value) || value <= 0.0 || value > 140.0) {
                continue;
            }

            [result addObject:@{
                @"rawName": product,
                @"group": MPGroupForProduct(product),
                @"value": @(value),
            }];
        }

        CFRelease(services);
        CFRelease(system);

        return CFBridgingRetain([result copy]);
    }
}
