//
//  Systemator.m
//  appledoc
//
//  Created by Tomaz Kragelj on 14.4.09.
//  Copyright 2009 Tomaz Kragelj. All rights reserved.
//

#import "Systemator.h"
#import "LoggingProvider.h"
#import "CommandLineParser.h"

#define kTKSystemError @"TKSystemError"

//////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////
/** Declares methods private for the @c Systemator class.
*/
@interface Systemator (ClassPrivateAPI)

/** Determines the system's shell path.

This method will first determine the kind of shell that is used by the user. Then it will
get the path from the shell.

@return Returns the shell path.
@exception NSException Thrown if shell path cannot be determined.
*/
+ (NSString*) systemShellPath;

/** Returns the array of all lines from the given string.

@param string The string to get the lines from.
@return Returns the array containing strings representing all lines from the @c string.
*/
+ (NSMutableArray*) linesFromString:(NSString*) string;

@end

//////////////////////////////////////////////////////////////////////////////////////////
#pragma mark -
//////////////////////////////////////////////////////////////////////////////////////////

@implementation Systemator

//////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Tasks and processes helpers
//////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------
+ (void) runTask:(NSString*) command, ...
{
	NSParameterAssert(command != nil);
	
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	BOOL isDebugLevelOn = [[self logger] isDebugEnabled];
	NSMutableString* argumentsString = isDebugLevelOn ? [[NSMutableString alloc] init] : nil;
	
	// Convert the variable list into the array.
	NSMutableArray* arguments = [[NSMutableArray alloc] init];
	
	va_list args;
	va_start(args, command);
	id arg = command;
	while (arg)
	{
		id argument = va_arg(args, id);
		if (!argument) break;
		[arguments addObject:argument];
		if (isDebugLevelOn) [argumentsString appendFormat:@"%@ ", argument];
		arg++;
	}
	va_end(args);
	
	logDebug(@"Running task '%@ %@'...", command, argumentsString);

	// If debug output is desired, we should show task output, otherwise we should
	// redirect it to a temporary pipe so that it doesn't "garbage" the output.
	BOOL showOutput = [[CommandLineParser sharedInstance] emitUtilityOutput];
	NSPipe* outputPipe = showOutput ? nil : [[NSPipe alloc] init];
	
	// Setup and run the task.
	NSTask* task = [[NSTask alloc] init];
	if (outputPipe) [task setStandardOutput:outputPipe];
	[task setLaunchPath:command];
	[task setArguments:arguments];
	[task launch];
	[task waitUntilExit];
	
	// Release temporary objects.
	[outputPipe release];
	[task release];
	[arguments release];
	[argumentsString release];
	[pool drain];
}

//----------------------------------------------------------------------------------------
+ (void) runShellTaskWithCommand:(NSString*) command
{
	NSParameterAssert(command != nil);
	logDebug(@"Running shell task '%@'", command);

	// Get the user's default shell. Throw exception if this fails.
	NSDictionary* environment = [[NSProcessInfo processInfo] environment];
	NSString* shell = [environment objectForKey:@"SHELL"];
	if (!shell)
	{
		[self throwExceptionWithName:kTKSystemError withDescription:@"Failed retreiving system shell!"];
	}
	
	// Prepare the temporary file contents.
	NSMutableArray* lines = [NSMutableArray array];
	[lines addObject:[NSString stringWithFormat:@"#!%@", shell]];
	[lines addObject:command];
	
	// Prepare the temporary file name and save it.
	NSString* filename = [NSTemporaryDirectory() stringByAppendingPathComponent:@"appledoc-temp-script.sh"];
	[self writeLines:lines toFile:filename];
	
	// Change the file permissions to execute, otherwise shell will reject it.
	NSFileManager* manager = [NSFileManager defaultManager];
	NSDictionary* attributes = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedLong:S_IRWXU|S_IRWXG|S_IRWXO] 
														   forKey:NSFilePosixPermissions];
	NSError* error = nil;
	[manager setAttributes:attributes
			  ofItemAtPath:filename 
					 error:&error];
	if (error)
	{
		[manager removeItemAtPath:filename error:nil];
		[self throwExceptionWithName:kTKSystemError basedOnError:error];
	}
	
	// Prepare shell script arguments.
	NSMutableArray* arguments = [NSMutableArray array];
	[arguments addObject:@"-c"];
	[arguments addObject:filename];
	
	// If debug output is desired, we should show task output, otherwise we should
	// redirect it to a temporary pipe so that it doesn't "garbage" the output.
	BOOL showOutput = [[CommandLineParser sharedInstance] emitUtilityOutput];
	NSPipe* outputPipe = showOutput ? nil : [[NSPipe alloc] init];
	
	// Execute the shell script.
	NSTask* task = [[NSTask alloc] init];
	if (outputPipe) [task setStandardOutput:outputPipe];
	[task setLaunchPath:shell];
	[task setArguments:arguments];
	[task launch];
	[task waitUntilExit];
	
	// Release temporary objects and remove the temporary file.
	[outputPipe release];
	[task release];
	[manager removeItemAtPath:filename error:nil];
}

