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

#import "BLEOperations.h"
#import "Utility.h"

@implementation BLEOperations

bool isFLSPacketCharacteristicFound, isFLSStatusRespondCharacteristicFound,isFLSServiceFound;
bool isPESServiceFound,isPESCommandCharacteristicFound;


-(BLEOperations *) initWithDelegate:(id<BLEOperationsDelegate>) delegate
{
    if (self = [super init])
    {
        self.bleDelegate = delegate;

    }
    return self;
}

-(void)setBluetoothCentralManager:(CBCentralManager *)manager
{
    self.centralManager = manager;
    self.centralManager.delegate = self;
}

-(void)connectDevice:(CBPeripheral *)peripheral
{
    NSLog(@"BLEOperations:  connectDevice");
    self.bluetoothPeripheral = peripheral;
    self.bluetoothPeripheral.delegate = self;
    [self.centralManager connectPeripheral:peripheral options:nil];
}

-(void)searchFLSRequiredCharacteristics:(CBService *)service
{
    isFLSStatusRespondCharacteristicFound = NO;
    isFLSPacketCharacteristicFound = NO;
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Found characteristic %@",characteristic.UUID);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:flsStatusRespondCharacteristicUUIDString]]) {
            NSLog(@"Status Respond characteristic found");
            isFLSStatusRespondCharacteristicFound = YES;
            self.flsStatusRespondCharacterstic = characteristic;
            NSLog(@"Status Respond characteristic property:\n%@ ",characteristic);
        }
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:flsPacketCharacteristicUUIDString]]) {
            NSLog(@"Packet Characteristic is found");
            isFLSPacketCharacteristicFound = YES;
            self.flsPacketCharacteristic = characteristic;
            NSLog(@"Packet Characteristic property:\n%@ ",characteristic);
        }
    }
}

-(void)searchPESRequiredCharacteristics:(CBService *)service
{
    isPESCommandCharacteristicFound = NO;
    
    for (CBCharacteristic *characteristic in service.characteristics) {
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:pesCommandCharacteristicUUIDString]]) {
            NSLog(@"Found characteristic %@",characteristic.UUID);
            NSLog(@"PES command characteristic found");
            isPESCommandCharacteristicFound = YES;
            self.pesCommandCharacteristic = characteristic;
            NSLog(@"PES command characteristic property:\n%@ ",characteristic);
        }

    }
}

#pragma mark - CentralManager delegates
- (void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"centralManagerDidUpdateState");
}

-(void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    //NSLog(@"didConnectPeripheral");
    NSLog(@"BLEOperations didConnectPeripheral");
    [self.bluetoothPeripheral discoverServices:nil];
}

-(void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didDisconnectPeripheral");
    
    [self.bleDelegate onDeviceDisconnected:peripheral];
}

-(void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    NSLog(@"didFailToConnectPeripheral");
    [self.bleDelegate onDeviceDisconnected:peripheral];
}

#pragma mark - CBPeripheral delegates

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    isFLSServiceFound = NO;
    isPESServiceFound = NO;
    NSLog(@"didDiscoverServices, found %lu services",(unsigned long)peripheral.services.count);
    for( CBService *service in peripheral.services)
    {
        NSLog(@"current service UUID is: %@",service.UUID);
    }

    for (CBService *service in peripheral.services) {
        NSLog(@"discovered service %@",service.UUID);
        if ([service.UUID isEqual:[CBUUID UUIDWithString:flsServiceUUIDString]]) {
            NSLog(@"FLS Service is found");
            isFLSServiceFound = YES;
            [self.bluetoothPeripheral discoverCharacteristics:nil forService:service];
        }
        else if([service.UUID isEqual:[CBUUID UUIDWithString:pesServiceUUIDString]]){
            NSLog(@"PES Service is found");
            isPESServiceFound = YES;
            [self.bluetoothPeripheral discoverCharacteristics:nil forService:service];
        }
        else{
            continue;
        }
     }
    if (!(isFLSServiceFound ||isPESServiceFound )) {
        NSString *errorMessage = [NSString stringWithFormat:@"Error on discovering service\n Message: Required FLS & PES service not available on peripheral"];
        [self.centralManager cancelPeripheralConnection:peripheral];
        [self.bleDelegate onError:errorMessage];
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    NSLog(@"didDiscoverCharacteristicsForService");
    if ([service.UUID isEqual:[CBUUID UUIDWithString:flsServiceUUIDString]]) {
        [self searchFLSRequiredCharacteristics:service];
           if (isFLSStatusRespondCharacteristicFound && isFLSPacketCharacteristicFound) {
            [self.bleDelegate onDeviceConnected:self.bluetoothPeripheral
                       withPacketCharacteristic:self.flsPacketCharacteristic
                  andStatusRespondCharacteristic:self.flsStatusRespondCharacterstic];
        }
        else {
            NSString *errorMessage = [NSString stringWithFormat:@"Error on discovering characteristics\n Message: Required FLS characteristics are not available on peripheral"];
            [self.centralManager cancelPeripheralConnection:peripheral];
            [self.bleDelegate onError:errorMessage];
        }
    }
    else if([service.UUID isEqual:[CBUUID UUIDWithString:pesServiceUUIDString]]){
        [self searchPESRequiredCharacteristics:service];
        if(isPESCommandCharacteristicFound){
            [self.bleDelegate onDeviceConnected:self.bluetoothPeripheral withCommandCharacteristic:self.pesCommandCharacteristic];
        }else{
            NSString *errorMessage = [NSString stringWithFormat:@"Error on discovering PES characteristics\n Message: Required PES command characteristic is not available on peripheral"];
            [self.centralManager cancelPeripheralConnection:peripheral];
            [self.bleDelegate onError:errorMessage];
            
        }
    }
}

-(void) peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    NSLog(@"didUpdateValueForCharacteristic");
    if (error) {
        NSString *errorMessage = [NSString stringWithFormat:@"Error on BLE Notification\n Message: %@",[error localizedDescription]];
        NSLog(@"Error in Notification state: %@",[error localizedDescription]);
        [self.bleDelegate onError:errorMessage];
    }
    else {
        NSLog(@"received notification from characteristic %@, with value %@",characteristic.UUID, characteristic.value);
        [self.bleDelegate onReceivedNotification:characteristic.value];
    }
}

-(void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"error in writing characteristic %@ and error %@",characteristic.UUID,[error localizedDescription]);
    }
    else {
        NSLog(@"didWriteValueForCharacteristic %@ and value %@",characteristic.UUID,characteristic.value);
    }
}


@end
