//
//  PPG.h
//  PPG
//
//  Created by Alexander Danilyak on 12/10/2016.
//  Copyright © 2016 mipt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

@interface PPG : NSObject

@property (nonatomic) NSBitmapImageRep* inImage;
@property (nonatomic) NSBitmapImageRep* outImage;
@property (nonatomic) NSBitmapImageRep* originalImage;

- (instancetype)init;
- (void)loadInImage;
- (void)makePPG;

@end
