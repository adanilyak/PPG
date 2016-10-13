//
//  Pixel.h
//  PPG
//
//  Created by Alexander Danilyak on 12/10/2016.
//  Copyright © 2016 mipt. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, ColorComponent) {
    R,
    G,
    B
};

@interface Pixel : NSObject {
    NSUInteger rawData[3];
}

@property (nonatomic) NSUInteger* data;

@property (nonatomic) NSInteger r;
@property (nonatomic) NSInteger g;
@property (nonatomic) NSInteger b;

@property (nonatomic) CGColorRef color;

- (NSInteger)getByColorComponent:(ColorComponent)component;
- (void)setValue:(NSInteger)value forComponent:(ColorComponent)component;

@end
