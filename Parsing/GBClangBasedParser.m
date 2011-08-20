//
//  GBClangBasedParser.m
//  appledoc
//
//  Created by Tobias Klonk on 20.08.11.
//  Copyright (c) 2011 Tobias Klonk. All rights reserved.
//

#import "GBClangBasedParser.h"
#import "GBStore.h"
#import "GBApplicationSettingsProvider.h"
#import "GBDataObjects.h"
#import "clang-c/Index.h"
#import "GBClangTokenizer.h"

@interface GBClangBasedParser ()

@property (retain) GBStore *store;
@property (retain) GBApplicationSettingsProvider *settings;
@property (assign) CXIndex index;
@property (retain) GBClangTokenizer* tokenizer;

@end

@interface GBClangBasedParser (ClangInterface)

- (NSArray*)clangArgumentsForFilename:(NSString*)filename;

@end

#pragma mark -

@implementation GBClangBasedParser

#pragma mark ￼Initialization & disposal

+ (id)parserWithSettingsProvider:(id)settingsProvider {
	return [[[self alloc] initWithSettingsProvider:settingsProvider] autorelease];
}

- (id)initWithSettingsProvider:(id)settingsProvider {
	NSParameterAssert(settingsProvider != nil);
	GBLogDebug(@"Initializing clang-based parser with settings provider %@...", settingsProvider);
	self = [super init];
	if (self) {
		self.settings = settingsProvider;
    self.index = clang_createIndex(1, 0);
	}
	return self;
}

#pragma mark Parsing handling

- (void)parseObjectsFromString:(NSString *)input sourceFile:(NSString *)filename toStore:(id)store {
	NSParameterAssert(input != nil);
	NSParameterAssert(filename != nil);
	NSParameterAssert([filename length] > 0);
	NSParameterAssert(store != nil);
	GBLogDebug(@"Parsing file...");
	self.store = store;

  NSArray* arguments = [self clangArgumentsForFilename:filename];
  
  self.tokenizer = [GBClangTokenizer tokenizerWithContents:input filename:filename arguments:arguments index:self.index];
  
  
}

#pragma mark Properties

@synthesize settings;
@synthesize store;
@synthesize index;
@synthesize tokenizer;

- (void)dealloc {
  clang_disposeIndex(self.index);
  
  [super dealloc];
}

@end

@implementation GBClangBasedParser (ClangInterface)

- (NSArray*)clangArgumentsForFilename:(NSString*)filename {
  return [NSArray arrayWithObjects:
          @"-isysroot/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator5.0.sdk" ,
          @"-xobjective-c",
          @"-std=gnu99",
          @"-D__IPHONE_OS_VERSION_MIN_REQUIRED=30000",
          nil];
}

@end
