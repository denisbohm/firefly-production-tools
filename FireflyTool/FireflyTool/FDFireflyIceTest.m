//
//  FDFireflyIceTest.m
//  FireflyFlash
//
//  Created by Denis Bohm on 10/1/13.
//  Copyright (c) 2013 Firefly Design. All rights reserved.
//

#import "FDFireflyIceTest.h"

#import <FireflyDevice/FDBinary.h>

#import <ARMSerialWireDebug/FDCortexM.h>
#import <ARMSerialWireDebug/FDSerialWireDebug.h>

#import <FireflyProduction/FDExecutable.h>

typedef enum {
    fd_adc_channel_temperature,
    fd_adc_channel_battery_voltage,
    fd_adc_channel_charge_current
} fd_adc_channel_t;

enum GPIO_Port_TypeDef {
    gpioPortA = 0,
    gpioPortB = 1,
    gpioPortC = 2,
    gpioPortD = 3,
    gpioPortE = 4,
    gpioPortF = 5
};

#define LED0_PORT_PIN gpioPortC, 1
#define LED4_PORT_PIN gpioPortC, 0
// USB orange
#define LED5_PORT_PIN gpioPortE, 9
// USB green
#define LED6_PORT_PIN gpioPortA, 15

#define FD_SPI_BUS_1 1

#define FD_LIS3DH_SCALE (1.0f / 4096.0f)

@interface FDFireflyIceTest ()

@end

@implementation FDFireflyIceTest

