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

#import "FLSHelper.h"
#import "UnzipFirmware.h"
#import "JsonParser.h"
#import "Utility.h"

@implementation FLSHelper

-(FLSHelper *)initWithData:(FLSOperations *)flsOperations
{
    if (self = [super init]) {
        self.flsOperations = flsOperations;
    }
    return self;
}

-(void)checkAndPerformFLS
{
    if (self.isSelectedFileZipped) {
        NSLog(@"FLSHelper checkAndPerformFLS in zip mode.");
                    [self.flsOperations performFLSOnFile:self.applicationURL firmwareType:APPLICATION];
                }
    else {
        NSLog(@"FLSHelper checkAndPerformFLS not in zip mode."); 
        [self.flsOperations performFLSOnFile:self.selectedFileURL firmwareType:APPLICATION];
    }
}

//Unzip and check if both bin and hex formats are present for same file then pick only bin format and drop hex format
-(void)unzipFiles:(NSURL *)zipFileURL
{
    self.softdeviceURL = self.bootloaderURL = self.applicationURL = nil;
    self.softdeviceMetaDataURL = self.bootloaderMetaDataURL = self.applicationMetaDataURL = self.systemMetaDataURL = nil;
    UnzipFirmware *unzipFiles = [[UnzipFirmware alloc]init];
    NSArray *firmwareFilesURL = [unzipFiles unzipFirmwareFiles:zipFileURL];
    // if manifest file exist inside then parse it and retrieve the files from the given path

    [self getHexAndDatFile:firmwareFilesURL];
    [self getBinFiles:firmwareFilesURL];
}


-(void)getHexAndDatFile:(NSArray *)firmwareFilesURL
{
    for (NSURL *firmwareURL in firmwareFilesURL) {
        if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"softdevice.hex"]) {
            self.softdeviceURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"bootloader.hex"]) {
            self.bootloaderURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"application.hex"]) {
            self.applicationURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"application.dat"]) {
            self.applicationMetaDataURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"bootloader.dat"]) {
            self.bootloaderMetaDataURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"softdevice.dat"]) {
            self.softdeviceMetaDataURL = firmwareURL;
        }
        else if ([[[firmwareURL path] lastPathComponent] isEqualToString:@"system.dat"]) {
            self.systemMetaDataURL = firmwareURL;
        }
    }
}

-(void)getBinFiles:(NSArray *)firmwareFilesURL
{
    for (NSURL *firmwareBinURL in firmwareFilesURL) {
        if ([[[firmwareBinURL path] lastPathComponent] isEqualToString:@"softdevice.bin"]) {
            self.softdeviceURL = firmwareBinURL;
        }
        else if ([[[firmwareBinURL path] lastPathComponent] isEqualToString:@"bootloader.bin"]) {
            self.bootloaderURL = firmwareBinURL;
        }
        else if ([[[firmwareBinURL path] lastPathComponent] isEqualToString:@"application.bin"]) {
            self.applicationURL = firmwareBinURL;
        }
    }
}

-(void) setFirmwareType
{
        self.enumFirmwareType = APPLICATION;
}



-(BOOL)isValidFileSelected{
    NSLog(@"isValidFileSelected");
    if (self.isSelectedFileZipped && self.applicationURL) {
        NSLog(@"Found Application file in selected zip file");
    }
    else {
       NSLog(@"Found Application file not in selected zip file");
    }   
   return YES;
}

-(NSString *)getUploadStatusMessage
{
            return @"uploading application ...";
}



-(NSString *)getFileValidationMessage
{
    NSString *message;
    switch (self.enumFirmwareType) {
        case SOFTDEVICE:
            message = [NSString stringWithFormat:@"softdevice.hex not exist inside selected file %@",[self.selectedFileURL lastPathComponent]];
            return message;
        case BOOTLOADER:
            message = [NSString stringWithFormat:@"bootloader.hex not exist inside selected file %@",[self.selectedFileURL lastPathComponent]];
            return message;
        case APPLICATION:
            message = [NSString stringWithFormat:@"application.hex not exist inside selected file %@",[self.selectedFileURL lastPathComponent]];
            return message;
            
        case SOFTDEVICE_AND_BOOTLOADER:
            return @"For selected File Type, zip file is required having inside softdevice.hex and bootloader.hex";
            break;
            
        default:
            return @"Not valid File type";
            break;
    }
}

@end
