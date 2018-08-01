//
//  TGRootFileManager.m
//  Filza
//
//  Created by Binh Nguyen on 11/8/15.
//  Copyright © 2015 0xFF. All rights reserved.
//

#import "TGRootFileManager.h"
#import <xpc/xpc.h>
#import "NSDictionary+XPCParse.h"
#import <sys/stat.h>
#import "FileXAttr.h"
#include <sys/stat.h>

@interface TGRootFileManager ()
{
    xpc_connection_t connection;
    BOOL invalidConnection;
}

- (void) _execRootShell:(NSString *)cmd;
- (NSString *) _execRootShellWithOutput:(NSString *)cmd;

@end

@implementation TGRootFileManager

+ (instancetype) sharedManager
{
    static TGRootFileManager *sharedInstance = nil;
    if (sharedInstance == nil) {
        static dispatch_once_t onceToken = 0;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[TGRootFileManager alloc] init];
        });
    }
    return sharedInstance;
}

- (instancetype) init
{
    self = [super init];
    if (self) {
        [self createXPCConnection];
    }
    return self;
}

-(void) tryLoadFilzaHelper
{
#if DEBUG_FILZA_SE
    return;
#endif
    
    NSLog(@"Load Filza Helper");
    system("/usr/libexec/filza/Filza reload");
    connection = xpc_connection_create_mach_service("com.tigisoftware.filza.helper.xpc", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    invalidConnection = NO;
    if (!connection) {
        NSLog(@"Failed to create XPC connection.");
        invalidConnection = YES;
    }
    else {
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            xpc_type_t type = xpc_get_type(event);
            if (type == XPC_TYPE_ERROR) {
                if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                    NSLog(@"XPC connection interupted.");
                } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                    NSLog(@"XPC connection invalid, releasing.");
                    invalidConnection = YES;
                } else {
                    NSLog(@"Unexpected XPC connection error.");
                }
            } else {
                NSLog(@"Unexpected XPC connection event.");
            }
        });
        xpc_connection_resume(connection);
    }
}

-(void) createXPCConnection
{
    invalidConnection = NO;
    connection = xpc_connection_create_mach_service("com.tigisoftware.filza.helper.xpc", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    if (!connection) {
        // Try starting service
        system("/usr/libexec/filza/Filza reload");
        connection = xpc_connection_create_mach_service("com.tigisoftware.filza.helper.xpc", NULL, XPC_CONNECTION_MACH_SERVICE_PRIVILEGED);
    }
    if (!connection) {
        NSLog(@"Failed to create XPC connection.");
        invalidConnection = YES;
    }
    else {
        xpc_connection_set_event_handler(connection, ^(xpc_object_t event) {
            xpc_type_t type = xpc_get_type(event);
            if (type == XPC_TYPE_ERROR) {
                if (event == XPC_ERROR_CONNECTION_INTERRUPTED) {
                    NSLog(@"XPC connection interupted.");
                } else if (event == XPC_ERROR_CONNECTION_INVALID) {
                    NSLog(@"XPC connection invalid, releasing.");
                    [self tryLoadFilzaHelper];
                } else {
                    NSLog(@"Unexpected XPC connection error.");
                }
            } else {
                NSLog(@"Unexpected XPC connection event.");
            }
        });
        xpc_connection_resume(connection);
    }
}

-(NSArray<NSString *> *)contentsOfDirectoryAtPath:(NSString *)path error:(NSError * _Nullable __autoreleasing *)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return nil;
    }
    else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "path", [path UTF8String]);
        xpc_dictionary_set_string(message, "name", "dir-contents");
        
        xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
        if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
            if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
                const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
                int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
                if (error != NULL) {
                    *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
                }
                return nil;
            }
            return [NSObject objectWithXPCObject:xpc_dictionary_get_value(result_xpc, "result")];
        }
        else {
            return [super contentsOfDirectoryAtPath:path error:error];
        }
    }
}

