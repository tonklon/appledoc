//
//  GBClangTokenizer.h
//  appledoc
//
//  Created by Tobias Klonk on 20.08.11.
//  Copyright (c) 2011 Gentle Bytes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "clang-c/Index.h"

@class GBModelBase;

@interface GBClangTokenizer : NSObject

+ (id)tokenizerWithContents:(NSString*)contents filename:(NSString*)filename arguments:(NSArray*)arguments index:(CXIndex)index;

- (id)initWithContents:(NSString*)contents filename:(NSString*)filename arguments:(NSArray*)arguments index:(CXIndex)index;

/**
 * Get the next entity in the file
 *
 * @return Returns subclass of GBModelBase or nil if all entities are already processed
 */
- (GBModelBase*)getNextEntity;

@end
