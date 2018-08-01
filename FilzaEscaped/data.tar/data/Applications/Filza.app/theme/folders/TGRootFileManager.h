//
//  TGRootFileManager.h
//  Filza
//
//  Created by Binh Nguyen on 11/8/15.
//  Copyright © 2015 0xFF. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "NSObject+XPCParse.h"

@interface RootShell : NSObject

+ (void) exec:(NSString *)cmd;
+ (NSString *) execWithOutput:(NSString *)cmd;

@end

@interface NSData (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
+(instancetype) dataWithContentsOfFilePrivileged:(NSString *)path;
+(instancetype) dataWithContentsOfFilePrivileged:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError **)errorPtr;

@end

@interface NSString (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
+(instancetype) stringWithContentsOfFilePrivileged:(NSString *)path;
+(instancetype) stringWithContentsOfFilePrivileged:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error;

@end

@interface NSDictionary (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
+(instancetype) dictionaryWithContentsOfFilePrivileged:(NSString *)path;

@end

@interface NSArray (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile;
+(instancetype) arrayWithContentsOfFilePrivileged:(NSString *)path;

@end

@interface TGRootFileManager : NSFileManager

+ (instancetype) sharedManager;

-(NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError **)error;
-(NSArray<NSDictionary *> *)contentsOfDirectoryWithSubItemAttributesAtPath:(NSString *)path error:(NSError **)error;

-(NSDictionary<NSString *,id> *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error;
-(BOOL)setAttributes:(NSDictionary<NSString *,id> *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error;

-(BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory;
-(BOOL)fileExistsAtPath:(NSString *)path;

-(long)tagValueForItemAtPath:(NSString *)path;
-(BOOL)setTagValue:(long)tagValue forItemAtPath:(NSString *)path;

-(BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary<NSString *,id> *)attributes error:(NSError **)error;
-(BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary<NSString *,id> *)attributes error:(NSError **)error;

-(BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error;
-(BOOL)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)destURL error:(NSError **)error;
-(BOOL)createHardLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error;
-(BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(NSDictionary<NSString *,id> *)attr;

-(BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
-(BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error;

-(BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error;
-(BOOL)copyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error;

-(BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error;
-(BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error;

-(NSDictionary<NSString *,id> *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error;


-(int) fileDescriptorForFileAtPath:(NSString *)path withFlags:(int)flags andModes:(mode_t)mode;
-(int) unlink:(NSString *)path;
-(int) dsync:(NSString *)path;
-(int) access:(NSString *)path mode:(int)mode;
-(int) stat:(NSString *)path stat:(struct stat *)stat;
-(int) mkdir:(NSString *)path mode:(mode_t)mode;
-(int) rmdir:(NSString *)path;
-(int) setxattr:(NSString *)path name:(NSString *)name value:(NSData *)value position:(uint32_t)position option:(int32_t)option;
-(ssize_t) readlink:(NSString *)path destination:(char *)destination maxSize:(size_t)size;
-(FILE *) openFile:(NSString *)path withFlags:(NSString *)flags;

@end