-(NSDictionary<NSString *,id> *)attributesOfItemAtPath:(NSString *)path error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return nil;
    }
    else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "path", [path UTF8String]);
        xpc_dictionary_set_string(message, "name", "get-attribute");
        
        xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
        if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
            if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
                const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
                int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
                if (error != NULL) {
                    *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
                }
                return nil;
            }
            return [NSObject objectWithXPCObject:xpc_dictionary_get_value(result_xpc, "result")];
        }
        else {
            return [super attributesOfItemAtPath:path error:error];
        }
    }
}

-(BOOL)setAttributes:(NSDictionary<NSString *,id> *)attributes ofItemAtPath:(NSString *)path error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return NO;
    }
    else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "path", [path UTF8String]);
        xpc_dictionary_set_string(message, "name", "set-attribute");
        xpc_dictionary_set_value(message, "attribute", [attributes newXPCObject]);
        
        xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
        if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
            if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
                const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
                int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
                if (error != NULL) {
                    *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
                }
            }
            return xpc_dictionary_get_bool(result_xpc, "result");
        }
        else {
            return [super setAttributes:attributes ofItemAtPath:path error:error];
        }
    }
}

-(NSArray<NSDictionary *> *)contentsOfDirectoryWithSubItemAttributesAtPath:(NSString *)path error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return nil;
    }
    else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "path", [path UTF8String]);
        xpc_dictionary_set_string(message, "name", "dir-contents-with-attributes");
        
        xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
        if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
            if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
                const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
                int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
                if (error != NULL) {
                    *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
                }
                return nil;
            }
            return [NSObject objectWithXPCObject:xpc_dictionary_get_value(result_xpc, "result")];
        }
        else {
            NSError *error3 = nil;
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error3];
            if (contents) {
                NSMutableArray *resultArray = [NSMutableArray array];
                for (int i=0; i < [contents count]; i++) {
                    NSError *error2 = nil;
                    NSString *fpath = [path stringByAppendingPathComponent:contents[i]];
                    NSDictionary *att = [[NSFileManager defaultManager] attributesOfItemAtPath:fpath error:&error2];
                    if (error2) {
                        struct stat st;
                        if (stat([fpath UTF8String], &st) == 0)
                        {
                            NSString *type = NSFileTypeRegular;
                            if ((st.st_mode & S_IFMT) == S_IFDIR) {
                                type = NSFileTypeDirectory;
                            }
                            if ((st.st_mode & S_IFMT) == S_IFREG) {
                                type = NSFileTypeRegular;
                            }
                            if ((st.st_mode & S_IFMT) == S_IFLNK) {
                                type = NSFileTypeSymbolicLink;
                            }
                            if ((st.st_mode & S_IFMT) == S_IFSOCK) {
                                type = NSFileTypeSocket;
                            }
                            if ((st.st_mode & S_IFMT) == S_IFCHR) {
                                type = NSFileTypeCharacterSpecial;
                            }
                            if ((st.st_mode & S_IFMT) == S_IFBLK) {
                                type = NSFileTypeBlockSpecial;
                            }
                            if ((st.st_mode & S_IFMT) == S_IFIFO) {
                                type = NSFileTypeBlockSpecial;
                            }
                            att = @{NSFileSize:@(st.st_size), NSFileType:type, NSFileOwnerAccountID:@(st.st_uid), NSFileGroupOwnerAccountID:@(st.st_gid), NSFilePosixPermissions:@(st.st_mode), NSFileCreationDate:[NSDate dateWithTimeIntervalSince1970:st.st_birthtimespec.tv_sec], NSFileModificationDate:[NSDate dateWithTimeIntervalSince1970:st.st_mtimespec.tv_sec]};
                            error2 = nil;
                        }
                        NSLog(@"File: %@ att: %@", fpath, att);
                    }
                    if (att) {
                        long fileTagValue = [[FileXAttr sharedInstance] tagValueForFilePath:fpath];
                        NSMutableDictionary *ext = [att mutableCopy];
                        [ext setObject:@(fileTagValue) forKey:@"TGFileTag"];
                        if ([[att fileType] isEqualToString:NSFileTypeSymbolicLink]) {
                            BOOL isDir = NO;
                            [[NSFileManager defaultManager] fileExistsAtPath:fpath isDirectory:&isDir];
                            [ext setObject:@(isDir) forKey:@"TGSymlinkFileIsDirectory"];
                            [resultArray addObject:@{@"n":contents[i], @"a":ext}];
                        }
                        else {
                            [resultArray addObject:@{@"n":contents[i], @"a":ext}];
                        }
                        ext = nil;
                    }
                }
                return resultArray;
            }
            return contents;
        }
    }
}

