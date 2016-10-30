//
//  PPG.m
//  PPG
//
//  Created by Alexander Danilyak on 12/10/2016.
//  Copyright © 2016 mipt. All rights reserved.
//

#import "PPG.h"
#import "Pixel.h"

static NSString* formatOutString = @"/Users/Alexander/Desktop/%@.bmp";

@interface PPG() {
    NSInteger minX, minY, maxX, maxY;
}

@end

@implementation PPG

#pragma mark - Initialization

- (instancetype)init {
    self = [super init];
    if(self != nil) {
        [self loadInImage];
        minX = 0, minY = 0;
        maxX = [self.inImage pixelsWide], maxY = [self.inImage pixelsHigh];
        
        [self loadOriginalImage];
    }
    return self;
}

#pragma mark - Images

- (void)loadInImage {
    self.inImage = [self loadImage:@"cfa"];
    self.outImage = [self.inImage copy];
}

- (void)loadOriginalImage {
    self.originalImage = [self loadImage:@"original"];
}

- (NSBitmapImageRep*)loadImage:(NSString*)name {
    NSString* path = [[NSBundle mainBundle] pathForResource:name ofType:@"bmp" inDirectory:nil forLocalization:nil];
    NSImage* image = [[NSImage alloc] initWithContentsOfFile:path];
    return (NSBitmapImageRep*)[[image representations]objectAtIndex:0];
}

- (BOOL)saveImageWithName:(NSString*)name {
    NSString* path = [NSString stringWithFormat:formatOutString, name];;
    NSData* data = [self.inImage representationUsingType:NSBMPFileType properties:@{}];
    return [data writeToFile:path atomically:NO];
}

#pragma mark - PPG Algo

- (void)makePPG {
    NSLog(@"[STARTED]  Stage 1: Calculate GREEN");
    [self calculateGreenWhereRedOrBlueDefined];
    self.inImage = [self.outImage copy];
    NSLog(@"[FINISHED] Stage 1: Calculate GREEN");
    //NSLog(@"[SAVED]    with result %d", [self saveImageWithName:@"stage1"]);
    
    NSLog(@"[STARTED]  Stage 2: Calculate RED and BLUE by GREEN");
    [self calculateRedAndBlueUsingRestoredGreen];
    self.inImage = [self.outImage copy];
    NSLog(@"[FINISHED] Stage 2: Calculate RED and BLUE by GREEN");
    //NSLog(@"[SAVED]    with result %d", [self saveImageWithName:@"stage2"]);
    
    NSLog(@"[STARTED]  Stage 3: Calculate RED by BLUE and vice versa");
    [self calculateRedWhereBlueDefinedAndViceVersa];
    self.inImage = [self.outImage copy];
    NSLog(@"[FINISHED] Stage 3: Calculate RED by BLUE and vice versa");
    
    NSLog(@"[SAVED]    with result %d", [self saveImageWithName:@"result"]);
    
    NSLog(@"[PSNR]     result: %f", [self psnr]);
}

- (void)calculateGreenWhereRedOrBlueDefined {
    for(NSInteger iX = 0; iX < maxX; iX += 2) {
        for(NSInteger iY = 0; iY < maxY; iY += 2) {
            [self calculateGradientsAndRestoreGreenForStage1AtX:iX andY:iY forComponent:R];
        }
    }
    
    for(NSInteger iX = 1; iX < maxX; iX += 2) {
        for(NSInteger iY = 1; iY < maxY; iY += 2) {
            [self calculateGradientsAndRestoreGreenForStage1AtX:iX andY:iY forComponent:B];
        }
    }
}

- (void)calculateRedAndBlueUsingRestoredGreen {
    for(NSInteger iX = 0; iX < maxX; ++iX) {
        for(NSInteger iY = 0; iY < maxY; ++iY) {
            if(iX % 2 == iY % 2) { continue; }
            [self calculateRedAndBlueAtX:iX andY:iY];
        }
    }
}

- (void)calculateRedWhereBlueDefinedAndViceVersa {
    for(NSInteger iX = 0; iX < maxX; iX += 2) {
        for(NSInteger iY = 0; iY < maxY; iY += 2) {
            [self calculate:B where:R definedAtX:iX andY:iY];
        }
    }
    
    for(NSInteger iX = 1; iX < maxX; iX += 2) {
        for(NSInteger iY = 1; iY < maxY; iY += 2) {
            [self calculate:R where:B definedAtX:iX andY:iY];
        }
    }
}

typedef NS_ENUM(NSUInteger, Stage1GradientDirection) {
    N,
    E,
    W,
    S
};

