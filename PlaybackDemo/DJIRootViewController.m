//
//  DJIRootViewController.m
//  PlaybackDemo
//
//  Created by DJI on 20/7/15.
//  Copyright (c) 2015 DJI. All rights reserved.
//

#import "DJIRootViewController.h"
#import <DJISDK/DJISDK.h>
#import <VideoPreviewer/VideoPreviewer.h>
#import "DJIPlaybackMultiSelectViewController.h"

#define WeakRef(__obj) __weak typeof(self) __obj = self
#define WeakReturn(__obj) if(__obj ==nil)return;

#define kDeleteAllSelFileAlertTag 100
#define kDeleteCurrentFileAlertTag 101
#define kDownloadAllSelFileAlertTag 102
#define kDownloadCurrentFileAlertTag 103

#define IS_IPAD (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#define IS_IPHONE (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)

#define SCREEN_WIDTH ([[UIScreen mainScreen] bounds].size.width)
#define SCREEN_HEIGHT ([[UIScreen mainScreen] bounds].size.height)
#define SCREEN_MAX_LENGTH (MAX(SCREEN_WIDTH, SCREEN_HEIGHT))
#define SCREEN_MIN_LENGTH (MIN(SCREEN_WIDTH, SCREEN_HEIGHT))

#define IS_IPHONE_6P (IS_IPHONE && SCREEN_MAX_LENGTH == 667)
#define IS_IPHONE_6 (IS_IPHONE && SCREEN_MAX_LENGTH == 568)


@interface DJIRootViewController ()<DJICameraDelegate, DJISDKManagerDelegate, DJIPlaybackDelegate, DJIBaseProductDelegate>

@property (weak, nonatomic) IBOutlet UIButton *recordBtn;
@property (weak, nonatomic) IBOutlet UISegmentedControl *changeWorkModeSegmentControl;
@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;
@property (weak, nonatomic) IBOutlet UILabel *currentRecordTimeLabel;
@property (nonatomic, strong) IBOutlet UIView* playbackBtnsView;
@property (weak, nonatomic) IBOutlet UIButton *playVideoBtn;
@property (weak, nonatomic) IBOutlet UIView *bottomBarView;
@property (weak, nonatomic) IBOutlet UIButton *selectBtn;
@property (weak, nonatomic) IBOutlet UIButton *selectAllBtn;

@property (strong, nonatomic) DJICameraSystemState* cameraSystemState;
@property (strong, nonatomic) DJICameraPlaybackState* cameraPlaybackState;
@property (strong, nonatomic) DJIPlaybackMultiSelectViewController *playbackMultiSelectVC;
@property (strong, nonatomic) UIAlertView* statusAlertView;
@property (strong, nonatomic) NSMutableData *downloadedImageData;
@property (strong, nonatomic) NSTimer *updateImageDownloadTimer;
@property (strong, nonatomic) NSError *downloadImageError;
@property (strong, nonatomic) NSMutableArray *downloadedImageArray;
@property (assign, nonatomic) BOOL isRecording;
@property (strong, nonatomic) NSString* targetFileName;
@property (assign, nonatomic) long totalFileSize;
@property (assign, nonatomic) long currentDownloadSize;
@property (assign, nonatomic) int downloadedFileCount;
@property (assign, nonatomic) int selectedFileCount;

- (IBAction)captureAction:(id)sender;
- (IBAction)recordAction:(id)sender;
- (IBAction)changeWorkModeAction:(id)sender;

- (IBAction)multiPreviewButtonClicked:(id)sender;
- (IBAction)playVideoBtnAction:(id)sender;
- (IBAction)stopVideoBtnAction:(id)sender;

- (IBAction)selectButtonAction:(id)sender;
- (IBAction)deleteButtonAction:(id)sender;
- (IBAction)downloadButtonAction:(id)sender;
- (IBAction)selectAllBtnAction:(id)sender;

@end

@implementation DJIRootViewController

- (void)viewDidAppear:(BOOL)animated
{
    [super viewWillAppear:animated];

    [[VideoPreviewer instance] setView:self.fpvPreviewView];
    [self registerApp];
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    __weak DJICamera* camera = [self fetchCamera];
    if (camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
    if (camera && camera.playbackManager.delegate == self) {
        [camera.playbackManager setDelegate:nil];
    }
    
    [self cleanVideoPreview];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self initData];
    [self initPlaybackMultiSelectVC];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return NO;
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return UIStatusBarStyleLightContent;
}