-(BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isDirectory
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return NO;
    }
    else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "path", [path UTF8String]);
        xpc_dictionary_set_string(message, "name", "file-exist");
        xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
        if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
            BOOL exist = xpc_dictionary_get_bool(result_xpc, "exist");
            BOOL isDir = xpc_dictionary_get_bool(result_xpc, "isDir");
            if (isDirectory != NULL) {
                *isDirectory = isDir;
            }
            return exist;
        }
        else {
            return [super fileExistsAtPath:path isDirectory:isDirectory];
        }
    }
}

-(BOOL)fileExistsAtPath:(NSString *)path
{
    return [self fileExistsAtPath:path isDirectory:NULL];
}

-(long)tagValueForItemAtPath:(NSString *)path
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return 0;
    }
    else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "path", [path UTF8String]);
        xpc_dictionary_set_string(message, "name", "get-tag");
        xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
        if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
            return (long)xpc_dictionary_get_int64(result_xpc, "tag");
        }
        else {
            return [[FileXAttr sharedInstance] tagValueForFilePath:path];
        }
    }
}

-(BOOL)setTagValue:(long)tagValue forItemAtPath:(NSString *)path
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return 0;
    }
    else {
        xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_string(message, "path", [path UTF8String]);
        xpc_dictionary_set_string(message, "name", "set-tag");
        xpc_dictionary_set_int64(message, "tag", (int64_t)tagValue);
        xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
        if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
            return xpc_dictionary_get_bool(result_xpc, "result");
        }
        else {
            return [[FileXAttr sharedInstance] setTagValue:tagValue forFilePath:path];
        }
    }
}

-(BOOL)createDirectoryAtPath:(NSString *)path withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary<NSString *,id> *)attributes error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (attributes == nil) {
        attributes = @{NSFileOwnerAccountID:@(getuid()), NSFileGroupOwnerAccountID:@(getgid())};
    }
    
    if (path == nil) {
        return NO;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "create-dir");
    xpc_dictionary_set_bool(message, "intermediates", createIntermediates);
    xpc_dictionary_set_value(message, "attribute", [attributes newXPCObject]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super createDirectoryAtPath:path withIntermediateDirectories:createIntermediates attributes:attributes error:error];
    }
}

-(BOOL)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(NSDictionary<NSString *,id> *)attributes error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (attributes == nil) {
        attributes = @{NSFileOwnerAccountID:@(getuid()), NSFileGroupOwnerAccountID:@(getgid())};
    }
    
    if (url == nil) {
        return NO;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "url", [[url absoluteString] UTF8String]);
    xpc_dictionary_set_string(message, "name", "create-dir-url");
    xpc_dictionary_set_bool(message, "intermediates", createIntermediates);
    xpc_dictionary_set_value(message, "attribute", [attributes newXPCObject]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super createDirectoryAtURL:url withIntermediateDirectories:createIntermediates attributes:attributes error:error];
    }
}

-(BOOL)createHardLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError *__autoreleasing *)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil || destPath == nil) {
        return NO;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "create-hardlink");
    xpc_dictionary_set_string(message, "dest", [destPath UTF8String]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        int result = link([destPath UTF8String],[path UTF8String]);
        
        if (result == 0) {
            return YES;
        }
        else {
            const char *string = "Error when creating hardlink";
            int64_t code = errno;
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
            return NO;
        }
    }
}

-(BOOL)createSymbolicLinkAtPath:(NSString *)path withDestinationPath:(NSString *)destPath error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil || destPath == nil) {
        return NO;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "create-symlink");
    xpc_dictionary_set_string(message, "dest", [destPath UTF8String]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super createSymbolicLinkAtPath:path withDestinationPath:destPath error:error];
    }
}

