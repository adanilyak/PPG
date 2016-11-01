//
//  Pixel.m
//  PPG
//
//  Created by Alexander Danilyak on 12/10/2016.
//  Copyright © 2016 mipt. All rights reserved.
//

#import "Pixel.h"

@implementation Pixel

@synthesize r;
@synthesize g;
@synthesize b;

- (instancetype)init {
    self = [super init];
    if(self != nil) {
        self.data = rawData;
    }
    return self;
}

#pragma mark - Getters

- (NSInteger)r {
    return rawData[0];
}

- (NSInteger)g {
    return rawData[1];
}

- (NSInteger)b {
    return rawData[2];
}

- (NSUInteger*)data {
    return rawData;
}

- (CGColorRef)color {
    return CGColorCreateGenericRGB(self.r / 255.0,
                                   self.g / 255.0,
                                   self.b / 255.0,
                                   1.0);
}

- (CGFloat)l {
    return 1.0 * self.r + 4.5907 * self.g + 0.0601 * self.b;
}

#pragma mark - Setters

- (void)setR:(NSInteger)newR {
    r = MAX(0, MIN(255, newR));
    rawData[0] = r;
}

- (void)setG:(NSInteger)newG {
    g = MAX(0, MIN(255, newG));
    rawData[1] = g;
}

- (void)setB:(NSInteger)newB {
    b = MAX(0, MIN(255, newB));
    rawData[2] = b;
}

#pragma mark - Methods

- (NSInteger)getByColorComponent:(ColorComponent)component {
    return rawData[component];
}

- (void)setValue:(NSInteger)value forComponent:(ColorComponent)component {
    switch(component) {
        case R: {
            [self setR:value];
        }
            break;
        case G: {
            [self setG:value];
        }
            break;
        case B: {
            [self setB:value];
        }
            break;
    }
}

@end
