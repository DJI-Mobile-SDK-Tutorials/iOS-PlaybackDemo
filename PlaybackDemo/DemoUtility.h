//
//  DemoUtility.h
//  DJISimulatorDemo
//
//  Created by DJI on 8/6/2016.
//  Copyright © 2016 Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <DJISDK/DJISDK.h>

#define WeakRef(__obj) __weak typeof(self) __obj = self
#define WeakReturn(__obj) if(__obj ==nil)return;

#define RADIAN(x) ((x)*M_PI/180.0)

#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define SCREEN_MAX_LENGTH (MAX(SCREEN_WIDTH, SCREEN_HEIGHT))
#define SCREEN_MIN_LENGTH (MIN(SCREEN_WIDTH, SCREEN_HEIGHT))

#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

#define IS_IPHONE_6P (IS_IPHONE && SCREEN_MAX_LENGTH == 667)
#define IS_IPHONE_6 (IS_IPHONE && SCREEN_MAX_LENGTH == 568)

extern void ShowResult(NSString *format, ...);

@interface DemoUtility : NSObject

+(DJIBaseProduct*) fetchProduct;
+(DJICamera*) fetchCamera;
+(DJIAircraft*) fetchAircraft;
+(DJIFlightController*) fetchFlightController;

@end