#pragma mark Custom Methods

- (void)cleanVideoPreview {
    [[VideoPreviewer instance] unSetView];
    
    if (self.fpvPreviewView != nil) {
        [self.fpvPreviewView removeFromSuperview];
        self.fpvPreviewView = nil;
    }
}

- (DJICamera*) fetchCamera {
    
    if (![DJISDKManager product]) {
        return nil;
    }
    
    if ([[DJISDKManager product] isKindOfClass:[DJIAircraft class]]) {
        return ((DJIAircraft*)[DJISDKManager product]).camera;
    }
    
    return nil;
}

- (void)registerApp
{
    NSString *appKey = @"Please enter your App Key here.";
    [DJISDKManager registerApp:appKey withDelegate:self];
}

- (void)showAlertViewWithTitle:(NSString *)title withMessage:(NSString *)message
{
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark DJISDKManagerDelegate Method

-(void) sdkManagerProductDidChangeFrom:(DJIBaseProduct* _Nullable) oldProduct to:(DJIBaseProduct* _Nullable) newProduct
{
    if (newProduct) {
        [newProduct setDelegate:self];
        DJICamera* camera = [self fetchCamera];
        if (camera != nil) {
            camera.delegate = self;
            camera.playbackManager.delegate = self;
        }
    }

}

- (void)sdkManagerDidRegisterAppWithError:(NSError *)error
{
    NSString* message = @"Register App Successed!";
    if (error) {
        message = @"Register App Failed! Please enter your App Key and check the network.";

    }else
    {
        NSLog(@"registerAppSuccess");
        [DJISDKManager startConnectionToProduct];
        [[VideoPreviewer instance] start];
    }
    
    [self showAlertViewWithTitle:@"Register App" withMessage:message];
}

- (void)initData
{
    self.downloadedImageData = [NSMutableData data];
    self.downloadedImageArray = [NSMutableArray array];
}

- (void)initPlaybackMultiSelectVC
{
    
    NSLog(@"Width: %f, Height: %f", SCREEN_WIDTH, SCREEN_HEIGHT);
    
    if (IS_IPAD) {
        
        self.playbackMultiSelectVC = [[DJIPlaybackMultiSelectViewController alloc] initWithNibName:@"DJIPlaybackMultiSelectViewController_iPad" bundle:[NSBundle mainBundle]];

    }else if (IS_IPHONE_6){

        self.playbackMultiSelectVC = [[DJIPlaybackMultiSelectViewController alloc] initWithNibName:@"DJIPlaybackMultiSelectViewController_iPhone6" bundle:[NSBundle mainBundle]];
        
    }else if (IS_IPHONE_6P){
    
        self.playbackMultiSelectVC = [[DJIPlaybackMultiSelectViewController alloc] initWithNibName:@"DJIPlaybackMultiSelectViewController_iPhone6+" bundle:[NSBundle mainBundle]];
    }
    
    [self.playbackMultiSelectVC.view setFrame:self.view.frame];
    [self.view insertSubview:self.playbackMultiSelectVC.view aboveSubview:self.fpvPreviewView];
    
    WeakRef(target);
    [self.playbackMultiSelectVC setSelectItemBtnAction:^(int index) {

        WeakReturn(target);
        __weak DJICamera* camera = [target fetchCamera];

        if (target.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesPreview) {
            [camera.playbackManager enterSinglePreviewModeWithIndex:index];
        }else if (target.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit){
            [camera.playbackManager toggleFileSelectionAtIndex:index];
        }
        
    }];
    
    [self.playbackMultiSelectVC setSwipeGestureAction:^(UISwipeGestureRecognizerDirection direction) {
        
        WeakReturn(target);
        __weak DJICamera* camera = [target fetchCamera];

        if (target.cameraPlaybackState.playbackMode == DJICameraPlaybackModeSingleFilePreview) {
            
            if (direction == UISwipeGestureRecognizerDirectionLeft) {
                [camera.playbackManager goToNextSinglePreviewPage];
            }else if (direction == UISwipeGestureRecognizerDirectionRight){
                [camera.playbackManager goToPreviousSinglePreviewPage];
            }
            
        }else if(target.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesPreview){
            
            if (direction == UISwipeGestureRecognizerDirectionUp) {
                [camera.playbackManager goToNextMultiplePreviewPage];
            }else if (direction == UISwipeGestureRecognizerDirectionDown){
                [camera.playbackManager goToPreviousMultiplePreviewPage];
            }
            
        }
        
    }];

}

- (NSString *)formattingSeconds:(int)seconds
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSString *formattedTimeString = [formatter stringFromDate:date];
    return formattedTimeString;
}

