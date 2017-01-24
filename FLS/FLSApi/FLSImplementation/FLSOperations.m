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

#import "FLSOperations.h"
#import "Utility.h"
#import "FLSOperationsDetails.h"
#import "BLEOperations.h"
#import "FLSScanner.h"



@implementation FLSOperations

@synthesize flsDelegate;
@synthesize flsRequests;
@synthesize binFileSize;
@synthesize firmwareFile;
@synthesize dfuResponse;
@synthesize fileRequests;
@synthesize fileRequests2;
@synthesize bleOperations;
@synthesize flsScanner;
@synthesize isEnteredFLSMode;



bool isStartingSecondFile, isPerformedOldDFU, isVersionCharacteristicExist, isOneFileForSDAndBL;

NSDate *startTime, *finishTime,*eraseStartTime,*eraseEndTime;
uint16_t connectInterval =30;




-(FLSOperations *) initWithDelegate:(id<FLSOperationsDelegate>) delegate
{
    if (self = [super init])
    {
        flsDelegate = delegate;
        flsRequests = [[FLSOperationsDetails alloc]init];
        bleOperations = [[BLEOperations alloc]initWithDelegate:self];
        flsScanner = [[FLSScanner alloc] init];
       
    }
    return self;
}


-(void)setCentralManager:(CBCentralManager *)manager
{
    if (manager) {
        [bleOperations setBluetoothCentralManager:manager];
    }
    else {
        NSLog(@"CBCentralManager is nil");
        NSString *errorMessage = [NSString stringWithFormat:@"Error on received CBCentralManager\n Message: Bluetooth central manager is nil"];
        [flsDelegate onError:errorMessage];
    }
}

-(void)connectDevice:(CBPeripheral *)peripheral
{
    if (peripheral) {
        [bleOperations connectDevice:peripheral];
    }
    else {
        NSLog(@"CBPeripheral is nil");
        NSString *errorMessage = [NSString stringWithFormat:@"Error on received CBPeripheral\n Message: Bluetooth peripheral is nil"];
        [flsDelegate onError:errorMessage];
    }
}

-(void)cancelFLS
{
    NSLog(@"cancelFLS");
    [flsRequests sendResetCommand];

}





-(void)performFLSOnFile:(NSURL *)firmwareURL firmwareType:(FlsFirmwareTypes)firmwareType
{
    NSLog(@"FLSOperations.m perfirmFLSOnFile");
    firmwareFile = firmwareURL;
    [self initFileOperations];
    [self initParameters];
    self.flsFirmwareType = firmwareType;
    [fileRequests openFile:firmwareURL];
    [flsRequests enableNotification];
    
}



-(void)initParameters
{
    startTime = [NSDate date];
    binFileSize = 0;
    flsRequests.frameIndex =0;
    fileRequests.mAbort= NO;
    fileRequests.delayTime =0.006f;
}

-(void) initFileOperations
{
    fileRequests = [[FileOperations alloc]initWithDelegate:self
                                             blePeripheral:self.bluetoothPeripheral
                                         bleCharacteristic:self.flsPacketCharacteristic];
}




-(void) startSendingFile
{
    NSLog(@"FLSOperations:  startSendingFile");

    [flsDelegate onFLSStarted];
    if (self.flsFirmwareType == SOFTDEVICE_AND_BOOTLOADER && !isOneFileForSDAndBL) {
        [flsDelegate onSoftDeviceUploadStarted];
    }
}