-(BOOL)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)destURL error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (url == nil || destURL == nil) {
        return NO;
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "url", [[url absoluteString] UTF8String]);
    xpc_dictionary_set_string(message, "name", "create-symlink-url");
    xpc_dictionary_set_string(message, "dest", [[destURL absoluteString] UTF8String]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super createSymbolicLinkAtURL:url withDestinationURL:destURL error:error];
    }
}

-(BOOL)createFileAtPath:(NSString *)path contents:(NSData *)data attributes:(NSDictionary<NSString *,id> *)attr
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (attr == nil) {
        attr = @{NSFileOwnerAccountID:@(getuid()), NSFileGroupOwnerAccountID:@(getgid())};
    }
    
    if (path == nil) {
        return NO;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "create-file");
    if (data) {
        xpc_dictionary_set_data(message, "data", [data bytes], [data length]);
    }
    xpc_dictionary_set_value(message, "attribute", [attr newXPCObject]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super createFileAtPath:path contents:data attributes:attr];
    }
}

-(BOOL)moveItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (srcPath == nil || dstPath == nil) {
        return NO;
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "srcPath", [srcPath UTF8String]);
    xpc_dictionary_set_string(message, "name", "move");
    xpc_dictionary_set_string(message, "dstPath", [dstPath UTF8String]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super moveItemAtPath:srcPath toPath:dstPath error:error];
    }
}
-(BOOL)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (srcURL == nil || dstURL == nil) {
        NSLog(@"Check this: srcURL: %@ dstURL: %@", srcURL, dstURL);
        return NO;
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "srcURL", [[srcURL absoluteString] UTF8String]);
    xpc_dictionary_set_string(message, "name", "move-url");
    xpc_dictionary_set_string(message, "dstURL", [[dstURL absoluteString] UTF8String]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super moveItemAtURL:srcURL toURL:dstURL error:error];
    }
}

-(BOOL)copyItemAtPath:(NSString *)srcPath toPath:(NSString *)dstPath error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (srcPath == nil || dstPath == nil) {
        return NO;
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "srcPath", [srcPath UTF8String]);
    xpc_dictionary_set_string(message, "name", "copy");
    xpc_dictionary_set_string(message, "dstPath", [dstPath UTF8String]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super copyItemAtPath:srcPath toPath:dstPath error:error];
    }
}
-(BOOL)copyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (srcURL == nil || dstURL == nil) {
        return NO;
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "srcURL", [[srcURL absoluteString] UTF8String]);
    xpc_dictionary_set_string(message, "name", "copy-url");
    xpc_dictionary_set_string(message, "dstURL", [[dstURL absoluteString] UTF8String]);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super copyItemAtURL:srcURL toURL:dstURL error:error];
    }
}

-(BOOL)removeItemAtPath:(NSString *)path error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return NO;
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "delete");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super removeItemAtPath:path error:error];
    }
}

-(BOOL)removeItemAtURL:(NSURL *)URL error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (URL == nil) {
        return NO;
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "url", [[URL absoluteString] UTF8String]);
    xpc_dictionary_set_string(message, "name", "delete-url");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
        }
        return xpc_dictionary_get_bool(result_xpc, "result");
    }
    else {
        return [super removeItemAtURL:URL error:error];
    }
}

-(NSDictionary<NSString *,id> *)attributesOfFileSystemForPath:(NSString *)path error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return nil;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "get-filesystem-attribute");
    
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
            return nil;
        }
        return [NSObject objectWithXPCObject:xpc_dictionary_get_value(result_xpc, "result")];
    }
    else {
        return [super attributesOfFileSystemForPath:path error:error];
    }
}

-(NSData *)readDataWithFilePath:(NSString *)path option:(NSDataReadingOptions)option error:(NSError **)error
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return nil;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "nsdata-read-option");
    xpc_dictionary_set_int64(message, "option", option);
    
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            const char *string = xpc_dictionary_get_string(result_xpc, "e-string");
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            if (error != NULL) {
                *error = [NSError errorWithDomain:[NSString stringWithUTF8String:string] code:(NSInteger)code userInfo:nil];
            }
            return nil;
        }
        return [NSObject objectWithXPCObject:xpc_dictionary_get_value(result_xpc, "result")];
    }
    else {
        return [NSData dataWithContentsOfFile:path options:option error:error];
    }
}

