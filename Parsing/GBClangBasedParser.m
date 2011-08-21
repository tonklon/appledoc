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

@interface GBClangBasedParser (StoreManagement)

/** Registers the entity with the parsers store
 
 The type of the entity is inspected to determin with which property of the store
 the entity should be registerd.
 
 @param entity The entity to register.
 */
- (void)registerEntityWithStore:(GBModelBase*)entity;
- (void)registerClassWithStore:(GBClassData *)class;
- (void)registerCategoryWithStore:(GBCategoryData *)category;
- (void)registerProtocolWithStore:(GBProtocolData *)protocol;

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
  
  GBModelBase* entity;
  while ((entity = [self.tokenizer getNextEntity]) != nil) {
    [self registerEntityWithStore:entity];
  }
  
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
          @"-isysroot/Developer/SDKs/MacOSX10.7.sdk",
          @"-xobjective-c",
          nil];
}

@end

@implementation GBClangBasedParser (StoreManagement)

- (void)registerEntityWithStore:(GBModelBase*)entity {
  if ([entity isKindOfClass:[GBClassData class]]) {
    GBClassData* class = (GBClassData*)entity;
    [self registerClassWithStore:class];
  }
  if ([entity isKindOfClass:[GBProtocolData class]]) {
    GBProtocolData* protocol = (GBProtocolData*)entity;
    [self registerProtocolWithStore:protocol];
  }
  if ([entity isKindOfClass:[GBCategoryData class]]) {
    GBCategoryData* category = (GBCategoryData*)entity;
    [self registerCategoryWithStore:category];
  }
}

- (void)registerClassWithStore:(GBClassData *)class {
  NSParameterAssert([class isKindOfClass:[GBClassData class]]);
  [self.store registerClass:class];
}

- (void)registerCategoryWithStore:(GBCategoryData *)category {
  NSParameterAssert([category isKindOfClass:[GBCategoryData class]]);
  [self.store registerCategory:category];
}

- (void)registerProtocolWithStore:(GBProtocolData *)protocol {
  NSParameterAssert([protocol isKindOfClass:[GBProtocolData class]]);
  [self.store registerProtocol:protocol];
}

@end
