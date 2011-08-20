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

@interface GBClangBasedParser ()

@property (retain) GBStore *store;
@property (retain) GBApplicationSettingsProvider *settings;
@property (assign) CXIndex index;
@property (assign) CXTranslationUnit translationUnit;
@property (assign) CXFile file;

@end

@interface GBClangBasedParser (ClangInterface)

- (NSArray*)clangArgumentsForFilename:(NSString*)filename;
- (void)createTranslationUnitWithContents:(NSString*)input filename:(NSString*)filename
                                arguments:(NSArray*)arguments;

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
  [self createTranslationUnitWithContents:input filename:filename arguments:arguments];
}

#pragma mark Properties

@synthesize settings;
@synthesize store;
@synthesize index;
@synthesize translationUnit;
@synthesize file;

- (void)dealloc {
  clang_disposeIndex(self.index);
  clang_disposeTranslationUnit(self.translationUnit);
  
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

- (void)createTranslationUnitWithContents:(NSString*)input
                                 filename:(NSString*)filename
                                arguments:(NSArray*)arguments {
  
  GBLogDebug(@"Creating translation unit...");

  const char *fn = [filename UTF8String];
	struct CXUnsavedFile unsaved[] = {
		{fn, [input UTF8String], [input length]},
		{NULL, NULL, 0}};
  
	self.file = NULL;
	if (NULL != self.translationUnit)
	{
    clang_disposeTranslationUnit(self.translationUnit);
  }
  
  const char *mainFile = fn;
  unsigned argc = [arguments count];
  const char *argv[argc];
  int i=0;
  for (NSString *arg in arguments)
  {
    argv[i++] = [arg UTF8String];
  }
  int unsavedCount = 1;
  if ([@"h" isEqualToString: [filename pathExtension]])
  {
    unsaved[1].Filename = "/tmp/foo.m";
    unsaved[1].Contents = [[NSString stringWithFormat: @"#import \"%@\"\n", filename] UTF8String];
    unsaved[1].Length = strlen(unsaved[1].Contents);
    mainFile = unsaved[1].Filename;
    unsavedCount = 2;
  }
  self.translationUnit =
  clang_createTranslationUnitFromSourceFile(self.index, fn, argc, argv, unsavedCount, unsaved);
  
  NSAssert(self.translationUnit != NULL, @"failed to create translation unit");
  
  self.file = clang_getFile(self.translationUnit, fn);
  
  NSAssert(self.file != NULL, @"failed to create file");
  
}

@end
