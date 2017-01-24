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
uint8_t twoBytesBuffer[2];



-(void) enableNotification
{
    NSLog(@"FLSOperationsdetails-> enableNotification");
    [self.bluetoothPeripheral setNotifyValue:YES forCharacteristic:self.flsStatusRespondCharacterstic];
}

-(void) startFLS:(FlsFirmwareTypes)firmwareType
{
    NSLog(@"FLSOperationsdetails startFLS");
    self.flsFirmwareType = firmwareType;
    
    uint8_t value[] = {FRAME_SIZE, firmwareType};
    NSLog(@"startFLS: sizeof(value)= %lu",sizeof(value));
    NSLog(@"startFLS: value[]=  %@",[NSData dataWithBytes:&value length:sizeof(value)] );
    
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}

-(void)startOldDFU
{
    NSLog(@"FLSOperationsdetails startOldDFU");
    uint8_t value[] = {START_DFU_REQUEST};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}

-(void) writeFileSize:(uint32_t)firmwareSize
{
    NSLog(@"FLSOperationsdetails writeFileSize");
    uint32_t fileSizeCollection[3];
    switch (self.flsFirmwareType) {
        case SOFTDEVICE:
            fileSizeCollection[0] = firmwareSize;
            fileSizeCollection[1] = 0;
            fileSizeCollection[2] = 0;
            break;
        case BOOTLOADER:
            fileSizeCollection[0] = 0;
            fileSizeCollection[1] = firmwareSize;
            fileSizeCollection[2] = 0;
            break;
        case APPLICATION:
            fileSizeCollection[0] = 0;
            fileSizeCollection[1] = 0;
            fileSizeCollection[2] = firmwareSize;
            break;
            
        default:
            break;
    }    
    
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&fileSizeCollection length:sizeof(fileSizeCollection)] forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

-(void) writeFilesSizes:(uint32_t)softdeviceSize bootloaderSize:(uint32_t)bootloaderSize
{
    NSLog(@"FLSOperationsdetails writeFilesSizes");
    uint32_t fileSizeCollection[3];
    fileSizeCollection[0] = softdeviceSize;
    fileSizeCollection[1] = bootloaderSize;
    fileSizeCollection[2] = 0;
        
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&fileSizeCollection length:sizeof(fileSizeCollection)] forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
}


-(void)sendFrameCommand:(NSData*)binFileData  withframeNumber:(NSUInteger)totalFrameNumber;
{
    NSLog(@"FLSOperationsDetails sendFrameCommand");
    NSMutableData *frameCommand =[[NSMutableData alloc]init];
    uint16_t currentFrameIndex =self.frameIndex;
    [frameCommand appendBytes:&currentFrameIndex length:sizeof(currentFrameIndex)]; //frame index
    
    //[self integerToBytes:self.frameIndex];
    
   // [frameCommand appendBytes:&twoBytesBuffer length:2];
    NSRange dataRange = NSMakeRange(self.frameIndex*FRAME_SIZE, FRAME_SIZE );
    
    NSData *frameData = [binFileData subdataWithRange:dataRange];
    uint16_t frameLength=(uint16_t)frameData.length;
    uint8_t crcPtr[frameLength];
    [frameData getBytes:crcPtr length:frameLength];
    
    uint16_t frameCRC= [Utility crc16_compute:crcPtr withSize:frameLength];
    
    [frameCommand appendBytes:&frameCRC length: sizeof(frameCRC)];//frame crc
    
   
    //[self integerToBytes:frameCRC];
    //[frameCommand appendBytes:&twoBytesBuffer length:2];
    NSLog(@"currentFrameIndex = %i, withh crc= 0x%02x",self.frameIndex,frameCRC);
    [frameCommand appendBytes:&frameLength length:sizeof(frameLength)]; //frame size
    NSLog(@"frame size =%i",frameLength);
    //uint16_t frameSize = FrameData.length;
    //[self integerToBytes:frameSize];
  
   // [frameCommand appendBytes:&twoBytesBuffer length:2];
    flsCommandType cmd_type;
    if(self.frameIndex <=0){
       cmd_type = FLS_CMD_START;
    }else if(self.frameIndex == totalFrameNumber -1){
        cmd_type = FLS_CMD_END;
    }else{
        cmd_type = FLS_CMD_NEXT;
    }
    //[self integerToBytes:cmd_type];
    
    [frameCommand appendBytes:&cmd_type length:2]; //frame command
    NSLog(@"mutable frame command is %@",frameCommand);
    NSData *frameCommandData= [NSData dataWithData:frameCommand];
    NSLog(@"immutable frame command is %@",frameCommandData);
    
    [self.bluetoothPeripheral writeValue:frameCommandData
                       forCharacteristic:self.flsPacketCharacteristic
                                    type:CBCharacteristicWriteWithResponse];
}
-(uint8_t *) integerToBytes:(uint16_t) value{
    twoBytesBuffer[0]= (Byte)(value & 0xFF);
    twoBytesBuffer[1] =(Byte)((value >> 8) & 0xFF);
    
    return twoBytesBuffer;
}


