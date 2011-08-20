//
//  GBClangBasedParser.h
//  appledoc
//
//  Created by Tobias Klonk on 20.08.11.
//  Copyright (c) 2011 Gentle Bytes. All rights reserved.
//

#import <Foundation/Foundation.h>

/** Implements Objective-C source code parser on top of libclang http://clang.llvm.org/.
 
 The main responsibility of this class is encapsulation of C source code parsing into in-memory
 representation. This class should be able to handle C, C++, Objective-C and Objective-C++.
 The actual work is done in the clang compiler frontend, with which we interface through libclang.
 */

@interface GBClangBasedParser : NSObject


///---------------------------------------------------------------------------------------
/// @name ￼Initialization & disposal
///---------------------------------------------------------------------------------------

/** Returns autoreleased parser to work with the given `GBApplicationSettingsProvider` implementor.
 
 This is the designated initializer.
 
 @param settingsProvider Application-wide settings provider to use for checking parameters.
 @return Returns initialized instance or `nil` if initialization fails.
 @exception NSException Thrown if the given application is `nil`.
 */
+ (id)parserWithSettingsProvider:(id)settingsProvider;

/** Initializes the parser to work with the given `GBApplicationSettingsProvider` implementor.
 
 This is the designated initializer.
 
 @param settingsProvider Application-wide settings provider to use for checking parameters.
 @return Returns initialized instance or `nil` if initialization fails.
 @exception NSException Thrown if the given application is `nil`.
 */
- (id)initWithSettingsProvider:(id)settingsProvider;

///---------------------------------------------------------------------------------------
/// @name Parsing handling
///---------------------------------------------------------------------------------------

/** Parses all objects from the given string.
 
 The method adds all detected objects to the given store.
 
 @param input The input string to parse from.
 @param filename The name of the file including extension.
 @param store Store into which the objects should be added.
 @exception NSException Thrown if the given input or store is `nil`.
 */
- (void)parseObjectsFromString:(NSString *)input sourceFile:(NSString *)filename toStore:(id)store;

@end
