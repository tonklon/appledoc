//
//  GBClangTokenizer.m
//  appledoc
//
//  Created by Tobias Klonk on 20.08.11.
//  Copyright (c) 2011 Gentle Bytes. All rights reserved.
//

#import "GBClangTokenizer.h"
#import "GBDataObjects.h"
#import "GBSourceInfo.h"

@interface GBClangTokenizer ()

@property (copy) NSString* contents;
@property (copy) NSString* filename;
@property (assign) CXIndex index;
@property (assign) CXTranslationUnit tu;
@property (assign) CXFile file;
@property (assign) CXToken* tokens;
@property (assign) unsigned tokenCount;
@property (assign) CXCursor* cursors;
@property (assign) unsigned currentToken;
@property (assign) CXCursorSet processedCursors;
  
- (void)createTranslationUnitWithArguments:(NSArray*)arguments;
- (void)tokenize;
- (void)annotateTokens;
- (void)prepareForIteration;
- (GBModelBase*)currentEntity;
- (GBClassData*)classEntityFromCurrentCursor;
- (GBCategoryData*)categoryEntityFromCurrentCursor;
- (GBProtocolData*)protocolEntityFromCurrentCursor;
- (GBSourceInfo*)sourceInfoForCurrentToken;
- (GBSourceInfo*)sourceInfoForTokenNumber:(unsigned)tokenNumber;
- (GBComment*)findLastComment;
- (NSString*)stripCommentEnclosure:(NSString*)enclosedComment;

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
    [self annotateTokens];
    [self prepareForIteration];
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
@synthesize cursors;
@synthesize currentToken;
@synthesize processedCursors;

