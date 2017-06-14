//
//  DefaultLayoutViewController.m
//  PlaybackDemo
//
//  Created by DJI on 16/4/2017.
//  Copyright © 2017 DJI. All rights reserved.
//

#import "DefaultLayoutViewController.h"
#import "DemoUtility.h"

@interface DefaultLayoutViewController ()
@property (weak, nonatomic) IBOutlet UIButton *playbackBtn;

@end

@implementation DefaultLayoutViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if (IS_IPAD) {
        [self.playbackBtn setImage:[UIImage imageNamed:@"playback_icon_iPad"] forState:UIControlStateNormal];
    }else{
        [self.playbackBtn setImage:[UIImage imageNamed:@"playback_icon"] forState:UIControlStateNormal];
    }
}

@end