typedef struct Stage1MinGradient {
    Stage1GradientDirection direction;
    NSUInteger gradient;
} Stage1MinGradient;

- (void)calculateGradientsAndRestoreGreenForStage1AtX:(NSInteger)x andY:(NSInteger)y forComponent:(ColorComponent)component {
    @autoreleasepool {
        if(x == minX && y == minY) { return; }
        if(x == minX && y == maxY - 1) { return; }
        if(x == maxX - 1 && y == minY) { return; }
        if(x == maxX - 1 && y == maxY - 1) { return; }
        
        // N
        NSUInteger dN = NSUIntegerMax;
        NSInteger* dNparts = NULL;
        BOOL skipN = (y + 1) >= maxY || (y - 2) < minX;
        if(!skipN) {
            NSInteger C_p0 = [self colorComponent:component atX:x andY:y];
            NSInteger C_m2 = [self colorComponent:component atX:x andY:y - 2];
            NSInteger G_m1 = [self gAtX:x andY:y - 1];
            NSInteger G_p1 = [self gAtX:x andY:y + 1];
            
            NSInteger parts[4] = {C_p0, C_m2, G_m1, G_p1};
            dNparts = parts;
            
            dN = ABS(C_p0 - C_m2) * 2 + ABS(G_m1 - G_p1);
        }
        
        // E
        NSUInteger dE = NSUIntegerMax;
        NSInteger* dEparts = NULL;
        BOOL skipE = (x + 2) >= maxX || (x - 1) < minX;
        if(!skipE) {
            NSInteger C_p0 = [self colorComponent:component atX:x andY:y];
            NSInteger C_p2 = [self colorComponent:component atX:x + 2 andY:y];
            NSInteger G_p1 = [self gAtX:x + 1 andY:y];
            NSInteger G_m1 = [self gAtX:x - 1 andY:y];
            
            NSInteger parts[4] = {C_p0, C_p2, G_p1, G_m1};
            dEparts = parts;
            
            dE = ABS(C_p0 - C_p2) * 2 + ABS(G_p1 - G_m1);
        }
        
        // W
        NSUInteger dW = NSUIntegerMax;
        NSInteger* dWparts = NULL;
        BOOL skipW = (x + 1) >= maxX || (x - 2) < minX;
        if(!skipW) {
            NSInteger C_p0 = [self colorComponent:component atX:x andY:y];
            NSInteger C_m2 = [self colorComponent:component atX:x - 2 andY:y];
            NSInteger G_m1 = [self gAtX:x - 1 andY:y];
            NSInteger G_p1 = [self gAtX:x + 1 andY:y];
            
            NSInteger parts[4] = {C_p0, C_m2, G_m1, G_p1};
            dWparts = parts;
            
            dW = ABS(C_p0 - C_m2) * 2 + ABS(G_m1 - G_p1);
        }
        
        // S
        NSUInteger dS = NSUIntegerMax;
        NSInteger* dSparts = NULL;
        BOOL skipS = (y + 2) >= maxY || (y - 1) < minY;
        if(!skipS) {
            NSInteger C_p0 = [self colorComponent:component atX:x andY:y];
            NSInteger C_p2 = [self colorComponent:component atX:x andY:y + 2];
            NSInteger G_p1 = [self gAtX:x andY:y + 1];
            NSInteger G_m1 = [self gAtX:x andY:y - 1];
            
            NSInteger parts[4] = {C_p0, C_p2, G_p1, G_m1};
            dSparts = parts;
            
            dS = ABS(C_p0 - C_p2) * 2 + ABS(G_p1 - G_m1);
        }
        
        // MIN
        Stage1MinGradient min;
        min.gradient = dN;
        min.direction = N;
        
        [self setMinIn:&min for:dE andDirection:E];
        [self setMinIn:&min for:dW andDirection:W];
        [self setMinIn:&min for:dS andDirection:S];
        
        // Update Green
        Pixel* pixel = [Pixel new];
        [self.inImage getPixel:pixel.data atX:x y:y];
        NSInteger newG;
        
        switch(min.direction) {
            case N: {
                newG = (dNparts[2] * 3 + dNparts[3] + dNparts[0] - dNparts[1]) / 4;
            }
                break;
            case E: {
                newG = (dEparts[2] * 3 + dEparts[3] + dEparts[0] - dEparts[1]) / 4;
            }
                break;
            case W: {
                newG = (dWparts[2] * 3 + dWparts[3] + dWparts[0] - dWparts[1]) / 4;
            }
                break;
            case S: {
                newG = (dSparts[2] * 3 + dSparts[3] + dSparts[0] - dSparts[1]) / 4;
            }
                break;
        }
        
        [pixel setG:newG];
        [self.outImage setPixel:pixel.data atX:x y:y];
    }
}

