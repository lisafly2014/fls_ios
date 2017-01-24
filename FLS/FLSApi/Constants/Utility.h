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

#import <Foundation/Foundation.h>

@interface Utility : NSObject

extern NSString * const flsServiceUUIDString;
extern NSString * const flsStatusRespondCharacteristicUUIDString;
extern NSString * const flsPacketCharacteristicUUIDString;
extern NSString * const pesServiceUUIDString;
extern NSString * const pesCommandCharacteristicUUIDString;


extern NSString* const FIRMWARE_TYPE_SOFTDEVICE;
extern NSString* const FIRMWARE_TYPE_BOOTLOADER;
extern NSString* const FIRMWARE_TYPE_APPLICATION;
extern NSString* const FIRMWARE_TYPE_BOTH_SOFTDEVICE_BOOTLOADER;


extern int PACKETS_NOTIFICATION_INTERVAL;
extern int FRAME_PACKET;
extern int const PACKET_SIZE;
extern uint16_t const FRAME_SIZE;
extern uint8_t FLSMODEFLAG;

struct DFUResponse
{
    uint8_t responseCode;
    uint8_t requestedCode;
    uint8_t responseStatus;
    
};

typedef enum {
    HEX,
    BIN,
    RBF,
    ZIP
}enumFileExtension;

typedef enum {
    START_INIT_PACKET = 0x00,
    END_INIT_PACKET = 0x01
}initPacketParam;

typedef enum {
    START_DFU_REQUEST = 0x01,
    INITIALIZE_DFU_PARAMETERS_REQUEST = 0x02,
    RECEIVE_FIRMWARE_IMAGE_REQUEST = 0x03,
    VALIDATE_FIRMWARE_REQUEST = 0x04,
    ACTIVATE_AND_RESET_REQUEST = 0x05,
    RESET_SYSTEM = 0x06,
    PACKET_RECEIPT_NOTIFICATION_REQUEST = 0x08,
    RESPONSE_CODE = 0x10,
    PACKET_RECEIPT_NOTIFICATION_RESPONSE = 0x11
    
}FlsOperations;

typedef enum{
    FLS_CMD_START = 0x0,
    FLS_CMD_NEXT =0x1,
    FLS_CMD_END= 0x2
}flsCommandType;

typedef enum{
    FLS_NOTIFY_ENABLED =0x00,
    FLS_NOTIFY_DISABLED= 0x01,
    FLS_CRC_FAIL=0x02,
    FLS_CMD_LENGTH_ERROR =0x03,
    FLS_CMD_MODE_ERROR =0x04,
    FLS_DATA_LENGTH_ERROR =0x05,
    FLS_DATA_WRITE_READY =0x06,
    FLS_RESET_REQUEST= 0x07,
    FLS_CMD_RECEIVED =0x08,
    FLS_CMD_LOST =0x09,
//    FLS_DATA_LOST=0x0A,
}flsStatusValue;


typedef enum {    
    SOFTDEVICE = 0x01,
    BOOTLOADER = 0x02,
    SOFTDEVICE_AND_BOOTLOADER = 0x03,
    APPLICATION = 0x04    
    
}FlsFirmwareTypes;

+ (NSArray *) getFirmwareTypes;
+ (NSString *) stringFileExtension:(enumFileExtension)fileExtension;
+ (NSString *) getDFUHelpText;
+ (NSString *) getEmptyUserFilesText;
+ (NSString *) getEmptyFolderText;
+ (NSString *) getDFUAppFileHelpText;
+ (void) showAlert:(NSString *)message;
+(void)showBackgroundNotification:(NSString *)message;
+ (BOOL)isApplicationStateInactiveORBackground;
+ (uint16_t) crc16_compute:(uint8_t *) p_data withSize:(uint32_t) size;

@end
