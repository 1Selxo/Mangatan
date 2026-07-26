#import "MihonEmbeddedBridge.h"

#include <jni.h>

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

extern "C" void loadfunctions(void);

namespace {

NSString *const kEmbeddedMihonErrorDomain =
    @"com.selxo.mangatan.embedded_mihon";
const char *const kEmbeddedBridgeClassName =
    "mextensionserver/EmbeddedBridge";

JavaVM *gJavaVM = nullptr;
jclass gEmbeddedBridgeClass = nullptr;
jmethodID gStartMethod = nullptr;
jmethodID gStopMethod = nullptr;
jmethodID gIsRunningMethod = nullptr;
std::mutex gJavaVMLock;

dispatch_queue_t EmbeddedMihonQueue() {
  static dispatch_queue_t queue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queue = dispatch_queue_create(
        "com.selxo.mangatan.embedded-mihon",
        DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

NSError *EmbeddedMihonError(NSInteger code, NSString *message) {
  return [NSError errorWithDomain:kEmbeddedMihonErrorDomain
                             code:code
                         userInfo:@{NSLocalizedDescriptionKey : message}];
}

NSString *JavaExceptionMessage(JNIEnv *env, NSString *fallback) {
  jthrowable exception = env->ExceptionOccurred();
  if (exception == nullptr) {
    return fallback;
  }
  env->ExceptionClear();

  NSString *message = fallback;
  jclass throwableClass = env->FindClass("java/lang/Throwable");
  if (throwableClass != nullptr) {
    jmethodID toStringMethod =
        env->GetMethodID(throwableClass, "toString", "()Ljava/lang/String;");
    if (toStringMethod != nullptr) {
      auto text =
          static_cast<jstring>(env->CallObjectMethod(exception, toStringMethod));
      if (!env->ExceptionCheck() && text != nullptr) {
        const char *utf8 = env->GetStringUTFChars(text, nullptr);
        if (utf8 != nullptr) {
          message = [NSString stringWithUTF8String:utf8];
          env->ReleaseStringUTFChars(text, utf8);
        }
        env->DeleteLocalRef(text);
      } else {
        env->ExceptionClear();
      }
    }
    env->DeleteLocalRef(throwableClass);
  } else {
    env->ExceptionClear();
  }
  env->DeleteLocalRef(exception);
  return message;
}

bool VerifyRuntimeFiles(NSString *resourcePath, NSError **error) {
  NSArray<NSString *> *requiredFiles = @[
    @"lib/modules",
    @"lib/security/cacerts",
    @"MExtensionServer.jar",
    @"java-logging-shim.jar",
  ];
  NSFileManager *fileManager = NSFileManager.defaultManager;
  for (NSString *relativePath in requiredFiles) {
    NSString *path = [resourcePath stringByAppendingPathComponent:relativePath];
    if (![fileManager fileExistsAtPath:path]) {
      if (error != nullptr) {
        *error = EmbeddedMihonError(
            1,
            [NSString stringWithFormat:
                @"The embedded Mihon runtime is incomplete: %@ is missing.",
                relativePath]);
      }
      return false;
    }
  }
  return true;
}

NSString *CreateApplicationDirectory(NSError **error) {
  NSFileManager *fileManager = NSFileManager.defaultManager;
  NSURL *supportURL = [fileManager URLForDirectory:NSApplicationSupportDirectory
                                          inDomain:NSUserDomainMask
                                 appropriateForURL:nil
                                            create:YES
                                             error:error];
  if (supportURL == nil) {
    return nil;
  }
  NSURL *appURL = [supportURL URLByAppendingPathComponent:@"MihonExtensions"
                                             isDirectory:YES];
  if (![fileManager createDirectoryAtURL:appURL
             withIntermediateDirectories:YES
                              attributes:nil
                                   error:error]) {
    return nil;
  }
  return appURL.path;
}

bool CacheBridgeEntryPoints(JNIEnv *env, NSError **error) {
  jclass localClass = env->FindClass(kEmbeddedBridgeClassName);
  if (localClass == nullptr) {
    if (error != nullptr) {
      *error = EmbeddedMihonError(
          3,
          JavaExceptionMessage(
              env, @"The embedded Mihon bridge class could not be loaded."));
    }
    return false;
  }

  gEmbeddedBridgeClass =
      static_cast<jclass>(env->NewGlobalRef(localClass));
  env->DeleteLocalRef(localClass);
  if (gEmbeddedBridgeClass == nullptr) {
    if (error != nullptr) {
      *error = EmbeddedMihonError(
          4, @"The embedded Mihon bridge class could not be retained.");
    }
    return false;
  }

  gStartMethod = env->GetStaticMethodID(
      gEmbeddedBridgeClass, "start", "(ILjava/lang/String;)I");
  gStopMethod =
      env->GetStaticMethodID(gEmbeddedBridgeClass, "stop", "()V");
  gIsRunningMethod =
      env->GetStaticMethodID(gEmbeddedBridgeClass, "isRunning", "()Z");
  if (gStartMethod == nullptr ||
      gStopMethod == nullptr ||
      gIsRunningMethod == nullptr ||
      env->ExceptionCheck()) {
    if (error != nullptr) {
      *error = EmbeddedMihonError(
          5,
          JavaExceptionMessage(
              env, @"The embedded Mihon bridge entry points are invalid."));
    }
    return false;
  }
  return true;
}

bool CreateJavaVMIfNeeded(JNIEnv **environment, NSError **error) {
  std::lock_guard<std::mutex> guard(gJavaVMLock);
  if (gJavaVM != nullptr) {
    if (gEmbeddedBridgeClass == nullptr ||
        gStartMethod == nullptr ||
        gStopMethod == nullptr ||
        gIsRunningMethod == nullptr) {
      if (error != nullptr) {
        *error = EmbeddedMihonError(
            2, @"The embedded Java runtime did not initialize completely.");
      }
      return false;
    }
    jint result = gJavaVM->AttachCurrentThread(
        reinterpret_cast<void **>(environment), nullptr);
    if (result != JNI_OK) {
      if (error != nullptr) {
        *error = EmbeddedMihonError(
            6, @"The embedded Java runtime could not attach its worker.");
      }
      return false;
    }
    return true;
  }

  NSString *resourcePath = NSBundle.mainBundle.resourcePath;
  if (!VerifyRuntimeFiles(resourcePath, error)) {
    return false;
  }

  NSString *applicationDirectory = CreateApplicationDirectory(error);
  if (applicationDirectory == nil) {
    return false;
  }
  NSString *temporaryDirectory =
      [NSTemporaryDirectory() stringByAppendingPathComponent:@"MihonExtensions"];
  if (![NSFileManager.defaultManager
          createDirectoryAtPath:temporaryDirectory
    withIntermediateDirectories:YES
                     attributes:nil
                          error:error]) {
    return false;
  }

  NSString *serverJar =
      [resourcePath stringByAppendingPathComponent:@"MExtensionServer.jar"];
  NSString *loggingShim =
      [resourcePath stringByAppendingPathComponent:@"java-logging-shim.jar"];
  NSString *trustStore =
      [resourcePath stringByAppendingPathComponent:@"lib/security/cacerts"];

  std::vector<std::string> optionStrings = {
      std::string("-Djava.class.path=") + serverJar.UTF8String,
      std::string("-Xbootclasspath/a:") + loggingShim.UTF8String,
      std::string("-Djava.home=") + resourcePath.UTF8String,
      std::string("-Djava.io.tmpdir=") + temporaryDirectory.UTF8String,
      std::string("-Duser.home=") + applicationDirectory.UTF8String,
      std::string("-Djavax.net.ssl.trustStore=") + trustStore.UTF8String,
      "-Djavax.net.ssl.trustStorePassword=changeit",
      "-Djava.awt.headless=true",
      "-Dfile.encoding=UTF-8",
      "-Djava.net.preferIPv4Stack=true",
      "-Dorg.slf4j.simpleLogger.defaultLogLevel=warn",
      "-Xms16m",
      "-Xmx256m",
  };
  std::vector<JavaVMOption> options(optionStrings.size());
  for (size_t index = 0; index < optionStrings.size(); index++) {
    options[index].optionString =
        const_cast<char *>(optionStrings[index].c_str());
    options[index].extraInfo = nullptr;
  }

  JavaVMInitArgs arguments = {};
  arguments.version = JNI_VERSION_1_8;
  arguments.nOptions = static_cast<jint>(options.size());
  arguments.options = options.data();
  arguments.ignoreUnrecognized = JNI_FALSE;

  loadfunctions();
  jint result = JNI_CreateJavaVM(
      &gJavaVM, reinterpret_cast<void **>(environment), &arguments);
  if (result != JNI_OK || gJavaVM == nullptr || *environment == nullptr) {
    gJavaVM = nullptr;
    if (error != nullptr) {
      *error = EmbeddedMihonError(
          7,
          [NSString stringWithFormat:
              @"The embedded Java runtime could not start (JNI %d).",
              result]);
    }
    return false;
  }
  if (!CacheBridgeEntryPoints(*environment, error)) {
    return false;
  }
  return true;
}

void DetachCurrentWorker() {
  if (gJavaVM != nullptr) {
    gJavaVM->DetachCurrentThread();
  }
}

}  // namespace

void MangatanEmbeddedMihonStart(
    int32_t port,
    MangatanEmbeddedMihonStartCompletion completion) {
  // OpenJDK Mobile's iOS launcher creates its first VM on the application
  // main thread. Match that path for initial bootstrap; once the VM exists,
  // normal bridge work can stay on the serial worker.
  dispatch_queue_t queue = gJavaVM == nullptr
      ? dispatch_get_main_queue()
      : EmbeddedMihonQueue();
  dispatch_async(queue, ^{
    @autoreleasepool {
      NSError *error = nil;
      JNIEnv *environment = nullptr;
      int32_t startedPort = 0;
      if (CreateJavaVMIfNeeded(&environment, &error)) {
        NSString *applicationDirectory = CreateApplicationDirectory(&error);
        if (applicationDirectory != nil) {
          jstring appDirectory =
              environment->NewStringUTF(applicationDirectory.UTF8String);
          jint result = environment->CallStaticIntMethod(
              gEmbeddedBridgeClass, gStartMethod, port, appDirectory);
          if (environment->ExceptionCheck()) {
            error = EmbeddedMihonError(
                8,
                JavaExceptionMessage(
                    environment, @"The embedded Mihon bridge failed to start."));
          } else if (result <= 0 || result > UINT16_MAX) {
            error = EmbeddedMihonError(
                9, @"The embedded Mihon bridge returned an invalid port.");
          } else {
            startedPort = result;
          }
          if (appDirectory != nullptr) {
            environment->DeleteLocalRef(appDirectory);
          }
        }
        DetachCurrentWorker();
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(startedPort, error);
      });
    }
  });
}

void MangatanEmbeddedMihonStop(
    MangatanEmbeddedMihonCompletion completion) {
  dispatch_async(EmbeddedMihonQueue(), ^{
    @autoreleasepool {
      NSError *error = nil;
      JNIEnv *environment = nullptr;
      if (gJavaVM != nullptr &&
          CreateJavaVMIfNeeded(&environment, &error)) {
        environment->CallStaticVoidMethod(
            gEmbeddedBridgeClass, gStopMethod);
        if (environment->ExceptionCheck()) {
          error = EmbeddedMihonError(
              10,
              JavaExceptionMessage(
                  environment, @"The embedded Mihon bridge failed to stop."));
        }
        DetachCurrentWorker();
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(error);
      });
    }
  });
}

void MangatanEmbeddedMihonIsRunning(
    MangatanEmbeddedMihonStatusCompletion completion) {
  dispatch_async(EmbeddedMihonQueue(), ^{
    @autoreleasepool {
      NSError *error = nil;
      JNIEnv *environment = nullptr;
      BOOL isRunning = NO;
      if (gJavaVM != nullptr &&
          CreateJavaVMIfNeeded(&environment, &error)) {
        jboolean result = environment->CallStaticBooleanMethod(
            gEmbeddedBridgeClass, gIsRunningMethod);
        if (environment->ExceptionCheck()) {
          error = EmbeddedMihonError(
              11,
              JavaExceptionMessage(
                  environment,
                  @"The embedded Mihon bridge status could not be read."));
        } else {
          isRunning = result == JNI_TRUE;
        }
        DetachCurrentWorker();
      }
      dispatch_async(dispatch_get_main_queue(), ^{
        completion(isRunning, error);
      });
    }
  });
}
