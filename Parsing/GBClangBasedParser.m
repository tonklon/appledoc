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

@interface GBClangBasedParser ()

@property (retain) GBStore *store;
@property (retain) GBApplicationSettingsProvider *settings;

@end

#pragma mark -

@implementation GBClangBasedParser

#pragma mark ￼Initialization & disposal

+ (id)parserWithSettingsProvider:(id)settingsProvider {
	return [[[self alloc] initWithSettingsProvider:settingsProvider] autorelease];
}

- (id)initWithSettingsProvider:(id)settingsProvider {
	NSParameterAssert(settingsProvider != nil);
	GBLogDebug(@"Initializing objective-c parser with settings provider %@...", settingsProvider);
	self = [super init];
	if (self) {
		self.settings = settingsProvider;
	}
	return self;
}

#pragma mark Parsing handling

- (void)parseObjectsFromString:(NSString *)input sourceFile:(NSString *)filename toStore:(id)store {
	NSParameterAssert(input != nil);
	NSParameterAssert(filename != nil);
	NSParameterAssert([filename length] > 0);
	NSParameterAssert(store != nil);
	GBLogDebug(@"Parsing objective-c objects...");
	self.store = store;

  // Do it.
}

#pragma mark Properties

@synthesize settings;
@synthesize store;

@end
