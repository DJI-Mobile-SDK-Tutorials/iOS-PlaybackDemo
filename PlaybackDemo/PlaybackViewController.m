//
//  PlaybackViewController.m
//  PlaybackDemo
//
//  Created by DJI on 16/4/2017.
//  Copyright © 2017 DJI. All rights reserved.
//

#import "PlaybackViewController.h"
#import "DemoUtility.h"
#import "DJIPlaybackMultiSelectViewController.h"

@interface PlaybackViewController ()<DJICameraDelegate, DJIPlaybackDelegate>

@property (nonatomic, strong) IBOutlet UIView* playbackBtnsView;
@property (weak, nonatomic) IBOutlet UIButton *playVideoBtn;
@property (weak, nonatomic) IBOutlet UIButton *selectBtn;
@property (weak, nonatomic) IBOutlet UIButton *selectAllBtn;
@property (weak, nonatomic) IBOutlet UIView *fpvPreviewView;

@property (strong, nonatomic) DJICameraSystemState* cameraSystemState;
@property (strong, nonatomic) DJICameraPlaybackState* cameraPlaybackState;
@property (strong, nonatomic) DJIPlaybackMultiSelectViewController *playbackMultiSelectVC;
@property (strong, nonatomic) UIAlertView* statusAlertView;
@property (strong, nonatomic) NSMutableData *downloadedImageData;
@property (strong, nonatomic) NSTimer *updateImageDownloadTimer;
@property (strong, nonatomic) NSError *downloadImageError;
@property (strong, nonatomic) NSMutableArray *downloadedImageArray;
@property (strong, nonatomic) NSString* targetFileName;
@property (assign, nonatomic) long totalFileSize;
@property (assign, nonatomic) long currentDownloadSize;
@property (assign, nonatomic) int downloadedFileCount;
@property (assign, nonatomic) int selectedFileCount;

- (IBAction)multiPreviewButtonClicked:(id)sender;
- (IBAction)playVideoBtnAction:(id)sender;
- (IBAction)stopVideoBtnAction:(id)sender;

- (IBAction)selectButtonAction:(id)sender;
- (IBAction)deleteButtonAction:(id)sender;
- (IBAction)downloadButtonAction:(id)sender;
- (IBAction)selectAllBtnAction:(id)sender;

- (IBAction)backBtnClickAction:(id)sender;
- (IBAction)switchModeAction:(id)sender;

@end

@implementation PlaybackViewController

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    DJICamera *camera = [DemoUtility fetchCamera];
    
    if (camera != nil) {
        [camera setMode:DJICameraModePlayback withCompletion:^(NSError * _Nullable error) {
            if (error) {
                ShowResult(@"Set CameraWorkModePlayback Failed, %@", error.description);
            }
        }];
        camera.delegate = self;
        camera.playbackManager.delegate = self;
    }
    
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    DJICamera *camera = [DemoUtility fetchCamera];
    [camera setMode:DJICameraModeShootPhoto withCompletion:^(NSError * _Nullable error) {
        if (error) {
            ShowResult(@"Set CameraWorkModeShootPhoto Failed, %@", error.description);
        }
    }];
    
    if (camera && camera.delegate == self) {
        [camera setDelegate:nil];
    }
    
    if (camera && camera.playbackManager.delegate == self) {
        [camera.playbackManager setDelegate:nil];
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
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

- (void)initData
{
    self.downloadedImageData = [NSMutableData data];
    self.downloadedImageArray = [NSMutableArray array];
}


- (void)initPlaybackMultiSelectVC
{
    
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
        DJICamera* camera = [DemoUtility fetchCamera];
        
        if (target.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesPreview) {
            [camera.playbackManager enterSinglePreviewModeWithIndex:index];
        }else if (target.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit){
            [camera.playbackManager toggleFileSelectionAtIndex:index];
        }
        
    }];
    
    [self.playbackMultiSelectVC setSwipeGestureAction:^(UISwipeGestureRecognizerDirection direction) {
        
        WeakReturn(target);
        DJICamera* camera = [DemoUtility fetchCamera];
        
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

- (NSString *)formattingSeconds:(NSUInteger)seconds
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:seconds];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"mm:ss"];
    [formatter setTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
    
    NSString *formattedTimeString = [formatter stringFromDate:date];
    return formattedTimeString;
}


#pragma mark - IBAction Methods

- (IBAction)backBtnClickAction:(id)sender {
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)switchModeAction:(id)sender {
    DJICamera *camera = [DemoUtility fetchCamera];
    if (camera != nil) {
        [camera setMode:DJICameraModePlayback withCompletion:^(NSError * _Nullable error) {
            if (error) {
                ShowResult(@"Set CameraWorkModePlayback Failed, %@", error.description);
            }
        }];
        camera.delegate = self;
        camera.playbackManager.delegate = self;
    }
    
}