-(int) fileDescriptorForFileAtPath:(NSString *)path withFlags:(int)flags andModes:(mode_t)mode;
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "get-file-desc");
    xpc_dictionary_set_int64(message, "flags", (int64_t)flags);
    xpc_dictionary_set_int64(message, "modes", (int64_t)mode);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            errno = (int)code;
            return -1;
        }
        return xpc_dictionary_dup_fd(result_xpc, "result");
    }
    else {
        int fd = -1;
        if (mode != 0)
        {
            fd = open([path UTF8String], flags, mode);
        }
        else {
            fd = open([path UTF8String], flags);
        }
        return fd;
    }
}

-(int) setxattr:(NSString *)path name:(NSString *)name value:(NSData *)value position:(uint32_t)position option:(int32_t)option
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "xattr", [name UTF8String]);
    xpc_dictionary_set_data(message, "value", [value bytes], [value length]);
    xpc_dictionary_set_uint64(message, "position", position);
    xpc_dictionary_set_int64(message, "option", option);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            errno = (int)code;
            return -1;
        }
        return (int)xpc_dictionary_get_int64(result_xpc, "result");
    }
    else {
        return setxattr([path UTF8String], [name UTF8String], [value bytes], [value length], position, option);
    }
}

-(int)unlink:(NSString *)path
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "unlink");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        return (int)xpc_dictionary_get_int64(result_xpc, "result");
    }
    else {
        return unlink([path UTF8String]);
    }
}

-(int)rmdir:(NSString *)path
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "rmdir");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        return (int)xpc_dictionary_get_int64(result_xpc, "result");
    }
    else {
        return rmdir([path UTF8String]);
    }
}

-(ssize_t) readlink:(NSString *)path destination:(char *)destination maxSize:(size_t)size
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_int64(message, "size", size);
    xpc_dictionary_set_string(message, "name", "readlink");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        if (xpc_dictionary_get_int64(result_xpc, "e-code") != 0) {
            int64_t code = xpc_dictionary_get_int64(result_xpc, "e-code");
            errno = (int)code;
            return -1;
        }
        else {
            size_t length = 0;
            const char *data = (const char *)xpc_dictionary_get_data(result_xpc, "dest", &length);
            if (length > 0 && destination) {
                memcpy(destination, data, length);
            }
            return (ssize_t)xpc_dictionary_get_int64(result_xpc, "result");
        }
    }
    else {
        return readlink([path UTF8String], destination, size);
    }
}

-(int)mkdir:(NSString *)path mode:(mode_t)mode
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "mkdir");
    xpc_dictionary_set_int64(message, "mode", mode);
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        return (int)xpc_dictionary_get_int64(result_xpc, "result");
    }
    else {
        return mkdir([path UTF8String], mode);
    }
}

-(int)dsync:(NSString *)path
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "dir-sync");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        return (int)xpc_dictionary_get_int64(result_xpc, "result");
    }
    else {
        int rc = 0;
        /* Open a file-descriptor on the directory. Sync. Close. */
        int dfd = open([path UTF8String], O_RDONLY, 0);
        if( dfd<0 ){
            rc = -1;
        }else{
            rc = fsync(dfd);
            close(dfd);
        }
        return rc;
    }
}

-(int)stat:(NSString *)path stat:(struct stat *)statp
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_string(message, "name", "stat");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        
        size_t length = 0;
        const char *data = (const char *)xpc_dictionary_get_data(result_xpc, "stat", &length);
        if (length > 0 && statp) {
            memcpy(statp, data, sizeof(struct stat));
        }
        return (int)xpc_dictionary_get_int64(result_xpc, "result");
    }
    else {
        return stat([path UTF8String], statp);
    }
}

