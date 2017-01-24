/*
 * Copyright (c) 2015, Nordic Semiconductor
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this
 * software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
 * ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "FLSViewController.h"
#import "ScannerViewController.h"
#import "Constants.h"
#import "HelpViewController.h"
#import "SSZipArchive.h"
#import "UnzipFirmware.h"
#import "Utility.h"
#import "FLSHelper.h"
#include "FLSHelper.h"


@interface FLSViewController () {
    
}

/*!
 * This property is set when the device has been selected on the Scanner View Controller.
 */
@property (strong, nonatomic) CBPeripheral *selectedPeripheral;
@property (strong, nonatomic) FLSOperations *flsOperations;
@property (strong, nonatomic) FLSHelper *flsHelper;

@property (weak, nonatomic) IBOutlet UILabel *fileName;
@property (weak, nonatomic) IBOutlet UILabel *fileSize;

@property (weak, nonatomic) IBOutlet UILabel *uploadStatus;
@property (weak, nonatomic) IBOutlet UIProgressView *progress;
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UIButton *selectFileButton;
@property (weak, nonatomic) IBOutlet UIView *uploadPane;
@property (weak, nonatomic) IBOutlet UIButton *uploadButton;
@property (weak, nonatomic) IBOutlet UILabel *fileType;
@property (weak, nonatomic) IBOutlet UILabel *fileStutus;



@property BOOL isTransferring;
@property BOOL isTransfered;
@property BOOL isTransferCancelled;
@property BOOL isConnected;
@property BOOL isErrorKnown;
@property BOOL isFLSModeEntered;


- (IBAction)uploadPressed;

@end

@implementation FLSViewController


@synthesize backgroundImage;
@synthesize deviceName;
@synthesize connectButton;
@synthesize selectedPeripheral;
@synthesize flsOperations;
@synthesize fileName;
@synthesize fileSize;
@synthesize uploadStatus;
@synthesize progress;
@synthesize progressLabel;
@synthesize selectFileButton;
@synthesize uploadButton;
@synthesize uploadPane;
@synthesize fileType;
@synthesize fileStutus;
@synthesize isFLSModeEntered;


-(id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        PACKETS_NOTIFICATION_INTERVAL = [[[NSUserDefaults standardUserDefaults] valueForKey:@"fls_number_of_packets"] intValue];
        NSLog(@"PACKETS_NOTIFICATION_INTERVAL %d",PACKETS_NOTIFICATION_INTERVAL);
        flsOperations = [[FLSOperations alloc] initWithDelegate:self];
        self.flsOperations.flsScanner.delegate =self;
        self.flsHelper = [[FLSHelper alloc] initWithData:flsOperations];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    if (is4InchesIPhone)
    {
        // 4 inches iPhone
        UIImage *image = [UIImage imageNamed:@"Background4.png"];
        [backgroundImage setImage:image];
    }
    else
    {
        // 3.5 inches iPhone
        UIImage *image = [UIImage imageNamed:@"Background35.png"];
        [backgroundImage setImage:image];
    }
}

-(void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:YES];
    //if FLS peripheral is connected and user press Back button then disconnect it
    if ([self isMovingFromParentViewController] && self.isConnected) {
        NSLog(@"isMovingFromParentViewController");
        [flsOperations cancelFLS];
    }
}

-(void)uploadPressed
{
    if (self.isTransferring) {
        flsOperations.fileRequests.mAbort =true;
        self.isTransferCancelled = YES;
        [flsOperations cancelFLS];
    }
    else {
        [self performFLS];
    }
}

-(void)performFLS
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self disableOtherButtons];
        uploadStatus.hidden = NO;
        progress.hidden = NO;
        progressLabel.hidden = NO;
        uploadButton.enabled = NO;
    });
    [self.flsHelper checkAndPerformFLS];
}

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // The 'scan' or 'select' seque will be performed only if DFU process has not been started or was completed.
    //return !self.isTransferring;
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"scan"])
    {
        // Set this contoller as scanner delegate
        
        ScannerViewController *controller = (ScannerViewController *)segue.destinationViewController;
        // controller.filterUUID = flsServiceUUID; - the FLS service should not be advertised. We have to scan for any device hoping it supports DFU.
        controller.delegate = self;
    }
    else if ([segue.identifier isEqualToString:@"FileSegue"])
    {
        NSLog(@"performing Select File segue");
        UITabBarController *barController = segue.destinationViewController;
        NSLog(@"BarController %@",barController);
        UINavigationController *navController = [barController.viewControllers firstObject];
        NSLog(@"NavigationController %@",navController);
        AppFilesTableViewController *appFilesVC = (AppFilesTableViewController *)navController.topViewController;
        NSLog(@"AppFilesTableVC %@",appFilesVC);        
        appFilesVC.fileDelegate = self;
    }
    else if ([[segue identifier] isEqualToString:@"help"]) {
        HelpViewController *helpVC = [segue destinationViewController];
        helpVC.helpText = [Utility getDFUHelpText];
        helpVC.isFLSViewController = YES;
    }
}