- (IBAction)multiPreviewButtonClicked:(id)sender {
    
    DJICamera *camera = [DemoUtility fetchCamera];
    [camera.playbackManager enterMultiplePreviewMode];
    
}

- (IBAction)playVideoBtnAction:(id)sender {
    
    DJICamera *camera = [DemoUtility fetchCamera];
    
    if (self.cameraPlaybackState.fileType == DJICameraPlaybackFileTypeVIDEO) {
        [camera.playbackManager playVideo];
    }
    
}

- (IBAction)stopVideoBtnAction:(id)sender {
    
    DJICamera *camera = [DemoUtility fetchCamera];
    if (self.cameraPlaybackState.fileType == DJICameraPlaybackFileTypeVIDEO) {
        if (self.cameraPlaybackState.videoPlayProgress > 0) {
            [camera.playbackManager stopVideo];
        }
    }
    
}

- (IBAction)selectButtonAction:(id)sender {
    
    DJICamera *camera = [DemoUtility fetchCamera];
    if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeMultipleFilesEdit) {
        [camera.playbackManager exitMultipleEditMode];
    }else
    {
        [camera.playbackManager enterMultipleEditMode];
    }
    
}

- (void)showAlertViewWithTitle:(NSString *)title message:(NSString *)message okActionHandler:(void (^ __nullable)(UIAlertAction *action))handler1 cancelActionhandler:(void (^ __nullable)(UIAlertAction *action))handler2
{
    UIAlertController* alertViewController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction* okAction = [UIAlertAction actionWithTitle:@"YES" style:UIAlertActionStyleDefault handler:handler1];
    UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"NO" style:UIAlertActionStyleDefault handler:handler2];
    [alertViewController addAction:cancelAction];
    [alertViewController addAction:okAction];
    UINavigationController* navController = (UINavigationController*)[[UIApplication sharedApplication] keyWindow].rootViewController;
    [navController presentViewController:alertViewController animated:YES completion:nil];
}

- (IBAction)deleteButtonAction:(id)sender {
    
    self.selectedFileCount = self.cameraPlaybackState.selectedFileCount;
    
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

            WeakRef(target);
            [self showAlertViewWithTitle:title message:nil okActionHandler:^(UIAlertAction *action) {
                WeakReturn(target);
                DJICamera* camera = [DemoUtility fetchCamera];
                [camera.playbackManager deleteAllSelectedFiles];
                [target.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
            } cancelActionhandler:nil];
        }
        
    }else if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeSingleFilePreview){
        
        WeakRef(target);
        [self showAlertViewWithTitle:@"Delete The Current File?" message:nil okActionHandler:^(UIAlertAction *action) {
            WeakReturn(target);
            DJICamera* camera = [DemoUtility fetchCamera];
            [camera.playbackManager deleteCurrentPreviewFile];
            [target.selectBtn setTitle:@"Select" forState:UIControlStateNormal];
            
        } cancelActionhandler:nil];
        
    }
    
}

- (IBAction)downloadButtonAction:(id)sender {
    
    self.selectedFileCount = self.cameraPlaybackState.selectedFileCount;
    
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

            WeakRef(target);
            [self showAlertViewWithTitle:title message:nil okActionHandler:^(UIAlertAction *action) {
                WeakReturn(target);
                [target downloadFiles];
            } cancelActionhandler:nil];
        }
        
    }else if (self.cameraPlaybackState.playbackMode == DJICameraPlaybackModeSingleFilePreview){
        
        WeakRef(target);
        [self showAlertViewWithTitle:@"Download The Current File?" message:nil okActionHandler:^(UIAlertAction *action) {
            WeakReturn(target);
            [target downloadFiles];
        } cancelActionhandler:nil];
    }
    
}

- (IBAction)selectAllBtnAction:(id)sender {
    
    DJICamera *camera = [DemoUtility fetchCamera];
    
    if (self.cameraPlaybackState.isAllFilesInPageSelected) {
        [camera.playbackManager unselectAllFilesInPage];
    }
    else
    {
        [camera.playbackManager selectAllFilesInPage];
    }
    
}

#pragma mark - DJICameraDelegate

- (void)camera:(DJICamera *)camera didUpdateSystemState:(DJICameraSystemState *)systemState
{
    self.cameraSystemState = systemState;
    
    //Update playbackBtnsView state
    
    BOOL isPlayback = (systemState.mode == DJICameraModePlayback) || (systemState.mode == DJICameraModeMediaDownload);
    self.playbackBtnsView.hidden = !isPlayback;
    
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
    DJICamera *camera = [DemoUtility fetchCamera];
    
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
        [self showStatusAlertView];
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
        [self showStatusAlertView];
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
                [self showStatusAlertView];
                [self updateStatusAlertContentWithTitle:@"Stored to Photos Album" message:@"" shouldDismissAfterDelay:YES];
            }
            
        }
        
    }
    
}



@end
