//
//  GBClangTokenizer.m
//  appledoc
//
//  Created by Tobias Klonk on 20.08.11.
//  Copyright (c) 2011 Gentle Bytes. All rights reserved.
//

#import "GBClangTokenizer.h"

@interface GBClangTokenizer ()

@property (copy) NSString* contents;
@property (copy) NSString* filename;
@property (assign) CXIndex index;
@property (assign) CXTranslationUnit tu;
@property (assign) CXFile file;
@property (assign) CXToken* tokens;
@property (assign) unsigned tokenCount;
  
- (void)createTranslationUnitWithArguments:(NSArray*)arguments;
- (void)tokenize;

@end

@implementation GBClangTokenizer

+ (id)tokenizerWithContents:(NSString*)contents filename:(NSString*)filename arguments:(NSArray*)arguments index:(CXIndex)index {
  return [[self alloc] initWithContents:(NSString*)contents filename:(NSString*)filename arguments:(NSArray*)arguments index:(CXIndex)index];
}

- (id)initWithContents:(NSString*)contents filename:(NSString*)filename arguments:(NSArray*)arguments index:(CXIndex)index {
  if (self = [super init]) {
    self.contents = contents;
    self.filename = filename;
    self.index = index;
    
    [self createTranslationUnitWithArguments:arguments];
    [self tokenize];
  }
  return self;
}

@synthesize contents;
@synthesize filename;
@synthesize index;
@synthesize tu;
@synthesize file;
@synthesize tokens;
@synthesize tokenCount;

- (void)dealloc {
  clang_disposeTokens(self.tu, self.tokens, self.tokenCount);
  clang_disposeTranslationUnit(self.tu);

  [super dealloc];
}

- (void)createTranslationUnitWithArguments:(NSArray*)arguments {
  
  GBLogDebug(@"Creating translation unit...");
  
  const char *fn = [self.filename UTF8String];
	struct CXUnsavedFile unsaved[] = {
		{fn, [self.contents UTF8String], [self.contents length]},
		{NULL, NULL, 0}};
  
	self.file = NULL;
	if (NULL != self.tu)
	{
    clang_disposeTranslationUnit(self.tu);
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
  self.tu =
  clang_createTranslationUnitFromSourceFile(self.index, fn, argc, argv, unsavedCount, unsaved);
  
  NSAssert(self.tu != NULL, @"failed to create translation unit");
  
  self.file = clang_getFile(self.tu, fn);
  
  NSAssert(self.file != NULL, @"failed to create file");
  
}

- (void)tokenize {
  
  CXSourceLocation start = clang_getLocationForOffset(self.tu, self.file, 0);
	CXSourceLocation end = clang_getLocationForOffset(self.tu, self.file, [self.contents length]);
  CXSourceRange wholeFileRange = clang_getRange(start, end);
  
	if (clang_equalLocations(clang_getRangeStart(wholeFileRange), clang_getRangeEnd(wholeFileRange)))
	{
		GBLogDebug(@"File is empty. Nothing to do...");
		return;
	}
  
  
  GBLogDebug(@"Tokenizing...");
	
  CXToken* localTokens;
  unsigned numOfTokens;
	
  clang_tokenize(self.tu, wholeFileRange , &localTokens, &numOfTokens);
	GBLogDebug(@"Found %i tokens", numOfTokens);
  
  self.tokens = localTokens;
  self.tokenCount = numOfTokens;
  
}

 
@end