-(int)access:(NSString *)path mode:(int)mode
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    if (path == nil) {
        return -1;
    }
    
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "path", [path UTF8String]);
    xpc_dictionary_set_int64(message, "mode", (int64_t)mode);
    xpc_dictionary_set_string(message, "name", "access");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        return (int)xpc_dictionary_get_int64(result_xpc, "result");
    }
    else {
        return access([path UTF8String], mode);
    }
}

-(FILE *) openFile:(NSString *)path withFlags:(NSString *)flags
{
    if ([flags isEqualToString:@"r"] || [flags isEqualToString:@"rb"]) {
        int fd = [self fileDescriptorForFileAtPath:path withFlags:O_RDONLY andModes:0];
        return fdopen(fd, [flags UTF8String]);
    }
    else if ([flags isEqualToString:@"w"] || [flags isEqualToString:@"wb"]) {
        mode_t mode = (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        int fd = [self fileDescriptorForFileAtPath:path withFlags:O_WRONLY | O_CREAT | O_TRUNC andModes:mode];
        return fdopen(fd, [flags UTF8String]);
    }
    else if ([flags isEqualToString:@"a"] || [flags isEqualToString:@"ab"]) {
        mode_t mode = (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        int fd = [self fileDescriptorForFileAtPath:path withFlags:O_WRONLY | O_APPEND | O_CREAT andModes:mode];
        return fdopen(fd, [flags UTF8String]);
    }
    else if ([flags isEqualToString:@"a+"] || [flags isEqualToString:@"ab+"] || [flags isEqualToString:@"a+b"]) {
        mode_t mode = (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        int fd = [self fileDescriptorForFileAtPath:path withFlags:O_RDWR | O_APPEND | O_CREAT andModes:mode];
        return fdopen(fd, [flags UTF8String]);
    }
    else if ([flags isEqualToString:@"r+"] || [flags isEqualToString:@"rb+"] || [flags isEqualToString:@"r+b"]) {
        int fd = [self fileDescriptorForFileAtPath:path withFlags:O_RDWR andModes:0];
        return fdopen(fd, [flags UTF8String]);
    }
    else if ([flags isEqualToString:@"w+"] || [flags isEqualToString:@"wb+"] || [flags isEqualToString:@"w+b"]) {
        mode_t mode = (S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH);
        int fd = [self fileDescriptorForFileAtPath:path withFlags:O_RDWR | O_CREAT | O_TRUNC andModes:mode];
        return fdopen(fd, [flags UTF8String]);
    }
    return NULL;
}

- (void) _execRootShell:(NSString *)cmd
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "cmd", [cmd UTF8String]);
    xpc_dictionary_set_string(message, "name", "exec");
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-variable"
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) != XPC_TYPE_DICTIONARY) {
        system([cmd UTF8String]);
    }
#pragma GCC diagnostic pop
    return;
}

- (NSString *)_execRootShellWithOutput:(NSString *)cmd
{
    if (invalidConnection) {
        [self createXPCConnection];
    }
    xpc_object_t message = xpc_dictionary_create(NULL, NULL, 0);
    xpc_dictionary_set_string(message, "cmd", [cmd UTF8String]);
    xpc_dictionary_set_string(message, "name", "exec-popen");
    xpc_object_t result_xpc = xpc_connection_send_message_with_reply_sync(connection, message);
    if (xpc_get_type(result_xpc) == XPC_TYPE_DICTIONARY) {
        const char *result_str = xpc_dictionary_get_string(result_xpc, "result");
        return [NSString stringWithUTF8String:result_str];
    }
    else {
        [self createXPCConnection];
        FILE *fp = popen([cmd UTF8String], "r");
        char *resp = (char *)malloc(500);
        memset(resp, 0, 500);
        fread(resp, sizeof(char), 499, fp);
        pclose(fp);
        return [NSString stringWithUTF8String:resp];
    }
}

@end

