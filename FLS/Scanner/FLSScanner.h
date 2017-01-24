//
//  FLSScanner.h
//  FLS
//
//  Created by Simon Third on 01/09/15.
//  Copyright (c) 2015 Nordic Semiconductor. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ScannerDelegate.h"

@interface FLSScanner : NSObject <CBCentralManagerDelegate>

@property (strong, nonatomic) CBCentralManager *bluetoothManager;
@property (weak, nonatomic) IBOutlet UITableView *devicesTable;
@property (weak, nonatomic) id <ScannerDelegate> delegate;
@property (strong, nonatomic) CBUUID *filterUUID;

-(void)initFLSScanner:(CBCentralManager *)manager;

@end