//////////////////////////////////////////////////////////////////////////////////////////
#pragma mark XML helpers
//////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------
+ (id) applyXSLTFromFile:(NSString*) filename 
			  toDocument:(NSXMLDocument*) document 
				   error:(NSError**) error
{
	return [self applyXSLTFromFile:filename 
						toDocument:document 
						 arguments:nil 
							 error:error];
}

//----------------------------------------------------------------------------------------
+ (id) applyXSLTFromFile:(NSString*) filename 
			  toDocument:(NSXMLDocument*) document 
			   arguments:(NSDictionary*) arguments
				   error:(NSError**) error
{
	NSString* xsltString = [NSString stringWithContentsOfFile:filename 
													 encoding:NSASCIIStringEncoding 
														error:error];
	if (xsltString)
	{
		return [document objectByApplyingXSLTString:xsltString 
										  arguments:arguments
											  error:error];
	}
	
	return nil;
}

//////////////////////////////////////////////////////////////////////////////////////////
#pragma mark File system helpers
//////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------
+ (void) createDirectory:(NSString*) path
{
	if (![[NSFileManager defaultManager] fileExistsAtPath:path])
	{
		NSError* error = nil;
		if (![[NSFileManager defaultManager] createDirectoryAtPath:path
									   withIntermediateDirectories:YES
														attributes:nil
															 error:&error])
		{
			logError(@"Creating directory '%@' failed with error %@!", 
					 path,
					 [error localizedDescription]);
			[self throwExceptionWithName:kTKSystemError basedOnError:error];
		}
	}
}

//----------------------------------------------------------------------------------------
+ (void) copyItemAtPath:(NSString*) source 
				 toPath:(NSString*) destination
{
	NSError* error = nil;
	NSFileManager* manager = [NSFileManager defaultManager];
	
	if ([manager fileExistsAtPath:destination])
	{
		logDebug(@"- Removing existing '%@'...", destination);
		if (![manager removeItemAtPath:destination error:&error])
		{
			logError(@"Removing existing '%@' failed with %@!",
					 destination,
					 [error localizedDescription]);
			[self throwExceptionWithName:kTKSystemError basedOnError:error];
		}
	}
	
	logDebug(@"- Copying '%@' to '%@'...", source, destination);
	if (![manager copyItemAtPath:source
						  toPath:destination
						   error:&error])
	{
		logError(@"Copying '%@' to '%@' failed with error %@!", 
				 source, 
				 destination,
				 [error localizedDescription]);
		[self throwExceptionWithName:kTKSystemError basedOnError:error];
	}
}

//----------------------------------------------------------------------------------------
+ (void) removeItemAtPath:(NSString*) path
{
	NSError* error = nil;
	NSFileManager* manager = [NSFileManager defaultManager];

	if ([manager fileExistsAtPath:path])
	{
		logDebug(@"Removing files at '%@'...", path);
		if (![manager removeItemAtPath:path error:&error])
		{
			logError(@"Failed removing files at '%@'!", path);
			[self throwExceptionWithName:kTKSystemError basedOnError:error];
		}
	}
}

//----------------------------------------------------------------------------------------
+ (NSMutableArray*) linesFromContentsOfFile:(NSString*) filename
{
	// Read the data from the file into the string.
	NSError* error = nil;
	NSString* contents = [[NSString alloc] initWithContentsOfFile:filename
														 encoding:NSASCIIStringEncoding
															error:&error];
	if (!contents)
	{
		logError(@"Failed reading data from '%@'!", filename);
		[self throwExceptionWithName:kTKSystemError basedOnError:error];
	}
	return [self linesFromString:contents];
}

//----------------------------------------------------------------------------------------
+ (void) writeLines:(NSArray*) lines toFile:(NSString*) filename
{
	// Generate the string containing all lines.
	NSMutableString* string = [NSMutableString string];
	for (NSString* line in lines)
	{
		[string appendString:line];
		[string appendString:@"\n"];
	}
	
	// Write the file.
	NSError* error = nil;
	if (![string writeToFile:filename
				  atomically:NO
					encoding:NSASCIIStringEncoding
					   error:&error])
	{
		logError(@"Failed writting data to file '%@'!", filename);
		[self throwExceptionWithName:kTKSystemError basedOnError:error];
	}
}

