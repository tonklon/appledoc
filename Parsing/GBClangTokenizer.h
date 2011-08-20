//
//  GBClangTokenizer.h
//  appledoc
//
//  Created by Tobias Klonk on 20.08.11.
//  Copyright (c) 2011 Gentle Bytes. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "clang-c/Index.h"

@interface GBClangTokenizer : NSObject

+ (id)tokenizerWithContents:(NSString*)contents filename:(NSString*)filename arguments:(NSArray*)arguments index:(CXIndex)index;

- (id)initWithContents:(NSString*)contents filename:(NSString*)filename arguments:(NSArray*)arguments index:(CXIndex)index;

@end
