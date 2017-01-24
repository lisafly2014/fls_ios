//
//  FLSScanner.m
//  FLS
//
//  Created by Simon Third on 01/09/15.
//  Copyright (c) 2015 Nordic Semiconductor. All rights reserved.
//

#import "FLSScanner.h"
#import "ScannedPeripheral.h"
#import "Utility.h"

@interface FLSScanner ()
/*!
 * List of the peripherals shown on the table view. Peripheral are added to this list when it's discovered.
 * Only peripherals with bridgeServiceUUID in the advertisement packets are being displayed.
 */
@property (strong, nonatomic) NSMutableArray *peripherals;
/*!
 * The timer is used to periodically reload table
 */
@property (strong, nonatomic) NSTimer *timer;

@end

@implementation FLSScanner

@synthesize bluetoothManager;
@synthesize devicesTable;
@synthesize filterUUID;
@synthesize timer;

NSDate *startTime;

-(void)initFLSScanner:(CBCentralManager *)manager{
    NSLog(@"FLSScanner initFLSScanner");
    
    self.bluetoothManager = manager;
    self.bluetoothManager.delegate = self;
    if (self.bluetoothManager.state == CBCentralManagerStatePoweredOn) {
//        startTime =[NSDate date];
        [self scanForPeripherals:YES];
    }

}

#pragma mark Central Manager delegate methods

-(void)centralManagerDidUpdateState:(CBCentralManager *)central
{
    NSLog(@"FLSScanner centralManagerDidUpdateState");

}

/*!
 * @brief Starts scanning for peripherals with rscServiceUUID
 * @param enable If YES, this method will enable scanning for bridge devices, if NO it will stop scanning
 * @return 0 if success, -1 if Bluetooth Manager is not in CBCentralManagerStatePoweredOn state.
 */
- (int) scanForPeripherals:(BOOL)enable
{
     if (enable)
    {
        filterUUID = [CBUUID UUIDWithString:flsServiceUUIDString];

        NSLog(@"filterUUID =%@",filterUUID);
        [self.bluetoothManager scanForPeripheralsWithServices:@[ filterUUID ] options:@{CBCentralManagerScanOptionAllowDuplicatesKey:@YES}];
    }
    else
    {
        NSLog(@"stop scan");
        [bluetoothManager stopScan];
    }

    return 0;
}


- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
   NSLog(@"scanned peripheral : %@",peripheral.name);

   // Add the sensor to the list and reload deta set
   ScannedPeripheral* sensor = [ScannedPeripheral initWithPeripheral:peripheral rssi:RSSI.intValue];
    
    if(sensor){
        [self.bluetoothManager stopScan];
//        [self calculateScanTime];
        
        [self.delegate centralManager:self.bluetoothManager didPeripheralSelected:sensor.peripheral];
     }
}

-(void)calculateScanTime
{
    NSDate *finishTime = [NSDate date];
    unsigned long uploadTimeInSeconds = [finishTime timeIntervalSinceDate:startTime];
    NSLog(@"scan fls peripheral time in sec: %lu",uploadTimeInSeconds);
}

@end