//----------------------------------------------------------------------------------------
+ (id) readPropertyListFromFile:(NSString*) filename
{
	// Read the plist data into NSData. Exit if this fails.
	NSError* error = nil;
	NSData* infoPlistData = [NSData dataWithContentsOfFile:filename
												   options:0
													 error:&error];
	if (!infoPlistData)
	{
		logError(@"Failed reading property list data from '%@'!", filename);
		[self throwExceptionWithName:kTKSystemError basedOnError:error];
	}
	
	// Convert the data into the object that will represent the property list.
	NSString* errorDescription = nil;
	id docsetInfo = [NSPropertyListSerialization propertyListFromData:infoPlistData
													 mutabilityOption:NSPropertyListImmutable
															   format:NULL
													 errorDescription:&errorDescription];
	if (!docsetInfo)
	{
		logError(@"Failed parsing property list data from '%@'!", filename);
		[self throwExceptionWithName:kTKSystemError withDescription:errorDescription];
	}
	
	return docsetInfo;
}

//----------------------------------------------------------------------------------------
+ (void) writePropertyList:(id) plist toFile:(NSString*) filename
{
	// Convert the dictionary to property list.
	NSString* errorDescription = nil;
	NSData* infoPlistData = [NSPropertyListSerialization dataFromPropertyList:plist
																	   format:NSPropertyListXMLFormat_v1_0
															 errorDescription:&errorDescription];
	if (!infoPlistData)
	{
		logError(@"Failed extracting property list data for '%@'!", filename);
		[errorDescription autorelease];
		[self throwExceptionWithName:kTKSystemError withDescription:errorDescription];
	}
	
	// Save the data to the file.
	NSError* error = nil;
	if (![infoPlistData writeToFile:filename
							options:0
							  error:&error])
	{
		logError(@"Failed writting property list data to '%@'!", filename);
		[self throwExceptionWithName:kTKSystemError basedOnError:error];
	}
}

//////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Exception helpers
//////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------
+ (void) throwExceptionWithName:(NSString*) name basedOnError:(NSError*) error;
{
	@throw [NSException exceptionWithName:name
								   reason:[error localizedDescription]
								 userInfo:[error userInfo]];
}

//----------------------------------------------------------------------------------------
+ (void) throwExceptionWithName:(NSString*) name withDescription:(NSString*) description
{
	@throw [NSException exceptionWithName:name
								   reason:description
								 userInfo:nil];
}

//////////////////////////////////////////////////////////////////////////////////////////
#pragma mark Class private methods
//////////////////////////////////////////////////////////////////////////////////////////

//----------------------------------------------------------------------------------------
+ (NSString*) systemShellPath
{
	NSTask* task = nil;
	NSPipe* outputPipe = nil;
	NSString* outputString = nil;
	
	@try
	{
		// First we must determine the kind of shell that is used, then create a process that 
		// asks the shell about the path.
		NSDictionary* environment = [[NSProcessInfo processInfo] environment];
		NSString* shell = [environment objectForKey:@"SHELL"];
		
		// Setup the pipe which will capture output from the task.
		outputPipe = [[NSPipe alloc] init];
			
		// Now create the task which will ask the shell for all environment variables.
		task = [[NSTask alloc] init];
		[task setLaunchPath:shell];
		[task setArguments:[NSArray arrayWithObjects:@"-c", @"env", nil]];
		[task setStandardOutput:outputPipe];	
		[task launch];

		// Read the output from the task into a string.
		NSData* data = [[outputPipe fileHandleForReading] readDataToEndOfFile];
		outputString = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
		
		// Convert the string into individual lines. Then scan through the lines and extract
		NSArray* lines = [self linesFromString:outputString];
		for (NSString* line in lines)
		{
			NSRange pathRange = [line rangeOfString:@"PATH"];
			NSRange separatorRange = [line rangeOfString:@"="];
			if (pathRange.location != NSNotFound && separatorRange.location != NSNotFound)
			{
				return [line substringFromIndex:separatorRange.location + separatorRange.length];
			}
		}
	}
	@catch (NSException* e)
	{
		@throw;
	}
	@finally
	{
		[outputString release];
		[outputPipe release];
		[task release];
	}
	
	return nil;
}

//----------------------------------------------------------------------------------------
+ (NSMutableArray*) linesFromString:(NSString*) string
{
	NSMutableArray *result = [NSMutableArray array];
	
	NSUInteger paragraphStart = 0;
	NSUInteger paragraphEnd = 0;
	NSUInteger contentsEnd = 0;
	NSUInteger length = [string length];
	
	NSRange currentRange;
	while (paragraphEnd < length)
	{
		[string getParagraphStart:&paragraphStart 
							  end:&paragraphEnd
					  contentsEnd:&contentsEnd 
						 forRange:NSMakeRange(paragraphEnd, 0)];
		currentRange = NSMakeRange(paragraphStart, contentsEnd - paragraphStart);
		[result addObject:[string substringWithRange:currentRange]];
	}
	
	return result;
}

@end