#pragma mark - DJICameraDelegate
- (void)camera:(DJICamera *)camera didReceiveVideoData:(uint8_t *)videoBuffer length:(size_t)size
{
    [[VideoPreviewer instance] push:videoBuffer length:(int)size];
}

- (void)camera:(DJICamera *)camera didUpdateSystemState:(DJICameraSystemState *)systemState
{
    self.cameraSystemState = systemState;

    //Update currentRecordTimeLabel State
    self.isRecording = systemState.isRecording;
    [self.currentRecordTimeLabel setHidden:!self.isRecording];
    [self.currentRecordTimeLabel setText:[self formattingSeconds:systemState.currentVideoRecordingTimeInSeconds]];
    
    //Update playbackBtnsView state
    
    BOOL isPlayback = (systemState.mode == DJICameraModePlayback) || (systemState.mode == DJICameraModeMediaDownload);
    self.playbackBtnsView.hidden = !isPlayback;
    
    //Update recordBtn State
    if (self.isRecording) {
        [self.recordBtn setTitle:@"Stop Record" forState:UIControlStateNormal];
    }else
    {
        [self.recordBtn setTitle:@"Start Record" forState:UIControlStateNormal];
    }
    
    //Update UISegmented Control's state
    if (systemState.mode == DJICameraModeShootPhoto) {
        [self.changeWorkModeSegmentControl setSelectedSegmentIndex:0];
    }else if (systemState.mode == DJICameraModeRecordVideo){
        [self.changeWorkModeSegmentControl setSelectedSegmentIndex:1];
    }else if (systemState.mode == DJICameraModePlayback){
        [self.changeWorkModeSegmentControl setSelectedSegmentIndex:2];
    }
}

#pragma mark - DJIPlaybackDelegate
- (void)playbackManager:(DJIPlaybackManager *)playbackManager didUpdatePlaybackState:(DJICameraPlaybackState *)playbackState
{
    self.cameraPlaybackState = playbackState;
    [self updateUIWithPlaybackState:playbackState];
}