- (void)calculateRedAndBlueAtX:(NSInteger)x andY:(NSInteger)y {
    @autoreleasepool {
        Pixel* pixel = [Pixel new];
        [self.inImage getPixel:pixel.data atX:x y:y];
        
        ColorComponent hComponent = y % 2 == 0 ? R : B;
        ColorComponent vComponent = hComponent == R ? B : R;
            
        //Horizontal
        if(x != minX && x != maxX - 1) {
            NSInteger G_m1_p0 = [self gAtX:x - 1 andY:y];
            NSInteger G_p0_p0 = [self gAtX:x andY:y];
            NSInteger G_p1_p0 = [self gAtX:x + 1 andY:y];
            NSInteger C_m1_p0 = [self colorComponent:hComponent atX:x - 1 andY:y];
            NSInteger C_p1_p0 = [self colorComponent:hComponent atX:x + 1 andY:y];
            NSInteger newC = [self hueTransit:G_m1_p0 :G_p0_p0 :G_p1_p0 :C_m1_p0 :C_p1_p0];
            [pixel setValue:newC forComponent:hComponent];
        }
        
        //Vertical
        if(y != minY && y != maxY - 1) {
            NSInteger G_p0_m1 = [self gAtX:x andY:y - 1];
            NSInteger G_p0_p0 = [self gAtX:x andY:y];
            NSInteger G_p0_p1 = [self gAtX:x andY:y + 1];
            NSInteger C_p0_m1 = [self colorComponent:vComponent atX:x andY:y - 1];
            NSInteger C_p0_p1 = [self colorComponent:vComponent atX:x andY:y + 1];
            NSInteger newC = [self hueTransit:G_p0_m1 :G_p0_p0 :G_p0_p1 :C_p0_m1 :C_p0_p1];
            [pixel setValue:newC forComponent:vComponent];
        }
        
        [self.outImage setPixel:pixel.data atX:x y:y];
    }
}

// Calculates Red (Blue) where Blue (Red) defined
- (void)calculate:(ColorComponent)component where:(ColorComponent)definedComponent definedAtX:(NSInteger)x andY:(NSInteger)y {
    @autoreleasepool {
        if(x - 2 < minX || y - 2 < minY) { return; }
        if(x + 2 >= maxX && y + 2 >= maxY) { return; }
        
        // NE
        NSInteger C_p1_p1 = [self colorComponent:component atX:(x + 1) andY:(y + 1)];
        NSInteger C_m1_m1 = [self colorComponent:component atX:(x - 1) andY:(y - 1)];
        
        NSInteger DC_p2_p2 = [self colorComponent:definedComponent atX:(x + 2) andY:(y + 2)];
        NSInteger DC_p0_p0 = [self colorComponent:definedComponent atX:x andY:y];
        NSInteger DC_m2_m2 = [self colorComponent:definedComponent atX:(x - 2) andY:(y - 2)];
        
        NSInteger G_p1_p1 = [self gAtX:(x + 1) andY:(y + 1)];
        NSInteger G_p0_p0 = [self gAtX:x andY:y];
        NSInteger G_m1_m1 = [self gAtX:(x - 1) andY:(y - 1)];
        
        NSInteger dNE = ABS(C_p1_p1 - C_m1_m1) + ABS(DC_p2_p2 - DC_p0_p0) + ABS(DC_p0_p0 - DC_m2_m2) + ABS(G_p1_p1 - G_p0_p0) + ABS(G_p0_p0 - G_m1_m1);
        
        // NW
        NSInteger C_m1_p1 = [self colorComponent:component atX:(x - 1) andY:(y + 1)];
        NSInteger C_p1_m1 = [self colorComponent:component atX:(x + 1) andY:(y - 1)];
        
        NSInteger DC_m2_p2 = [self colorComponent:definedComponent atX:(x - 2) andY:(y + 2)];
        //NSInteger DC_p0_p0 = [self colorComponent:definedComponent atX:x andY:y];
        NSInteger DC_p2_m2 = [self colorComponent:definedComponent atX:(x + 2) andY:(y - 2)];
        
        NSInteger G_m1_p1 = [self gAtX:(x - 1) andY:(y + 1)];
        //NSInteger G_p0_p0 = [self gAtX:x andY:y];
        NSInteger G_p1_m1 = [self gAtX:(x + 1) andY:(y - 1)];
        
        NSInteger dNW = ABS(C_m1_p1 - C_p1_m1) + ABS(DC_m2_p2 - DC_p0_p0) + ABS(DC_p0_p0 - DC_p2_m2) + ABS(G_m1_p1 - G_p0_p0) + ABS(G_p0_p0 - G_p1_m1);
        
        //Update
        Pixel* pixel = [Pixel new];
        [self.inImage getPixel:pixel.data atX:x y:y];
        NSInteger newC;
        
        if(dNE < dNW) {
            newC = [self hueTransit:G_p1_p1 :G_p0_p0 :G_m1_m1 :C_p1_p1 :C_m1_m1];
        } else {
            newC = [self hueTransit:G_m1_p1 :G_p0_p0 :G_p1_m1 :C_m1_p1 :C_p1_m1];
        }
        
        [pixel setValue:newC forComponent:component];
        [self.outImage setPixel:pixel.data atX:x y:y];
    }
}