@implementation NSData (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
    if (path) {
        FILE *file = [[TGRootFileManager sharedManager] openFile:path withFlags:@"w"];
        if (file) {
            NSInteger needToWrite = [self length];
            NSInteger write = fwrite((char *)[self bytes], sizeof(char), [self length], file);
            fclose(file);
            if (write == needToWrite) {
                NSLog(@"write: %ld needtowrite: %ld", (long)write, (long)needToWrite);
                return YES;
            }
            else {
                NSLog(@"write: %ld needtowrite: %ld", (long)write, (long)needToWrite);
                return NO;
            }
        }
    }
    return NO;
}

+(instancetype) dataWithContentsOfFilePrivileged:(NSString *)path
{
    int fp = [[TGRootFileManager sharedManager] fileDescriptorForFileAtPath:path withFlags:O_RDONLY andModes:0];
    if(fp != -1) {
        NSFileHandle *fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fp closeOnDealloc:YES];
        return [fileHandle readDataToEndOfFile];
    }
    else {
        return nil;
    }
    return nil;
}

+(instancetype)dataWithContentsOfFilePrivileged:(NSString *)path options:(NSDataReadingOptions)readOptionsMask error:(NSError *__autoreleasing *)errorPtr
{
    return [[TGRootFileManager sharedManager] readDataWithFilePath:path option:readOptionsMask error:errorPtr];
}

@end

@implementation NSString (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
    NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    FILE *file = [[TGRootFileManager sharedManager] openFile:path withFlags:@"w"];
    NSInteger needToWrite = [data length];
    NSInteger write = fwrite((char *)[data bytes], sizeof(char), [data length], file);
    fclose(file);
    if (write == needToWrite) {
        NSLog(@"write: %ld needtowrite: %ld", (long)write, (long)needToWrite);
        return YES;
    }
    else {
        NSLog(@"write: %ld needtowrite: %ld", (long)write, (long)needToWrite);
        return NO;
    }
}

+(instancetype)stringWithContentsOfFilePrivileged:(NSString *)path
{
    NSData *data = [NSData dataWithContentsOfFilePrivileged:path];
    if (data) {
        return [[self alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return nil;
}

+(instancetype) stringWithContentsOfFilePrivileged:(NSString *)path encoding:(NSStringEncoding)enc error:(NSError **)error
{
    NSData *data = [NSData dataWithContentsOfFilePrivileged:path];
    if (data) {
        NSString *str = [[self alloc] initWithData:data encoding:enc];
        if (str == nil && error != NULL) {
            *error = [NSError errorWithDomain:@"Encoding error" code:-1 userInfo:nil];
        }
        return str;
    }
    return nil;
}

@end

@implementation RootShell

+ (void) exec:(NSString *)cmd
{
    [[TGRootFileManager sharedManager] _execRootShell:cmd];
}

+(NSString *)execWithOutput:(NSString *)cmd
{
    return [[TGRootFileManager sharedManager] _execRootShellWithOutput:cmd];
}

@end


@implementation NSDictionary (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:self format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    
    if (error == nil) {
        BOOL result =[data writeToFilePrivileged:path atomically:NO];
        return result;
    }
    return NO;
}

+(instancetype)dictionaryWithContentsOfFilePrivileged:(NSString *)path
{
    NSData *data = [NSData dataWithContentsOfFilePrivileged:path];
    if (data) {
        NSPropertyListFormat format;
        return [NSPropertyListSerialization propertyListWithData:data options:0 format:&format error:NULL];
    }
    return nil;
}

@end

@implementation NSArray (TGRootFileManager)

-(BOOL)writeToFilePrivileged:(NSString *)path atomically:(BOOL)useAuxiliaryFile
{
    NSError *error = nil;
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:self format:NSPropertyListBinaryFormat_v1_0 options:0 error:&error];
    
    if (error == nil) {
        BOOL result =[data writeToFilePrivileged:path atomically:NO];
        return result;
    }
    return NO;
}

+(instancetype)arrayWithContentsOfFilePrivileged:(NSString *)path
{
    NSData *data = [NSData dataWithContentsOfFilePrivileged:path];
    if (data) {
        NSPropertyListFormat format;
        return [NSPropertyListSerialization propertyListWithData:data options:0 format:&format error:NULL];
    }
    return nil;
}

@end