-(void)sendResetCommand{
    uint8_t value[] = {FLS_RESET_REQUEST};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
    
}

-(void) writeFileSizeForOldDFU:(uint32_t)firmwareSize
{
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&firmwareSize length:sizeof(firmwareSize)] forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
}

//Init Packet is included in new DFU in SDK 7.0
-(void) sendInitPacket:(NSURL *)metaDataURL
{
    NSData *fileData = [NSData dataWithContentsOfURL:metaDataURL];
    NSLog(@"metaDataFile length: %lu",(unsigned long)[fileData length]);
    
    //send initPacket with parameter value set to Receive Init Packet [0] to dfu Control Point Characteristic
    uint8_t initPacketStart[] = {INITIALIZE_DFU_PARAMETERS_REQUEST, START_INIT_PACKET};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&initPacketStart length:sizeof(initPacketStart)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
    
    //send init Packet data to dfu Packet Characteristic
    [self.bluetoothPeripheral writeValue:fileData forCharacteristic:self.flsPacketCharacteristic type:CBCharacteristicWriteWithoutResponse];
    
    
    //send initPacket with parameter value set to Init Packet Complete [1] to dfu Control Point Characteristic
    uint8_t initPacketEnd[] = {INITIALIZE_DFU_PARAMETERS_REQUEST, END_INIT_PACKET};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&initPacketEnd length:sizeof(initPacketEnd)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}

-(void)resetAppToDFUMode
{
    [self.bluetoothPeripheral setNotifyValue:YES forCharacteristic:self.flsStatusRespondCharacterstic];
    uint8_t value[] = {START_DFU_REQUEST, APPLICATION};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}

//dfu Version characteristic is introduced in SDK 7.0
-(void)getDfuVersion
{
    NSLog(@"getDFUVersion");
    [self.bluetoothPeripheral readValueForCharacteristic:self.dfuVersionCharacteristic];
}

-(void) enablePacketNotification
{
    NSLog(@"FLSOperationsdetails enablePacketNotification");
    uint8_t value[] = {PACKET_RECEIPT_NOTIFICATION_REQUEST, PACKETS_NOTIFICATION_INTERVAL,0};
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}


-(void) receiveFirmwareImage
{
    NSLog(@"FLSOperationsdetails receiveFirmwareImage");
    uint8_t value = RECEIVE_FIRMWARE_IMAGE_REQUEST;
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}

-(void) validateFirmware
{
    NSLog(@"FLSOperationsdetails validateFirmwareImage");
    uint8_t value = VALIDATE_FIRMWARE_REQUEST;
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}

-(void) activateAndReset
{
    NSLog(@"FLSOperationsdetails activateAndReset");
    uint8_t value = ACTIVATE_AND_RESET_REQUEST;
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
}

-(void) resetSystem
{
    NSLog(@"FLSOperationsdetails resetSystem");
    uint8_t value = RESET_SYSTEM;
    [self.bluetoothPeripheral writeValue:[NSData dataWithBytes:&value length:sizeof(value)] forCharacteristic:self.flsStatusRespondCharacterstic type:CBCharacteristicWriteWithResponse];
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

-(void) setPeripheralAndOtherParametersWithVersion:(CBPeripheral *)peripheral
             controlPointCharacteristic:(CBCharacteristic *)controlPointCharacteristic
                   packetCharacteristic:(CBCharacteristic *)packetCharacteristic
                    versionCharacteristic:(CBCharacteristic *)versionCharacteristic
{
    NSLog(@"setPeripheralAndOtherParameters %@",peripheral.name);
    self.bluetoothPeripheral = peripheral;
    self.flsStatusRespondCharacterstic = controlPointCharacteristic;
    self.flsPacketCharacteristic = packetCharacteristic;
    self.dfuVersionCharacteristic = versionCharacteristic;
}

@end
