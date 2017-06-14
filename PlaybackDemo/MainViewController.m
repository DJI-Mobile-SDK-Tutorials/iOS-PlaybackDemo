//
//  ViewController.m
//  PlaybackDemo
//
//  Created by DJI on 15/4/2017.
//  Copyright © 2017 DJI. All rights reserved.
//

#import "MainViewController.h"
#import "DemoUtility.h"

@interface MainViewController ()<DJISDKManagerDelegate>
@property(nonatomic, weak) DJIBaseProduct* product;
@property (weak, nonatomic) IBOutlet UILabel *connectStatusLabel;
@property (weak, nonatomic) IBOutlet UILabel *modelNameLabel;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;

- (IBAction)onConnectButtonClicked:(id)sender;

@end

@implementation MainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //Please enter your App Key in the info.plist file.
    [DJISDKManager registerAppWithDelegate:self];
    [self initUI];
    if(self.product){
        [self updateStatusBasedOn:self.product];
    }
}


- (void)initUI
{
    self.title = @"DJI GEO Demo";
    self.modelNameLabel.hidden = YES;
    //Disable the connect button by default
    [self.connectButton setEnabled:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onConnectButtonClicked:(id)sender {
    
}

-(void) updateStatusBasedOn:(DJIBaseProduct* )newConnectedProduct {
    if (newConnectedProduct){
        self.connectStatusLabel.text = NSLocalizedString(@"Status: Product Connected", @"");
        self.modelNameLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Model: \%@", @""),newConnectedProduct.model];
        self.modelNameLabel.hidden = NO;
        
    }else {
        self.connectStatusLabel.text = NSLocalizedString(@"Status: Product Not Connected", @"");
        self.modelNameLabel.text = NSLocalizedString(@"Model: Unknown", @"");
    }
}

#pragma mark - DJISDKManager Delegate Methods
- (void)appRegisteredWithError:(NSError *)error
{
    if (!error) {

        ShowResult(@"Registration Success");
        [DJISDKManager startConnectionToProduct];
//        [DJISDKManager enableBridgeModeWithBridgeAppIP:@"192.168.8.107"];
        
    }else
    {
        ShowResult([NSString stringWithFormat:@"Registration Error:%@", error]);
        [self.connectButton setEnabled:NO];
    }
    
}

- (void)productConnected:(DJIBaseProduct *)product
{
    if (product) {
        self.product = product;
        [self.connectButton setEnabled:YES];
    }
    
    [self updateStatusBasedOn:product];
}

- (void)productDisconnected
{
    NSString* message = [NSString stringWithFormat:@"Connection lost. Back to root. "];
    
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *backAction = [UIAlertAction actionWithTitle:@"Back" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        if (![self.navigationController.topViewController isKindOfClass:[MainViewController class]]) {
            [self.navigationController popToRootViewControllerAnimated:YES];
        }
    }];
    
    UIAlertController* alertViewController = [UIAlertController alertControllerWithTitle:nil message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertViewController addAction:cancelAction];
    [alertViewController addAction:backAction];
    
    UINavigationController* navController = (UINavigationController*)[[UIApplication sharedApplication] keyWindow].rootViewController;
    [navController presentViewController:alertViewController animated:YES completion:nil];
    
    [self.connectButton setEnabled:NO];
    self.product = nil;
    
    [self updateStatusBasedOn:self.product];
    
}

@end