- (void) clearUI
{
    selectedPeripheral = nil;
    deviceName.text = @"FLASH LOADER SERVICE";
    fileName.text =@"";
    fileSize.text=@"";
    fileType.text=@"";
    fileStutus.text=@"File not loaded";

    uploadStatus.text = @"waiting ...";
    uploadStatus.hidden = YES;
    progress.progress = 0.0f;
    progress.hidden = YES;
    progressLabel.hidden = YES;
    progressLabel.text = @"";
    [uploadButton setTitle:@"Upload" forState:UIControlStateNormal];
    uploadButton.enabled = NO;
    [self enableOtherButtons];
}



-(void)enableUploadButton
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.flsHelper.selectedFileSize > 0) {
            if ([self.flsHelper isValidFileSelected]) {
                NSLog(@" valid file selected");
            }
            else {
                NSLog(@"Valid file not available in zip file");
                [Utility showAlert:[self.flsHelper getFileValidationMessage]];
                return;
            }
        }
        if(selectedPeripheral)
            deviceName.text = selectedPeripheral.name;
        
        if (selectedPeripheral && self.isConnected) {
            uploadButton.enabled = YES;
        }
        else {
            NSLog(@"cant enable Upload button");
        }


    });
}

-(void)disableOtherButtons
{
    selectFileButton.enabled = NO;
    connectButton.enabled = NO;
}

-(void)enableOtherButtons
{
    selectFileButton.enabled = YES;
    connectButton.enabled = YES;
}

-(void)appDidEnterBackground:(NSNotification *)_notification
{
    NSLog(@"appDidEnterBackground");
    if (self.isConnected && self.isTransferring) {
        [Utility showBackgroundNotification:[self.flsHelper getUploadStatusMessage]];
    }
}

-(void)appDidEnterForeground:(NSNotification *)_notification
{
    NSLog(@"appDidEnterForeground");
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
}


#pragma mark Device Selection Delegate
-(void)centralManager:(CBCentralManager *)manager didPeripheralSelected:(CBPeripheral *)peripheral
{
    NSLog(@"FLSViewController didPeripheralSelected");
    NSLog(@"%@",peripheral.name);
    selectedPeripheral = peripheral;
    
    NSLog(@"property of peripheral is: \n %@",peripheral);
    [flsOperations setCentralManager:manager];
    NSLog(@"didPeripheralSelected isEnteredFLSMode =%i ",flsOperations.isEnteredFLSMode);
    if(flsOperations.isEnteredFLSMode){

        flsOperations.isEnteredFLSMode = NO;
    }

   
    [flsOperations connectDevice:peripheral];
}

#pragma mark File Selection Delegate

-(void)onFileSelected:(NSURL *)url
{
    NSLog(@"onFileSelected");
    self.flsHelper.selectedFileURL = url;
    if (self.flsHelper.selectedFileURL) {
        NSLog(@"selectedFile URL %@",self.flsHelper.selectedFileURL);
        NSString *selectedFileName = [[url path]lastPathComponent];
        NSData *fileData = [NSData dataWithContentsOfURL:url];
        self.flsHelper.selectedFileSize = fileData.length;
        NSLog(@"fileSelected %@",selectedFileName);
        
        
        [self.flsHelper setFirmwareType];
        //get file extension
        NSString *extension = [selectedFileName pathExtension];
        NSLog(@"selected file extension is %@",extension);
        if ([extension isEqualToString:@"zip"]) {
            NSLog(@"this is zip file");
            self.flsHelper.isSelectedFileZipped = YES;
            self.flsHelper.isManifestExist = NO;
            [self.flsHelper unzipFiles:self.flsHelper.selectedFileURL];
        }
        else {
            self.flsHelper.isSelectedFileZipped = NO;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            fileName.text = selectedFileName;
            fileSize.text = [NSString stringWithFormat:@"%lu bytes", (unsigned long)self.flsHelper.selectedFileSize];
            fileType.text = @"Firmware Image";
            fileStutus.text=@"OK";
            
            [self enableUploadButton];
        });
    }
    else {
        [Utility showAlert:@"Selected file not exist!"];
    }
}