- (void)dealloc {
  clang_disposeTokens(self.tu, self.tokens, self.tokenCount);
  clang_disposeTranslationUnit(self.tu);
  clang_disposeCXCursorSet(self.processedCursors);
  
  free(self.cursors);
  
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

- (void)annotateTokens {
  CXCursor *localCursors = NULL;
  
  localCursors = calloc(sizeof(CXCursor), tokenCount);
  clang_annotateTokens(self.tu, self.tokens, self.tokenCount, localCursors);
  
  self.cursors = localCursors;
}

#define CX2NS_STRING(name, value)\
CXString name ## str = value;\
const char *name ## C = clang_getCString(name ## str);\
NSString* name = [NSString stringWithUTF8String:name ## C];\
clang_disposeString( name ## str);


- (void)prepareForIteration {
  self.processedCursors = clang_createCXCursorSet();
  self.currentToken = 0;
}

- (GBModelBase*)currentEntity {
  
  CXCursor currentCursor = cursors[currentToken];
  
  if (0 == clang_CXCursorSet_contains(processedCursors, currentCursor)) {
    return nil;
  }
  
  clang_CXCursorSet_insert(processedCursors, currentCursor);
  
  switch (currentCursor.kind)
  {
    case CXCursor_ClassDecl:
    case CXCursor_ObjCInterfaceDecl:
    case CXCursor_ObjCImplementationDecl:
      return [self classEntityFromCurrentCursor];
      break;
      
    case CXCursor_ObjCCategoryDecl:
    case CXCursor_ObjCCategoryImplDecl:
      return [self categoryEntityFromCurrentCursor];
      break;
      
    case CXCursor_ObjCProtocolDecl:
      return [self protocolEntityFromCurrentCursor];
      break;
      
    default:
      return nil;
      break;
   }
  
  return nil;
}

- (GBClassData*)classEntityFromCurrentCursor {
  
  CXCursor currentCursor = cursors[currentToken];
  
  CX2NS_STRING(className, clang_getCursorSpelling(currentCursor));
  
  GBClassData* class = [[GBClassData alloc] initWithName:className];
  [class registerSourceInfo:[self sourceInfoForCurrentToken]];
  
  clang_visitChildrenWithBlock(currentCursor,
    ^enum CXChildVisitResult (CXCursor current, CXCursor parent){
      
      switch (current.kind) {
        case CXCursor_ObjCSuperClassRef:
        {
          CX2NS_STRING(superclass, clang_getCursorSpelling(current));
          class.nameOfSuperclass = superclass;
          break;
        }
        case CXCursor_ObjCProtocolRef:
        {
          CX2NS_STRING(protocolName, clang_getCursorSpelling(current));
          GBProtocolData *protocol = [[GBProtocolData alloc] initWithName:protocolName];
          [class.adoptedProtocols registerProtocol:protocol];
          break;
        }
        case CXCursor_ObjCClassMethodDecl:
        case CXCursor_ObjCInstanceMethodDecl:
        {
          CX2NS_STRING(methodName, clang_getCursorSpelling(current));
          
          NSArray* argumentNames = [methodName componentsSeparatedByString:@":"];
          
          CXType type = clang_getCursorResultType(current);
          
          NSString* typeName = nil;
          if (0 == clang_isPODType(type)) {
            CX2NS_STRING(typeKind, clang_getTypeKindSpelling(type.kind));
            typeName = typeKind;
          } else {
            CXCursor typeCursor = clang_getTypeDeclaration(type);
            CX2NS_STRING(declarationName, clang_getCursorSpelling(typeCursor));
            typeName = declarationName;
          }
          
          NSMutableArray* methodArguments = [NSMutableArray array];
          
          clang_visitChildrenWithBlock(current,
            ^enum CXChildVisitResult (CXCursor current, CXCursor parent){
              switch (current.kind) {
                case CXCursor_ParmDecl:
                {
                  CX2NS_STRING(name, clang_getCursorSpelling(current));
                 
                  CXType type = clang_getCursorType(current);
                  NSString* typeName = nil;
                  if (0 == clang_isPODType(type)) {
                    CX2NS_STRING(typeKind, clang_getTypeKindSpelling(type.kind));
                    typeName = typeKind;
                  } else {
                    CXCursor typeCursor = clang_getTypeDeclaration(type);
                    CX2NS_STRING(declarationName, clang_getCursorSpelling(typeCursor));
                    typeName = declarationName;
                  }
                  
                  NSString* argumentName = [argumentNames objectAtIndex:[methodArguments count]];
                  GBMethodArgument* argument = [[GBMethodArgument alloc] initWithName:argumentName types:[NSArray arrayWithObject:typeName] var:[NSArray arrayWithObject:name] terminationMacros:nil];
                  [methodArguments addObject:argument];
                  
                  break;  
                }
                default: {

                  break;
                }
              }
              return CXChildVisit_Continue;                        
            });
          
          GBMethodType methodKind;
          if (current.kind == CXCursor_ObjCInstanceMethodDecl) {
            methodKind = GBMethodTypeInstance;
          } else {
            methodKind = GBMethodTypeClass;
          }
          
          // If no arguments, we still need one to transport the method name
          if ([methodArguments count] == 0) {
            GBMethodArgument* noRealArgument = [[GBMethodArgument alloc] initWithName:[argumentNames objectAtIndex:0] types:[NSArray array] var:nil terminationMacros:nil];
            [methodArguments addObject:noRealArgument];
          }

          GBMethodData* method = [[GBMethodData alloc] initWithType:methodKind attributes:nil result:[NSArray arrayWithObject:typeName] arguments:methodArguments];
          
          [class.methods registerMethod:method];
          break;
        }
        case CXCursor_ObjCPropertyDecl: {

          break;
        }
        default:
        {
          break;
        }
      }
      
      
      return CXChildVisit_Continue;
  });
  
  GBComment* comment = [self findLastComment];
  
  if (comment) {
    class.comment =comment;
  }
  
  return class;
}

- (GBCategoryData*)categoryEntityFromCurrentCursor {
  
  CXCursor currentCursor = cursors[currentToken];
  
  CX2NS_STRING(categoryName, clang_getCursorSpelling(currentCursor));
  
  __block NSString* className = nil;
  NSMutableArray* adoptedProtocols = [NSMutableArray array];
  NSMutableArray* methods = [NSMutableArray array];
  
  
  clang_visitChildrenWithBlock(currentCursor,
    ^enum CXChildVisitResult (CXCursor current, CXCursor parent){
      
      switch (current.kind) {
        case CXCursor_ObjCClassRef:
        {
          
          CX2NS_STRING(localClassName, clang_getCursorSpelling(current));
          className = localClassName;
          
          break;
        }
        case CXCursor_ObjCProtocolRef:
        {
          CX2NS_STRING(protocolName, clang_getCursorSpelling(current));
          GBProtocolData *protocol = [[GBProtocolData alloc] initWithName:protocolName];
          [adoptedProtocols addObject:protocol];
          break;
        }
        case CXCursor_ObjCClassMethodDecl:
        case CXCursor_ObjCInstanceMethodDecl:
        {
          CX2NS_STRING(methodName, clang_getCursorSpelling(current));
          
          NSArray* argumentNames = [methodName componentsSeparatedByString:@":"];
          
          CXType type = clang_getCursorResultType(current);
          
          NSString* typeName = nil;
          if (0 == clang_isPODType(type)) {
            CX2NS_STRING(typeKind, clang_getTypeKindSpelling(type.kind));
            typeName = typeKind;
          } else {
            CXCursor typeCursor = clang_getTypeDeclaration(type);
            CX2NS_STRING(declarationName, clang_getCursorSpelling(typeCursor));
            typeName = declarationName;
          }
          
          NSMutableArray* methodArguments = [NSMutableArray array];
          
          clang_visitChildrenWithBlock(current,
                                       ^enum CXChildVisitResult (CXCursor current, CXCursor parent){
                                         switch (current.kind) {
                                           case CXCursor_ParmDecl:
                                           {
                                             CX2NS_STRING(name, clang_getCursorSpelling(current));
                                             
                                             CXType type = clang_getCursorType(current);
                                             NSString* typeName = nil;
                                             if (0 == clang_isPODType(type)) {
                                               CX2NS_STRING(typeKind, clang_getTypeKindSpelling(type.kind));
                                               typeName = typeKind;
                                             } else {
                                               CXCursor typeCursor = clang_getTypeDeclaration(type);
                                               CX2NS_STRING(declarationName, clang_getCursorSpelling(typeCursor));
                                               typeName = declarationName;
                                             }
                                             
                                             NSString* argumentName = [argumentNames objectAtIndex:[methodArguments count]];
                                             GBMethodArgument* argument = [[GBMethodArgument alloc] initWithName:argumentName types:[NSArray arrayWithObject:typeName] var:[NSArray arrayWithObject:name] terminationMacros:nil];
                                             [methodArguments addObject:argument];
                                             
                                             break;  
                                           }
                                           default: {
                                             
                                             break;
                                           }
                                         }
                                         return CXChildVisit_Continue;                        
                                       });
          
          GBMethodType methodKind;
          if (current.kind == CXCursor_ObjCInstanceMethodDecl) {
            methodKind = GBMethodTypeInstance;
          } else {
            methodKind = GBMethodTypeClass;
          }
          
          // If no arguments, we still need one to transport the method name
          if ([methodArguments count] == 0) {
            GBMethodArgument* noRealArgument = [[GBMethodArgument alloc] initWithName:[argumentNames objectAtIndex:0] types:[NSArray array] var:nil terminationMacros:nil];
            [methodArguments addObject:noRealArgument];
          }
          
          GBMethodData* method = [[GBMethodData alloc] initWithType:methodKind attributes:nil result:[NSArray arrayWithObject:typeName] arguments:methodArguments];
          
          [methods addObject:method];
          break;
        }
        default:
        {
          CX2NS_STRING(kind, clang_getCursorKindSpelling(current.kind));
          CX2NS_STRING(name, clang_getCursorSpelling(current));
          
          NSLog(@"%@ %@",kind,name);
          break;
        }
      }
      
      return CXChildVisit_Continue;
    });
  

  if ([[categoryName stringByTrimmingWhitespaceAndNewLine] length] == 0) {
    categoryName = nil;
  }
  
  GBCategoryData* category = [[GBCategoryData alloc] initWithName:categoryName className:className];
  [category registerSourceInfo:[self sourceInfoForCurrentToken]];
  
  for (GBProtocolData* protocol in adoptedProtocols) {
    [category.adoptedProtocols registerProtocol:protocol];
  }
  
  for (GBMethodData* method in methods) {
    [category.methods registerMethod:method];
  }
  
  GBComment* comment = [self findLastComment];
  
  category.comment = comment;

  return category;
}

- (GBProtocolData*)protocolEntityFromCurrentCursor {
  return nil;
}

- (GBSourceInfo*)sourceInfoForCurrentToken {
  
  return [self sourceInfoForTokenNumber:currentToken];
}

- (GBSourceInfo*)sourceInfoForTokenNumber:(unsigned)tokenNumber {
  CXSourceLocation location = clang_getTokenLocation(self.tu, tokens[tokenNumber]);
  CXFile theFile;
  unsigned theLine;
  
  clang_getInstantiationLocation(location, &theFile, &theLine, NULL, NULL);
  
  CX2NS_STRING(fileName, clang_getFileName(theFile));
  
  return [GBSourceInfo infoWithFilename:fileName lineNumber:theLine];
}

- (GBComment*)findLastComment {
  unsigned possibleCommentTokenIdx = currentToken;
  
  NSString* lastComment = nil;
  
  while ((possibleCommentTokenIdx > 0) && (lastComment == nil)) {
    
    possibleCommentTokenIdx--;
    
    CXToken possibleCommentToken = tokens[possibleCommentTokenIdx];
    
    if (clang_getTokenKind(possibleCommentToken) == CXToken_Comment) {
      CX2NS_STRING(commentContents, clang_getTokenSpelling(self.tu, possibleCommentToken));
      lastComment = commentContents;
    }
  }
  
  if ([[lastComment stringByTrimmingWhitespaceAndNewLine] length] == 0) {
    return nil;
  }

  lastComment = [self stripCommentEnclosure:lastComment];
  
  GBSourceInfo* sourceInfo = [self sourceInfoForTokenNumber:possibleCommentTokenIdx];
  
  GBComment* comment = [GBComment commentWithStringValue:lastComment sourceInfo:sourceInfo];
  
  return comment;
}

- (NSString*)stripCommentEnclosure:(NSString*)enclosedComment {
  NSString* workingCopy = enclosedComment;
  
  NSCharacterSet* slashCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"/"];
  workingCopy = [workingCopy stringByTrimmingCharactersInSet:slashCharacterSet];
  
  NSCharacterSet* starCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"*"];
  workingCopy = [workingCopy stringByTrimmingCharactersInSet:starCharacterSet];
  
  workingCopy = [workingCopy stringByTrimmingWhitespaceAndNewLine];
  
  return workingCopy;
}

#pragma mark - public

- (GBModelBase*)getNextEntity {

  GBModelBase* nextEntity = nil;
  
  while ((self.currentToken < self.tokenCount) && (nil == nextEntity)) {
    nextEntity = [self currentEntity];
    self.currentToken++;
  }
  
  return nextEntity;
}


@end
