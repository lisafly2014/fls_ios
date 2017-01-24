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

#import "FileOperations.h"
#import "IntelHex2BinConverter.h"
#import "Utility.h"

@implementation FileOperations

NSDate *frameEndTime;
@synthesize mAbort;

-(FileOperations *) initWithDelegate:(id<FileOperationsDelegate>) delegate blePeripheral:(CBPeripheral *)peripheral bleCharacteristic:(CBCharacteristic *)characteristic;
{
    self = [super init];
    if (self)
    {
        self.fileDelegate = delegate;
        self.bluetoothPeripheral = peripheral;
        self.flsPacketCharacteristic = characteristic;  
    }
    return self;
}

-(void)openFile:(NSURL *)fileURL
{
    NSLog(@"FileOperations    openFile");
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if (fileData.length > 0) {
        [self processFileData:fileURL];
        [self.fileDelegate onFileOpened:self.binFileSize];
    }
    else {
        NSLog(@"Error: file is empty!");
        NSString *errorMessage = [NSString stringWithFormat:@"Error on openning file\n Message: file is empty or not exist"];
        [self.fileDelegate onError:errorMessage];
    }
}

-(BOOL)isFileExtension:(NSString *)fileName fileExtension:(enumFileExtension)fileExtension
{
    if ([[fileName pathExtension] isEqualToString:[Utility stringFileExtension:fileExtension]]) {
        return YES;
    }
    else {
        return NO;
    }
}


-(void)processFileData:(NSURL *)fileURL
{
    NSLog(@"FileOperations -- processFileData:fileURL");
    NSString *fileName = [[fileURL path] lastPathComponent];
    NSData *fileData = [NSData dataWithContentsOfURL:fileURL];
    if ([self isFileExtension:fileName fileExtension:HEX]) {
        self.binFileData = [IntelHex2BinConverter convert:fileData];
        NSLog(@"HexFileSize: %lu and BinFileSize: %lu",(unsigned long)fileData.length,(unsigned long)self.binFileData.length);
    }
    else if ([self isFileExtension:fileName fileExtension:BIN]) {
        self.binFileData = [NSData dataWithContentsOfURL:fileURL];
        NSLog(@"BinFileSize: %lu",(unsigned long)self.binFileData.length);
    }
    else if ([self isFileExtension:fileName fileExtension:RBF]) {
        self.binFileData = [NSData dataWithContentsOfURL:fileURL];
        NSLog(@"RbfFileSize in bytes: %lu",(unsigned long)self.binFileData.length);
    }
    
    self.numberOfPackets = ceil((double)self.binFileData.length / (double)PACKET_SIZE);
    self.bytesInLastPacket = (self.binFileData.length % PACKET_SIZE);
    if (self.bytesInLastPacket == 0) {
        self.bytesInLastPacket = PACKET_SIZE;
    }
    NSLog(@"Number of Packets %d,Bytes in last Packet %d",self.numberOfPackets,self.bytesInLastPacket);
    self.writingPacketNumber = 0;
    self.binFileSize = self.binFileData.length;
    self.flsFrameNumber = ceil((double)self.binFileSize/(double)FRAME_SIZE);
    NSLog(@"Number of Frame: %i",self.flsFrameNumber);
}

-(void)calculateFrameTransferTime{
    frameEndTime =[NSDate date];
    NSUInteger frameTransferTime =[frameEndTime timeIntervalSinceDate:self.frameStartTime];
    NSLog(@"Frame transfers time is %lu seconds",(unsigned long)frameTransferTime );
    
}

-(void)writeFrame:(uint16_t) frameIndex withInterval:(float)interval;
{
    NSLog(@"FileOperations  writeFrame");
    int percentage = 0;

    uint16_t currentWritingframeIndex = 0;
    NSData *nextPacketData;
    self.writingPacketNumber =frameIndex *FRAME_PACKET ;
    NSLog(@"current writing packet number is: %i",self.writingPacketNumber);
    self.frameStartTime =[NSDate date];
    for (int index = 0; index<FRAME_PACKET; index++) {
        if(!self.mAbort){
            if (self.writingPacketNumber > self.numberOfPackets-2) {
                NSLog(@"writeFrame: writing the last packet");
                NSRange dataRange = NSMakeRange(self.writingPacketNumber*PACKET_SIZE, self.bytesInLastPacket);
                if(self.bytesInLastPacket < PACKET_SIZE)
                {
                    NSMutableData *lastPacketData=[NSMutableData data];
                    [lastPacketData appendData:[self.binFileData subdataWithRange:dataRange]];
                    uint8_t paddingNumber = PACKET_SIZE - self.bytesInLastPacket;
                    uint8_t paddingArray[paddingNumber];
                    for(int i=0;i< paddingNumber;i++){
                        paddingArray[i]= 0xff;
                    }
                    
                    [lastPacketData appendBytes:paddingArray length:sizeof(paddingArray)];
                    nextPacketData= [NSData dataWithData:lastPacketData];
                }else{
                    nextPacketData = [self.binFileData subdataWithRange:dataRange];
                }
                
                //          NSLog(@"writing packet number %d ...",self.writingPacketNumber+1);
                //          NSLog(@"packet data: %@",nextPacketData);
                
                
                 [NSThread sleepForTimeInterval:interval];//0.006f
                [self.bluetoothPeripheral writeValue:nextPacketData forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
                [self calculateFrameTransferTime];
                self.writingPacketNumber++;
                currentWritingframeIndex++;
                
                break;
            }
            
            NSRange dataRange = NSMakeRange(self.writingPacketNumber*PACKET_SIZE, PACKET_SIZE);
            nextPacketData = [self.binFileData subdataWithRange:dataRange];
            //      NSLog(@"writing packet number %d ...",self.writingPacketNumber+1);
            //      NSLog(@"packet data: %@",nextPacketData);
            
            [NSThread sleepForTimeInterval:interval]; //0.006f
            [self.bluetoothPeripheral writeValue:nextPacketData forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
            percentage = (((double)(self.writingPacketNumber * 20) / (double)(self.binFileSize)) * 100);
            [self.fileDelegate onTransferPercentage:percentage];
            self.writingPacketNumber++;
            currentWritingframeIndex++;
            
            if((currentWritingframeIndex > FRAME_PACKET-1)){
                NSLog(@"Finished writing Frame %i",frameIndex);
                [self calculateFrameTransferTime];
            }
        }else{           
            break;
        }
   }
    if(self.mAbort){
       [self.fileDelegate  onFLSOperationCancelled];
    }
}


-(void)setBLEParameters:(CBPeripheral *)peripheral bleCharacteristic:(CBCharacteristic *)flsPacketCharacteristic
{
    self.bluetoothPeripheral = peripheral;
    self.flsPacketCharacteristic = flsPacketCharacteristic;
}

@end