#pragma mark - Tools

#pragma mark - Tools: Algorithm Parts

- (void)setMinIn:(Stage1MinGradient*)min for:(NSUInteger)gradient andDirection:(Stage1GradientDirection)direction {
    if(gradient < min->gradient) {
        min->gradient = gradient;
        min->direction = direction;
    }
}

- (NSInteger)hueTransit:(NSInteger)l1 :(NSInteger)l2 :(NSInteger)l3 :(NSInteger)v1 :(NSInteger)v3   {
    if((l1 < l2 && l2 < l3) || (l1 > l2 && l2 > l3)) {
        return v1 + (v3 - v1) * (l2 - l1) / (l3 - l1);
    } else {
        return (v1 + v3) / 2 + (l2 - (l1 + l3) / 2) / 2;
    }
}

#pragma mark - Tools: Work With Pixels

- (NSInteger)rAtX:(NSInteger)x andY:(NSInteger)y {
    Pixel* pixel = [Pixel new];
    [self.inImage getPixel:pixel.data atX:x y:y];
    return pixel.r;
}

- (NSInteger)gAtX:(NSInteger)x andY:(NSInteger)y {
    Pixel* pixel = [Pixel new];
    [self.inImage getPixel:pixel.data atX:x y:y];
    return pixel.g;
}

- (NSInteger)bAtX:(NSInteger)x andY:(NSInteger)y {
    Pixel* pixel = [Pixel new];
    [self.inImage getPixel:pixel.data atX:x y:y];
    return pixel.b;
}

- (NSInteger)colorComponent:(ColorComponent)component atX:(NSInteger)x andY:(NSInteger)y {
    Pixel* pixel = [Pixel new];
    [self.inImage getPixel:pixel.data atX:x y:y];
    return [pixel getByColorComponent:component];
}

- (CGFloat)lAtX:(NSInteger)x andY:(NSInteger)y forImage:(NSBitmapImageRep*)image {
    Pixel* pixel = [Pixel new];
    [image getPixel:pixel.data atX:x y:y];
    return pixel.l;
}

#pragma mark - Printers

- (void)debugInPrintAtX:(NSInteger)x andY:(NSInteger)y {
    Pixel* pixel = [Pixel new];
    [self.inImage getPixel:pixel.data atX:x y:y];
    NSLog(@"| X:%04ld Y:%04ld | R:%03ld | G:%03ld | B:%03ld |", x, y, pixel.r, pixel.g, pixel.b);
}

- (void)debugOutPrintAtX:(NSInteger)x andY:(NSInteger)y {
    Pixel* pixel = [Pixel new];
    [self.outImage getPixel:pixel.data atX:x y:y];
    NSLog(@"| X:%04ld Y:%04ld | R:%03ld | G:%03ld | B:%03ld |", x, y, pixel.r, pixel.g, pixel.b);
}

#pragma mark - PSNR

- (CGFloat)maxL {
    Pixel* pixel = [Pixel new];
    [pixel setR:255];
    [pixel setG:255];
    [pixel setB:255];
    return pixel.l;
}

- (CGFloat)mse {
    CGFloat mse = 0.0;
    
    for(NSInteger iX = 0; iX < maxX; ++iX) {
        for(NSInteger iY = 0; iY < maxY; ++iY) {
            @autoreleasepool {
                mse += pow(fabs([self lAtX:iX andY:iY forImage:self.inImage] - [self lAtX:iX andY:iY forImage:self.originalImage]), 2);
            }
        }
    }
    
    return mse * 1.0/maxX * 1.0/maxY;
}

- (CGFloat)psnr {
    CGFloat maxL = [self maxL];
    CGFloat mse = [self mse];
    
    return 10 * log10(pow(maxL, 2) / mse);
}

@end
