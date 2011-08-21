//
//  GBClangBasedParser-AdoptedProtocolsParsingTesting.m
//  appledoc
//
//  Created by Tobias Klonk on 21.8.11.
//  Copyright (C) 2010 Gentle Bytes. All rights reserved.
//

#import "GBStore.h"
#import "GBDataObjects.h"
#import "GBClangBasedParser.h"

// Note that we use class for invoking parsing of adopted protocols. Probably not the best option - i.e. we could isolate parsing code altogether and only parse relevant stuff here, but it seemed not much would be gained by doing this. Separating unit tests does avoid repetition in top-level objects testing code - we only need to test specific data there.

@interface GBClangBasedParserAdoptedProtocolsParsingTesting : GBObjectsAssertor
@end

@implementation GBClangBasedParserAdoptedProtocolsParsingTesting

- (void)testParseObjectsFromString_shouldRegisterAdoptedProtocol {
	// setup
	GBClangBasedParser *parser = [GBClangBasedParser parserWithSettingsProvider:[GBTestObjectsRegistry mockSettingsProvider]];
	GBStore *store = [[GBStore alloc] init];
	// execute
	[parser parseObjectsFromString:@"@interface MyClass <MyProtocol> @end" sourceFile:@"filename.h" toStore:store];
	// verify
	NSArray *protocols = [[[[store classes] anyObject] adoptedProtocols] protocolsSortedByName];
	assertThatInteger([protocols count], equalToInteger(1));
	assertThat([[protocols objectAtIndex:0] nameOfProtocol], is(@"MyProtocol"));
}

- (void)testParseObjectsFromString_shouldRegisterAllAdoptedProtocols {
	// setup
	GBClangBasedParser *parser = [GBClangBasedParser parserWithSettingsProvider:[GBTestObjectsRegistry mockSettingsProvider]];
	GBStore *store = [[GBStore alloc] init];
	// execute
	[parser parseObjectsFromString:@"@interface MyClass <MyProtocol1, MyProtocol2> @end" sourceFile:@"filename.h" toStore:store];
	// verify
	NSArray *protocols = [[[[store classes] anyObject] adoptedProtocols] protocolsSortedByName];
	assertThatInteger([protocols count], equalToInteger(2));
	assertThat([[protocols objectAtIndex:0] nameOfProtocol], is(@"MyProtocol1"));
	assertThat([[protocols objectAtIndex:1] nameOfProtocol], is(@"MyProtocol2"));
}

@end