- (void)updateUIWithPlaybackState:(DJICameraPlaybackState *)playbackState
{
    
    if (playbackState.playbackMode == DJICameraPlaybackModeSingleFilePreview) {
        
        [self.selectBtn setHidden:YES];
        [self.selectAllBtn setHidden:YES];
        
        if (playbackState.fileType == DJICameraPlaybackFileTypeJPEG || playbackState.fileType == DJICameraPlaybackFileTypeRAWDNG) { //Photo Type
            
            if (!self.playVideoBtn.hidden) {
                [self.playVideoBtn setHidden:YES];
            }
        }else if (playbackState.fileType == DJICameraPlaybackFileTypeVIDEO) //Video Type
        {
            if (self.playVideoBtn.hidden) {
                [self.playVideoBtn setHidden:NO];
            }
        }
        
    }else if (playbackState.playbackMode == DJICameraPlaybackModeSingleVideoPlaybackStart){ //Playing Video
        
        [self.selectBtn setHidden:YES];
        [self.selectAllBtn setHidden:YES];
        [self.playVideoBtn setHidden:YES];
        
    }else if (playbackState.playbackMode == DJICameraPlaybackModeMultipleFilesPreview){
        
        [self.selectBtn setHidden:NO];
        [self.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
        [self.selectAllBtn setHidden:NO];
        [self.playVideoBtn setHidden:YES];
        
    }else if (playbackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit){
    
        [self.selectBtn setHidden:NO];
        [self.selectBtn setTitle:@"Cancel" forState:UIControlStateNormal];
        [self.selectAllBtn setHidden:NO];
        [self.playVideoBtn setHidden:YES];
    }
    
}

#pragma mark UIAlertView Delegate Method
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
    __weak DJICamera* camera = [self fetchCamera];

    if (alertView.tag == kDeleteAllSelFileAlertTag) {
    
        if (buttonIndex == 1) {
            [camera.playbackManager deleteAllSelectedFiles];
            [self.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
        }
        
    }else if (alertView.tag == kDeleteCurrentFileAlertTag){
    
        if (buttonIndex == 1) {
            [camera.playbackManager deleteCurrentPreviewFile];
            [self.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
        }
        
    }else if (alertView.tag == kDownloadAllSelFileAlertTag){
    
        if (buttonIndex == 1) {
            [self downloadFiles];
        }
        
    }else if (alertView.tag == kDownloadCurrentFileAlertTag){
        
        if (buttonIndex == 1) {
            [self downloadFiles];
        }
    }
    
}

#pragma mark Download Files Method
- (void)updateDownloadProgress:(NSTimer *)updatedTimer
{
    
    if (self.downloadImageError) {
        
        [self stopTimer];
        [self.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
        [self updateStatusAlertContentWithTitle:@"Download Error" message:[NSString stringWithFormat:@"%@", self.downloadImageError] shouldDismissAfterDelay:YES];
        
    }
    else
    {
        NSString *title = [NSString stringWithFormat:@"Download (%d/%d)", self.downloadedFileCount + 1, self.selectedFileCount];
        NSString *message = [NSString stringWithFormat:@"FileName:%@, FileSize:%0.1fKB, Downloaded:%0.1fKB", self.targetFileName, self.totalFileSize / 1024.0, self.currentDownloadSize / 1024.0];
        [self updateStatusAlertContentWithTitle:title message:message shouldDismissAfterDelay:NO];
    }
    
}

- (void)startUpdateTimer
{
    if (self.updateImageDownloadTimer == nil) {
        self.updateImageDownloadTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:self selector:@selector(updateDownloadProgress:) userInfo:nil repeats:YES];
    }
}

- (void)stopTimer
{
    if (self.updateImageDownloadTimer != nil) {
        [self.updateImageDownloadTimer invalidate];
        self.updateImageDownloadTimer = nil;
    }
}

- (void)resetDownloadData
{
    self.downloadImageError = nil;
    self.totalFileSize = 0;
    self.currentDownloadSize = 0;
    self.downloadedFileCount = 0;
    
    [self.downloadedImageData setData:[NSData dataWithBytes:NULL length:0]];
    [self.downloadedImageArray removeAllObjects];
}

-(void) downloadFiles
{
    [self resetDownloadData];
    
    if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeSingleFilePreview) {
        self.selectedFileCount = 1;
    }

    WeakRef(target);
    __weak DJICamera *camera = [self fetchCamera];
    
    [camera.playbackManager downloadSelectedFilesWithPreparation:^(NSString * _Nullable fileName, DJIDownloadFileType fileType, NSUInteger fileSize, BOOL * _Nonnull skip) {
        
        WeakReturn(target);
        [target startUpdateTimer];
        target.totalFileSize = (long)fileSize;
        target.targetFileName = fileName;
        
        [target showStatusAlertView];
        NSString *title = [NSString stringWithFormat:@"Download (%d/%d)", target.downloadedFileCount + 1, target.selectedFileCount];
        NSString *message = [NSString stringWithFormat:@"FileName:%@, FileSize:%0.1fKB, Downloaded:0.0KB", fileName, target.totalFileSize / 1024.0];
        [target updateStatusAlertContentWithTitle:title message:message shouldDismissAfterDelay:NO];
        
    } process:^(NSData * _Nullable data, NSError * _Nullable error) {
        
        WeakReturn(target);

        /**
         *  Important: Don't update Download Progress UI here, it will slow down the download file speed.
         */
        
        if (data) {
            [target.downloadedImageData appendData:data];
            target.currentDownloadSize += data.length;
        }
        target.downloadImageError = error;

    } fileCompletion:^{
        
        WeakReturn(target);
        NSLog(@"Completed Download");
        target.downloadedFileCount++;
        
        UIImage *downloadImage = [[UIImage alloc] initWithData:target.downloadedImageData];
        if (downloadImage) {
            [target.downloadedImageArray addObject:downloadImage];
        }
        
        [target.downloadedImageData setData:[NSData dataWithBytes:NULL length:0]]; //Reset DownloadedImageData when download one file finished
        target.currentDownloadSize = 0.0f; //Reset currentDownloadSize when download one file finished
        
        NSString *title = [NSString stringWithFormat:@"Download (%d/%d)", target.downloadedFileCount, target.selectedFileCount];
        [target updateStatusAlertContentWithTitle:title message:@"Completed" shouldDismissAfterDelay:YES];
        
        if (target.downloadedFileCount == target.selectedFileCount) { //Downloaded all the selected files
            [target stopTimer];
            [target.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
            [target saveDownloadImage];
        }

    } overallCompletion:^(NSError * _Nullable error) {
        
        NSLog(@"DownloadFiles Error %@", error.description);
    }];
    
}

#pragma mark StatusAlertView Methods
-(void) showStatusAlertView
{
    if (self.statusAlertView == nil) {
        self.statusAlertView = [[UIAlertView alloc] initWithTitle:@"" message:@"" delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
        [self.statusAlertView show];
    }
}

-(void) dismissStatusAlertView
{
    
    if (self.statusAlertView) {
        [self.statusAlertView dismissWithClickedButtonIndex:0 animated:YES];
        self.statusAlertView = nil;
    }
        
}

- (void)updateStatusAlertContentWithTitle:(NSString *)title message:(NSString *)message shouldDismissAfterDelay:(BOOL)dismiss
{
    
    if (self.statusAlertView) {
        [self.statusAlertView setTitle:title];
        [self.statusAlertView setMessage:message];
        
        if (dismiss) {
            [self performSelector:@selector(dismissStatusAlertView) withObject:nil afterDelay:2.0];
        }
    }
    
}

#pragma mark Save Download Images

- (void)saveDownloadImage
{
    if (self.downloadedImageArray && self.downloadedImageArray.count > 0)
    {
        UIImage *image = [self.downloadedImageArray lastObject];
        UIImageWriteToSavedPhotosAlbum(image, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
        [self.downloadedImageArray removeLastObject];
    }

}

- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo
{

    if (error != NULL)
    {
        // Show message when image saved failed
        [self updateStatusAlertContentWithTitle:@"Save Image Failed!" message:[NSString stringWithFormat:@"%@", error] shouldDismissAfterDelay:NO];
    }
    else
    {
        // Show message when image successfully saved
        if (self.downloadedImageArray)
        {
            [self saveDownloadImage];
            
            if (self.downloadedImageArray.count == 0)
            {
                [self updateStatusAlertContentWithTitle:@"Stored to Photos Album" message:@"" shouldDismissAfterDelay:YES];
            }
            
        }
        
    }
    
}

#pragma mark UIButton Action Methods

- (IBAction)captureAction:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];
    if (camera) {
        WeakRef(target);
        [camera startShootPhotoWithCompletion:^(NSError * _Nullable error) {
            WeakReturn(target);
            if (error) {
                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Take Photo Error" message:error.description delegate:target cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [errorAlert show];
            }
        }];
    }
    
}

- (IBAction)recordAction:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];
    if (camera) {
        WeakRef(target);
        if (self.isRecording) {
            [camera stopRecordVideoWithCompletion:^(NSError * _Nullable error) {
                WeakReturn(target);
                if (error) {
                    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Stop Record Error" message:error.description delegate:target cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [errorAlert show];
                }
                
            }];
            
        }else
        {
            [camera startRecordVideoWithCompletion:^(NSError * _Nullable error) {
                WeakReturn(target);
                if (error) {
                    UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Start Record Error" message:error.description delegate:target cancelButtonTitle:@"OK" otherButtonTitles:nil];
                    [errorAlert show];
                }
            }];
            
        }
    }
    
}