-(void) processFLSResponse:(NSData*) data
{
    NSLog(@"processFLSResponse");
    if([data length] > 2){
        uint16_t *conn_param = (uint16_t *)[data bytes];
        flsStatusValue reponseType = conn_param[0];
        NSLog(@"responseType =%u", reponseType);
        if(reponseType ==FLS_CRC_FAIL){
            NSLog(@"Frame CRC error. Transfer frame %i again!",flsRequests.frameIndex);
            uint16_t currentConnectInterval = (uint16_t)(conn_param[1]*1.25);
            NSLog(@"currentConnectInterval=%i,default connect interval =%i",currentConnectInterval,connectInterval);
             flsRequests.frameStartTime =[NSDate date];
            [fileRequests writeFrame:flsRequests.frameIndex withInterval:fileRequests.delayTime];
        }else{
            [self.flsRequests sendResetCommand];
            [flsDelegate onError: @"Unknow FLS Response"];
        }
    }else{
        flsStatusValue reponseType = *(int*)[data bytes];
        NSLog(@"responseType =%u", reponseType);
        switch(reponseType){
            case FLS_NOTIFY_ENABLED:
                NSLog(@"CCC enabled");
                eraseStartTime = [NSDate date];
                [flsRequests sendFrameCommand:fileRequests.binFileData  withframeNumber:self.fileRequests.flsFrameNumber];
               [flsDelegate onFLSStarted];
                break;
            case FLS_NOTIFY_DISABLED:
                [self.flsRequests sendResetCommand];
                [flsDelegate onError: @"CCC disabled"];
                break;
            case FLS_CMD_LENGTH_ERROR:
                [self.flsRequests sendResetCommand];
                [flsDelegate onError: @"Command Length Error"];
                break;
            case FLS_CMD_MODE_ERROR:
                [self.flsRequests sendResetCommand];
                [flsDelegate onError: @"Command Mode Error"];
                break;
            case FLS_DATA_LENGTH_ERROR:
                [self.flsRequests sendResetCommand];
                [flsDelegate onError: @"Data Length Error"];
                break;
            case FLS_DATA_WRITE_READY:
                NSLog(@"Frame %i has written to flash!",flsRequests.frameIndex);
                flsRequests.frameIndex ++;
                NSUInteger flsSendBytes = flsRequests.frameIndex*FRAME_SIZE;
                if(flsSendBytes >= binFileSize){
                    NSLog(@"The Last frame: Frame %i has written to flash",flsRequests.frameIndex);
                    [flsRequests sendResetCommand];
                    [self calculateFLSTime];
                    [flsDelegate onSuccessfulFileTranferred];
                }else{
                  [flsRequests sendFrameCommand:fileRequests.binFileData withframeNumber:fileRequests.flsFrameNumber];
                }
                break;
            case FLS_CMD_RECEIVED:
                NSLog(@"frame %i command received.",flsRequests.frameIndex);
                flsRequests.frameStartTime =[NSDate date];
                [fileRequests writeFrame:flsRequests.frameIndex withInterval:fileRequests.delayTime];
                break;
            case FLS_CMD_LOST:
                 NSLog(@"frame %i command has lost.",flsRequests.frameIndex);
                 [flsRequests sendFrameCommand:fileRequests.binFileData withframeNumber:fileRequests.flsFrameNumber];
                break;

            default:
                [self.flsRequests sendResetCommand];
                [flsDelegate onError: @"Unknow FLS Response"];
                break;
        }
        
    }

}

-(void)setFLSOperationsDetails
{
    [self.flsRequests setPeripheralAndOtherParameters:self.bluetoothPeripheral
                           statusRespondCharacteristic:self.flsStatusRespondCharacterstic
                                 packetCharacteristic:self.flsPacketCharacteristic];
}

-(void)calculateFLSTime
{
    finishTime = [NSDate date];
    self.uploadTimeInSeconds = [finishTime timeIntervalSinceDate:startTime];
    NSLog(@"upload time in sec: %lu",(unsigned long)self.uploadTimeInSeconds);
}

-(void)enterFLSMode{
    NSLog(@"FLSOperations:  enterFLSMode");
    uint8_t value[] = {FLSMODEFLAG};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.pesCommandCharacteristic type:CBCharacteristicWriteWithResponse];
}

#pragma mark - BLEOperations delegates

-(void)onDeviceConnected:(CBPeripheral *)peripheral
withPacketCharacteristic:(CBCharacteristic *)flsPacketCharacteristic
andStatusRespondCharacteristic:(CBCharacteristic *)flsStatusRespondCharacterstic
{
    self.bluetoothPeripheral = peripheral;
    self.flsPacketCharacteristic = flsPacketCharacteristic;
    self.flsStatusRespondCharacterstic = flsStatusRespondCharacterstic;
    [self setFLSOperationsDetails];
    [flsDelegate onDeviceConnected:peripheral];
}

-(void)onDeviceConnected:(CBPeripheral *)peripheral
withCommandCharacteristic:(CBCharacteristic *)pesCommandCharacteristic
{
    self.bluetoothPeripheral = peripheral;
    self.pesCommandCharacteristic = pesCommandCharacteristic;
    self.isEnteredFLSMode = YES;
    
    [self enterFLSMode];
    
    
}

-(void)onDeviceDisconnected:(CBPeripheral *)peripheral
{
    NSLog(@"isEnteredFLSMode = %i",self.isEnteredFLSMode);
    if(self.isEnteredFLSMode){
        [self.flsScanner initFLSScanner:self.bleOperations.centralManager];
    }
     [flsDelegate onDeviceDisconnected:peripheral];
}


-(void)onReceivedNotification:(NSData *)data
{
    [self processFLSResponse:data];
}

#pragma mark - FileOperations delegates

-(void)onTransferPercentage:(int)percentage
{
    [flsDelegate onTransferPercentage:percentage];
}

-(void)onFileOpened:(NSUInteger)fileSizeOfBin
{
    NSLog(@"onFileOpened file size: %lu",(unsigned long)fileSizeOfBin);
    binFileSize += fileSizeOfBin;
}

-(void)onError:(NSString *)errorMessage
{
    NSLog(@"FLSOperations: onError");
    [flsDelegate onError:errorMessage];
}

-(void)onFLSOperationCancelled{
    [self cancelFLS];
}


@end

