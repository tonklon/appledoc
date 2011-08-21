//
//  GBClangBasedParser-IvarsParsingTesting.m
//  appledoc
//
//  Created by Tobias Klonk on 21.8.11.
//  Copyright (C) 2010 Gentle Bytes. All rights reserved.
//

#import "GBStore.h"
#import "GBDataObjects.h"
#import "GBClangBasedParser.h"

@interface GBClangBasedParserIvarsParsingTesting : GBObjectsAssertor
@end

@implementation GBClangBasedParserIvarsParsingTesting

#pragma mark Ivars parsing testing

- (void)testParseObjectsFromString_shouldIgnoreIVar {
	// setup
	GBClangBasedParser *parser = [GBClangBasedParser parserWithSettingsProvider:[GBTestObjectsRegistry mockSettingsProvider]];
	GBStore *store = [[GBStore alloc] init];
	// execute
	[parser parseObjectsFromString:@"@interface MyClass { int _var; } @end" sourceFile:@"filename.h" toStore:store];
	// verify
	GBClassData *class = [[store classes] anyObject];
	NSArray *ivars = [[class ivars] ivars];
	assertThatInteger([ivars count], equalToInteger(0));
}

- (void)testParseObjectsFromString_shouldIgnoreAllIVars {
	// setup
	GBClangBasedParser *parser = [GBClangBasedParser parserWithSettingsProvider:[GBTestObjectsRegistry mockSettingsProvider]];
	GBStore *store = [[GBStore alloc] init];
	// execute
	[parser parseObjectsFromString:@"@interface MyClass { int _var1; long _var2; } @end" sourceFile:@"filename.h" toStore:store];
	// verify
	GBClassData *class = [[store classes] anyObject];
	NSArray *ivars = [[class ivars] ivars];
	assertThatInteger([ivars count], equalToInteger(0));
}

- (void)testParseObjectsFromString_shouldIgnoreComplexIVar {
	// setup
	GBClangBasedParser *parser = [GBClangBasedParser parserWithSettingsProvider:[GBTestObjectsRegistry mockSettingsProvider]];
	GBStore *store = [[GBStore alloc] init];
	// execute
	[parser parseObjectsFromString:@"@interface MyClass { id<Protocol>* _var; } @end" sourceFile:@"filename.h" toStore:store];
	// verify
	GBClassData *class = [[store classes] anyObject];
	NSArray *ivars = [[class ivars] ivars];
	assertThatInteger([ivars count], equalToInteger(0));
}

- (void)testParseObjectsFromString_shouldIgnoreIVarEndingWithParenthesis {
	// setup
	GBClangBasedParser *parser = [GBClangBasedParser parserWithSettingsProvider:[GBTestObjectsRegistry mockSettingsProvider]];
	GBStore *store = [[GBStore alloc] init];
	// execute
	[parser parseObjectsFromString:@"@interface MyClass { void (^_name)(id obj, NSUInteger idx, BOOL *stop); } @end" sourceFile:@"filename.h" toStore:store];
	// verify
	GBClassData *class = [[store classes] anyObject];
	NSArray *ivars = [[class ivars] ivars];
	assertThatInteger([ivars count], equalToInteger(0));
}

@end