- (IBAction)changeWorkModeAction:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];

    if (camera == nil) {
        return;
    }
    WeakRef(target);
    UISegmentedControl *segmentControl = (UISegmentedControl *)sender;
    if (segmentControl.selectedSegmentIndex == 0) { //CaptureMode
        
        [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
            WeakReturn(target);
            
            if (!self.playVideoBtn.hidden) {
                [target.playVideoBtn setHidden:YES];
            }
            
            if (error) {
                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Set CameraWorkModeCapture Failed" message:error.description delegate:target cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [errorAlert show];
            }
            
        }];
        
    }else if (segmentControl.selectedSegmentIndex == 1){ //RecordMode
        
        [camera setMode:DJICameraModeRecordVideo withCompletion:^(NSError * _Nullable error) {
            WeakReturn(target);
            
            if (!self.playVideoBtn.hidden) {
                [target.playVideoBtn setHidden:YES];
            }

            if (error) {
                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Set CameraWorkModeRecord Failed" message:error.description delegate:target cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [errorAlert show];
            }
        }];
        
    }else if (segmentControl.selectedSegmentIndex == 2){  //PlaybackMode
        
        [camera setMode:DJICameraModePlayback withCompletion:^(NSError * _Nullable error) {
            WeakReturn(target);
            if (error) {
                UIAlertView *errorAlert = [[UIAlertView alloc] initWithTitle:@"Set CameraWorkModePlayback Failed" message:error.description delegate:target cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [errorAlert show];
            }
        }];
    }
}