#pragma mark FLSOperations delegate methods

-(void)onDeviceConnected:(CBPeripheral *)peripheral
{
    NSLog(@"onDeviceConnected %@",peripheral.name);
    self.isConnected = YES;
    [self enableUploadButton];
    //Following if condition display user permission alert for background notification
    if ([UIApplication instancesRespondToSelector:@selector(registerUserNotificationSettings:)]) {
        [[UIApplication sharedApplication] registerUserNotificationSettings:[UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert|UIUserNotificationTypeSound categories:nil]];
    }
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterForeground:) name:UIApplicationDidBecomeActiveNotification object:nil];

}

-(void)onDeviceDisconnected:(CBPeripheral *)peripheral
{
    NSLog(@"device disconnected %@",peripheral.name);
    self.isTransferring = NO;
    self.isConnected = NO;
    
    // Scanner uses other queue to send events. We must edit UI in the main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if(!flsOperations.isEnteredFLSMode){
            
            [self clearUI];
        
            if (!self.isTransfered &&  !self.isErrorKnown) {
                if(!self.isTransferCancelled)
                {
                    if ([Utility isApplicationStateInactiveORBackground]) {
                        [Utility showBackgroundNotification:[NSString stringWithFormat:@"%@ peripheral is disconnected.",peripheral.name]];
                    }
                    else {
                        if(!flsOperations.isEnteredFLSMode)
                        [Utility showAlert:@"The connection has been lost"];
                       
                    }
                    
                }else{
                    [self onFLSCancelled];
                    [Utility showAlert:@"FLS Transfer cancelled"];
                }

                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
                [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:nil];
            }

           self.isTransferCancelled = NO;
            self.isTransfered = NO;
            self.isErrorKnown = NO;
        }

    });
}


-(void)onFLSStarted
{
    NSLog(@"onFLSStarted");
    self.isTransferring = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        uploadButton.enabled = YES;
        [uploadButton setTitle:@"Cancel" forState:UIControlStateNormal];
        NSString *uploadStatusMessage = [self.flsHelper getUploadStatusMessage];
        if ([Utility isApplicationStateInactiveORBackground]) {
            [Utility showBackgroundNotification:uploadStatusMessage];
        }
        else {
            uploadStatus.text = uploadStatusMessage;
        }
    });
}

-(void)onFLSCancelled
{
    NSLog(@"onFLSCancelled");
    self.isTransferring = NO;
    self.isTransferCancelled = YES;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self enableOtherButtons];
    });

}

-(void)onFLSModeEntered{
    
}

-(void)onSoftDeviceUploadStarted
{
    NSLog(@"onSoftDeviceUploadStarted");
}

-(void)onSoftDeviceUploadCompleted
{
    NSLog(@"onSoftDeviceUploadCompleted");
}

-(void)onBootloaderUploadStarted
{
    NSLog(@"onBootloaderUploadStarted");
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([Utility isApplicationStateInactiveORBackground]) {
            [Utility showBackgroundNotification:@"uploading bootloader ..."];
        }
        else {
            uploadStatus.text = @"uploading bootloader ...";
        }
    });
    
}

-(void)onBootloaderUploadCompleted
{
    NSLog(@"onBootloaderUploadCompleted");
}

-(void)onTransferPercentage:(int)percentage
{
    // Scanner uses other queue to send events. We must edit UI in the main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        progressLabel.text = [NSString stringWithFormat:@"%d %%", percentage];
        [progress setProgress:((float)percentage/100.0) animated:YES];
    });    
}

-(void)onSuccessfulFileTranferred
{
    NSLog(@"OnSuccessfulFileTransferred");
    self.flsHelper.selectedFileSize =0;
    // Scanner uses other queue to send events. We must edit UI in the main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isTransferring = NO;
        self.isTransfered = YES;
        NSString* message = [NSString stringWithFormat:@"%lu bytes transfered in %lu seconds", (unsigned long)flsOperations.binFileSize, (unsigned long)flsOperations.uploadTimeInSeconds];
        
        if ([Utility isApplicationStateInactiveORBackground]) {
            [Utility showBackgroundNotification:message];
        }
        else {
            fileName.text =@"";
            fileSize.text=@"";
            fileType.text=@"";
            fileStutus.text=@"File not loaded";
            [self enableOtherButtons];
            [Utility showAlert:message];
        }
        
    });
}

-(void)onError:(NSString *)errorMessage
{
    NSLog(@"OnError %@",errorMessage);
    self.isErrorKnown = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        [Utility showAlert:errorMessage];
        [self clearUI];
    });
}

@end
