//
//  DJIPlaybackMultiSelectViewController.h
//  PlaybackDemo
//
//  Created by DJI on 23/7/15.
//  Copyright (c) 2015 DJI. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DJIPlaybackMultiSelectViewController : UIViewController

@property (copy, nonatomic) void (^selectItemBtnAction)(int index);
@property (copy, nonatomic) void (^swipeGestureAction)(UISwipeGestureRecognizerDirection direction);

@end
