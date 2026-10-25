#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#include <dlfcn.h>
#include <spawn.h>

extern char **environ;

static NSString *GetExtractedAppPath() {
    NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *cacheDir = cachePaths[0];
    NSString *extractedAppPath = [cacheDir stringByAppendingPathComponent:@"extracted_bundle.app"];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if ([fileManager fileExistsAtPath:extractedAppPath]) {
        return extractedAppPath;
    }
    
    NSString *mainBundlePath = [[NSBundle mainBundle] bundlePath];
    NSString *zipPath = [mainBundlePath stringByAppendingPathComponent:@"bundle.zip"];
    
    if (![fileManager fileExistsAtPath:zipPath]) {
        zipPath = [[NSBundle mainBundle] pathForResource:@"bundle" ofType:@"zip"];
    }
    
    if (![fileManager fileExistsAtPath:zipPath]) {
        return nil;
    }
    
    [fileManager createDirectoryAtPath:extractedAppPath withIntermediateDirectories:YES attributes:nil error:nil];
    
    NSString *unzipCommand = [NSString stringWithFormat:@"/usr/bin/unzip -o \"%@\" -d \"%@\"", zipPath, cacheDir];
    const char *args[] = {"sh", "-c", [unzipCommand UTF8String], NULL};
    pid_t pid;
    int status = posix_spawn(&pid, "/bin/sh", NULL, NULL, (char *const *)args, environ);
    if (status == 0) {
        waitpid(pid, &status, 0);
    }
    
    return extractedAppPath;
}

static NSString *(*orig_bundlePath)(id self, SEL _cmd);
static NSString *replaced_bundlePath(id self, SEL _cmd) {
    if (self == [NSBundle mainBundle]) {
        NSString *extractedPath = GetExtractedAppPath();
        if (extractedPath && [[NSFileManager defaultManager] fileExistsAtPath:extractedPath]) {
            return extractedPath;
        }
    }
    return orig_bundlePath(self, _cmd);
}

static NSString *(*orig_pathForResource)(id self, SEL _cmd, NSString *name, NSString *ext);
static NSString *replaced_pathForResource(id self, SEL _cmd, NSString *name, NSString *ext) {
    NSString *extractedPath = GetExtractedAppPath();
    if (extractedPath) {
        NSBundle *customBundle = [NSBundle bundleWithPath:extractedPath];
        if (customBundle) {
            NSString *customFilePath = [customBundle pathForResource:name ofType:ext];
            if (customFilePath && [[NSFileManager defaultManager] fileExistsAtPath:customFilePath]) {
                return customFilePath;
            }
        }
    }
    return orig_pathForResource(self, _cmd, name, ext);
}

static OSStatus hooked_SecCodeCheckValidity(id code, CFOptionFlags flags, id requirement) {
    return 0;
}

__attribute__((constructor)) static void initExtractorDylib() {
    @autoreleasepool {
        GetExtractedAppPath();
        Class bundleClass = objc_getClass("NSBundle");
        
        Method m1 = class_getInstanceMethod(bundleClass, @selector(bundlePath));
        if (m1) {
            orig_bundlePath = (NSString *(*)(id, SEL))method_getImplementation(m1);
            method_setImplementation(m1, (IMP)replaced_bundlePath);
        }
        
        Method m2 = class_getInstanceMethod(bundleClass, @selector(pathForResource:ofType:));
        if (m2) {
            orig_pathForResource = (NSString *(*)(id, SEL, NSString *, NSString *))method_getImplementation(m2);
            method_setImplementation(m2, (IMP)replaced_pathForResource);
        }
    }
}