- (void)run
{
    [self loadExecutable:@"FireflyIceTest"];
    
    [self run:@"fd_processor_initialize"];
    
    [self run:@"fd_log_initialize"];
    [self run:@"fd_event_initialize"];
    
    [self GPIO_PinOutClear:gpioPortE pin:9]; // orange
    [self GPIO_PinOutClear:gpioPortA pin:15]; // green
    [self GPIO_PinOutClear:gpioPortC pin:1]; // red
    [self GPIO_PinOutClear:gpioPortC pin:0]; // red
    
    BOOL isCharging = ![self GPIO_PinInGet:gpioPortC pin:9];
    FDLog(@"is charging: %@", isCharging ? @"YES" : @"NO");
    
    BOOL testBattery = [self.resources[@"testBattery"] boolValue];
    
    [self invoke:@"fd_adc_initialize"];
    //
    [self invoke:@"fd_adc_start" r0:fd_adc_channel_temperature r1:false];
    float temperature = [self toFloat:[self invoke:@"fd_adc_get_temperature"]];
    FDLog(@"temperature = %0.3f", temperature);
    if ((temperature < 20.0f) || (temperature > 35.0f)) {
        @throw [NSException exceptionWithName:@"TemperatureOutOfRange" reason:[NSString stringWithFormat:@"temperature out of range: %f", temperature] userInfo:nil];
    }
    //
    [self invoke:@"fd_adc_start" r0:fd_adc_channel_battery_voltage r1:false];
    float batteryVoltage = [self toFloat:[self invoke:@"fd_adc_get_battery_voltage"]];
    FDLog(@"batteryVoltage = %0.3f", batteryVoltage);
    if (testBattery) {
        if ((batteryVoltage < 3.5f) || (batteryVoltage > 4.5f)) {
            @throw [NSException exceptionWithName:@"BatteryVoltageOutOfRange" reason:[NSString stringWithFormat:@"battery voltage out of range: %f", batteryVoltage] userInfo:nil];
        }
    }
    //
    [self invoke:@"fd_adc_start" r0:fd_adc_channel_charge_current r1:false];
    float chargeCurrent = [self toFloat:[self invoke:@"fd_adc_get_charge_current"]];
    FDLog(@"chargeCurrent = %0.3f", chargeCurrent);
    if (testBattery) {
        if ((chargeCurrent < 0.0f) || (chargeCurrent > 100.0f)) {
            @throw [NSException exceptionWithName:@"ChargeCurrentOfRange" reason:[NSString stringWithFormat:@"charge current out of range: %f", chargeCurrent] userInfo:nil];
        }
    }
    
    [self invoke:@"fd_i2c1_initialize"];
    [self invoke:@"fd_i2c1_power_on"];
    //
    [self invoke:@"fd_lp55231_initialize"];
    [self invoke:@"fd_lp55231_power_on"];
    [self invoke:@"fd_lp55231_wake"];
    for (uint32_t i = 0; i < 9; ++i) {
        [self invoke:@"fd_lp55231_set_led_pwm" r0:i r1:255];
        float v = [self toFloat:[self invoke:@"fd_lp55231_test_led" r0:i]];
        NSLog(@"led %u %0.3fV", i, v); // r = 2.1V, g = 3.1V, b=3.0V (at 5mA)
        [self invoke:@"fd_lp55231_set_led_pwm" r0:i r1:0];
        [NSThread sleepForTimeInterval:0.250];
    }
    //
    [self invoke:@"fd_mag3110_initialize"];
    [self invoke:@"fd_mag3110_wake"];
    [NSThread sleepForTimeInterval:0.1];
    float mx, my, mz;
    [self invoke:@"fd_mag3110_read" x:&mx y:&my z:&mz]; // -0.000015, 0.000003, 0.000054
    float m = sqrt(mx * mx + my * my + mz * mz);
    if ((m < 1.0e-6) || (m > 1.0e4)) {
        @throw [NSException exceptionWithName:@"MagnetometerOfRange" reason:[NSString stringWithFormat:@"magnetometer out of range: %f", m] userInfo:nil];
    }
    
    [self invoke:@"fd_spi_initialize"];
    //
    // initialize devices on spi1 bus
    [self invoke:@"fd_spi_on" r0:FD_SPI_BUS_1];
    [self invoke:@"fd_spi_wake" r0:FD_SPI_BUS_1];
    //
    [self invoke:@"fd_lis3dh_initialize"];
    [self invoke:@"fd_lis3dh_wake"];
    [NSThread sleepForTimeInterval:0.1];
    int16_t iax, iay, iaz;
    [self invoke:@"fd_lis3dh_read" ix:&iax iy:&iay iz:&iaz]; // -0.078125, -0.734375, 0.718750
    float ax = iax * FD_LIS3DH_SCALE;
    float ay = iay * FD_LIS3DH_SCALE;
    float az = iaz * FD_LIS3DH_SCALE;
    {
    float a = sqrt(ax * ax + ay * ay + az * az);
    if ((a < 0.8) || (a > 1.2)) {
        @throw [NSException exceptionWithName:@"AccelerometerOfRange" reason:[NSString stringWithFormat:@"accelerometer out of range: %f", a] userInfo:nil];
    }
    }
    
    
    [self GPIO_PinOutClear:gpioPortD pin:5]; // NRF_RESETN_PORT_PIN
    [NSThread sleepForTimeInterval:0.1];
    [self GPIO_PinOutSet:gpioPortD pin:5]; // NRF_RESETN_PORT_PIN
    [NSThread sleepForTimeInterval:0.1]; // wait for nRF8001 to come out of reset (62ms)
    BOOL radioNotReady = [self GPIO_PinInGet:gpioPortD pin:4]; // NRF_RDYN_PORT_PIN
    if (radioNotReady) {
        @throw [NSException exceptionWithName:@"nRF8001NotReady" reason:@"nRF8001 not ready" userInfo:nil];
    }
    
    // initialize devices on spi0 powered bus
    //    fd_spi_on(FD_SPI_BUS_0);
    //    fd_spi_wake(FD_SPI_BUS_0);
    //
    [self invoke:@"fd_w25q16dw_initialize"];
    [self invoke:@"fd_w25q16dw_wake"];
    uint32_t address = 0;
    [self invoke:@"fd_w25q16dw_enable_write"];
    [self invoke:@"fd_w25q16dw_erase_sector" r0:address];
    [self invoke:@"fd_w25q16dw_enable_write"];
    uint8_t write_data[] = {0x01, 0x02, 0x3, 04};
    NSData *writeData = [NSData dataWithBytes:write_data length:sizeof(write_data)];
    uint32_t a = self.cortexM.heapRange.location;
    [self.cortexM.serialWireDebug writeMemory:a data:writeData];
    [self invoke:@"fd_w25q16dw_write_page" r0:address r1:a r2:sizeof(write_data)];
    uint8_t read_data[] = {0x00, 0x00, 0x00, 0x00};
    [self.cortexM.serialWireDebug writeMemory:a data:[NSData dataWithBytes:read_data length:sizeof(write_data)]];
    [self invoke:@"fd_w25q16dw_read" r0:address r1:a r2:sizeof(read_data)];
    NSData *data = [self.cortexM.serialWireDebug readMemory:a length:sizeof(read_data)];
    if (![data isEqualToData:writeData]) {
        @throw [NSException exceptionWithName:@"ExternalFlashFailure" reason:@"external flash failure" userInfo:nil];
    }
    
    FDLog(@"erasing external flash...");
    [self invoke:@"fd_w25q16dw_enable_write"];
    [self invoke:@"fd_w25q16dw_chip_erase"];
    [self invoke:@"fd_w25q16dw_wait_while_busy"];
    FDLog(@"erase complete");

    [self GPIO_PinOutSet:gpioPortE pin:9]; // orange
    [self GPIO_PinOutClear:gpioPortA pin:15]; // green
    [self GPIO_PinOutSet:gpioPortC pin:1]; // red
    [self GPIO_PinOutSet:gpioPortC pin:0]; // red
}

@end
