

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

#import "FLSOperationsDetails.h"
#import "Utility.h"

@implementation FLSOperationsDetails



-(void) enableNotification
{
    NSLog(@"FLSOperationsdetails-> enableNotification");
    [self.bluetoothPeripheral setNotifyValue:YES forCharacteristic:self.flsStatusRespondCharacterstic];
}

-(void)sendFrameCommand:(NSData*)binFileData  withframeNumber:(NSUInteger)totalFrameNumber;
{
    NSLog(@"FLSOperationsDetails.m: sendFrameCommand");
    NSMutableData *frameCommand =[[NSMutableData alloc]init];
    uint16_t currentFrameIndex =self.frameIndex;
    [frameCommand appendBytes:&currentFrameIndex length:sizeof(currentFrameIndex)]; //frame index
    
    NSRange dataRange;
    NSUInteger firmwareFileSize =binFileData.length;

    if( (self.frameIndex+1)*FRAME_SIZE <=firmwareFileSize){
        dataRange = NSMakeRange(self.frameIndex*FRAME_SIZE, FRAME_SIZE );
    }else{
        dataRange = NSMakeRange(self.frameIndex*FRAME_SIZE, firmwareFileSize- self.frameIndex*FRAME_SIZE);
    }
    
    NSData *frameData = [binFileData subdataWithRange:dataRange];
    uint16_t frameLength=(uint16_t)frameData.length;
    uint8_t crcPtr[frameLength];
    [frameData getBytes:crcPtr length:frameLength];
    
    uint16_t frameCRC= [Utility crc16_compute:crcPtr withSize:frameLength];
    
    [frameCommand appendBytes:&frameCRC length: sizeof(frameCRC)];//frame crc
   
  
    NSLog(@"currentFrameIndex = %i,current Frame Size = %i, withh crc= 0x%02x",self.frameIndex,frameLength,frameCRC);
    [frameCommand appendBytes:&frameLength length:sizeof(frameLength)]; //frame size
   

    flsCommandType cmd_type;
    if(self.frameIndex <=0){
       cmd_type = FLS_CMD_START;
    }else if(self.frameIndex == totalFrameNumber -1){
        cmd_type = FLS_CMD_END;
    }else{
        cmd_type = FLS_CMD_NEXT;
    }
    
    [frameCommand appendBytes:&cmd_type length:2]; //frame command
    
     NSData *frameCommandData= [NSData dataWithData:frameCommand];
     NSLog(@"immutable frame command is %@",frameCommandData);
    
    [self.bluetoothPeripheral writeValue:frameCommandData
                       forCharacteristic:self.flsPacketCharacteristic
                                    type:CBCharacteristicWriteWithoutResponse];
    
}

-(void)sendResetCommand{
    NSLog(@"FLSOperationsDetails:  sendResetCommand");
    uint8_t value[] = {FLS_RESET_REQUEST};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
    
}

-(void) setPeripheralAndOtherParameters:(CBPeripheral *)peripheral
             statusRespondCharacteristic:(CBCharacteristic *)statusRespondCharacteristic
                   packetCharacteristic:(CBCharacteristic *)packetCharacteristic
{
    NSLog(@"setPeripheralAndOtherParameters %@",peripheral.name);
    self.bluetoothPeripheral = peripheral;
    self.flsStatusRespondCharacterstic = statusRespondCharacteristic;
    self.flsPacketCharacteristic = packetCharacteristic;
}

@end