- (IBAction)multiPreviewButtonClicked:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];
    [camera.playbackManager enterMultiplePreviewMode];
    
}

- (IBAction)playVideoBtnAction:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];
    
    if (self.cameraPlaybackState.fileType == DJICameraPlaybackFileTypeVIDEO) {
        [camera.playbackManager startVideoPlayback];
    }
    
}

- (IBAction)stopVideoBtnAction:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];
    if (self.cameraPlaybackState.fileType == DJICameraPlaybackFileTypeVIDEO) {
        if (self.cameraPlaybackState.videoPlayProgress > 0) {
            [camera.playbackManager stopVideoPlayback];
        }
    }
    
}

- (IBAction)selectButtonAction:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];
    if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit) {
        [camera.playbackManager exitMultipleEditMode];
    }else
    {
        [camera.playbackManager enterMultipleEditMode];
    }

}

- (IBAction)deleteButtonAction:(id)sender {
    
    self.selectedFileCount = self.cameraPlaybackState.numberOfSelectedFiles;
    
    if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit) {

        if (self.selectedFileCount == 0) {
            [self showStatusAlertView];
            [self updateStatusAlertContentWithTitle:@"Please select files to delete!" message:@"" shouldDismissAfterDelay:YES];
            return;
        }else
        {
            NSString *title;
            if (self.selectedFileCount == 1) {
                title = @"Delete Selected File?";
            }else
            {
                title = @"Delete Selected Files?";
            }
            UIAlertView *deleteAllSelFilesAlert = [[UIAlertView alloc] initWithTitle:title message:@"" delegate:self cancelButtonTitle:@"NO" otherButtonTitles:@"YES", nil];
            deleteAllSelFilesAlert.tag = kDeleteAllSelFileAlertTag;
            [deleteAllSelFilesAlert show];
        }

    }else if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeSingleFilePreview){
        
        UIAlertView *deleteCurrentFileAlert = [[UIAlertView alloc] initWithTitle:@"Delete The Current File?" message:@"" delegate:self cancelButtonTitle:@"NO" otherButtonTitles:@"YES", nil];
        deleteCurrentFileAlert.tag = kDeleteCurrentFileAlertTag;
        [deleteCurrentFileAlert show];
        
    }
    
}

- (IBAction)downloadButtonAction:(id)sender {
    
    self.selectedFileCount = self.cameraPlaybackState.numberOfSelectedFiles;
    
    if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit) {
        
        if (self.selectedFileCount == 0) {
            [self showStatusAlertView];
            [self updateStatusAlertContentWithTitle:@"Please select files to Download!" message:@"" shouldDismissAfterDelay:YES];
            return;
        }else
        {
            NSString *title;
            if (self.selectedFileCount == 1) {
                title = @"Download Selected File?";
            }else
            {
                title = @"Download Selected Files?";
            }
            UIAlertView *downloadSelFileAlert = [[UIAlertView alloc] initWithTitle:title message:@"" delegate:self cancelButtonTitle:@"NO" otherButtonTitles:@"YES", nil];
            downloadSelFileAlert.tag = kDownloadAllSelFileAlertTag;
            [downloadSelFileAlert show];
        }
        
    }else if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeSingleFilePreview){
        
        UIAlertView *downloadCurrentFileAlert = [[UIAlertView alloc] initWithTitle:@"Download The Current File?" message:@"" delegate:self cancelButtonTitle:@"NO" otherButtonTitles:@"YES", nil];
        downloadCurrentFileAlert.tag = kDownloadCurrentFileAlertTag;
        [downloadCurrentFileAlert show];
        
    }

}

- (IBAction)selectAllBtnAction:(id)sender {
    
    __weak DJICamera *camera = [self fetchCamera];

    if (self.cameraPlaybackState.isAllFilesInPageSelected) {
        [camera.playbackManager unselectAllFilesInPage];
    }
    else
    {
        [camera.playbackManager selectAllFilesInPage];
    }

}

@end
